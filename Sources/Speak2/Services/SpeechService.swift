import AVFoundation
import AppKit
import ApplicationServices
import Speak2Kit

enum SpeechSource {
    case selection
    case clipboard
    case screenRegion
}

private struct SpeechInputError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class SpeechService {
    private let appState: AppState
    private let glowOverlay: GlowOverlay
    private var playback: SpeechPlayback?
    private var synthesisTask: Task<Void, Never>?
    private var requestID = UUID()
    private var screenReader: ScreenTextReader?

    func stop() {
        guard synthesisTask != nil else { return }
        requestID = UUID()
        synthesisTask?.cancel()
        synthesisTask = nil
        screenReader?.cancel()
        screenReader = nil
        playback?.stop()
        playback = nil
        glowOverlay.hide()
        // This asynchronous refresh must never update a newer speech request.
        let stoppedID = requestID
        Task {
            let downloaded = await KokoroSpeechEngine.shared.isDownloaded()
            guard self.requestID == stoppedID else { return }
            if self.appState.kokoroModelState != .loaded {
                self.appState.kokoroModelState = downloaded ? .downloaded : .notDownloaded
            }
        }
    }

    init(appState: AppState, glowOverlay: GlowOverlay) {
        self.appState = appState
        self.glowOverlay = glowOverlay
    }

    /// Any read command stops an active read; otherwise acquire text from its explicit source.
    func toggleSpeaking(_ source: SpeechSource) -> String? {
        if synthesisTask != nil {
            stop()
            return nil
        }

        let selectedText: String?
        let reader: ScreenTextReader?
        do {
            switch source {
            case .selection:
                reader = nil
                selectedText = try readSelectedText()
            case .clipboard:
                reader = nil
                guard let text = NSPasteboard.general.string(forType: .string),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return "The clipboard contains no text. Copy some text, then try again."
                }
                selectedText = text
            case .screenRegion:
                if let error = ScreenTextReader.checkPermission() { return error }
                selectedText = nil
                reader = ScreenTextReader()
            }
        } catch {
            return error.localizedDescription
        }

        screenReader = reader
        let id = UUID()
        requestID = id
        synthesisTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.requestID == id {
                    self.screenReader?.cancel()
                    self.screenReader = nil
                    self.playback?.stop()
                    self.playback = nil
                    self.synthesisTask = nil
                    self.glowOverlay.hide()
                }
            }
            var synthesisStarted = false
            do {
                let speechText: String
                if let selectedText { speechText = selectedText }
                else if let reader { speechText = try await reader.readText() }
                else { throw CancellationError() }
                try Task.checkCancellation()
                guard self.requestID == id else { throw CancellationError() }
                NSLog("[ReadSpeech] Sending %d characters to Kokoro", speechText.count)
                synthesisStarted = true
                let engine = KokoroSpeechEngine.shared
                let downloaded = await engine.isDownloaded()
                try Task.checkCancellation()
                guard self.requestID == id else { throw CancellationError() }
                self.appState.kokoroModelState = downloaded ? .loading : .downloading(status: "Preparing download…")
                for text in SpeechChunks.split(speechText) {
                    await self.playback?.waitForCapacity()
                    try Task.checkCancellation()
                    let audio = try await engine.synthesize(
                        text: text,
                        onDownloadStatus: { [weak self] status in
                            guard let self, self.requestID == id else { return }
                            self.appState.kokoroModelState = .downloading(status: status)
                            self.glowOverlay.show(state: .loading, message: status)
                        },
                        onDownloadComplete: { [weak self] in
                            guard let self, self.requestID == id else { return }
                            self.glowOverlay.hide()
                            self.appState.kokoroModelState = .loading
                        }
                    )
                    try Task.checkCancellation()
                    guard self.requestID == id else { throw CancellationError() }
                    if self.playback == nil {
                        self.playback = try SpeechPlayback(sampleRate: audio.sampleRate) { [weak self] level in
                            guard let self, self.requestID == id, self.playback != nil else { return }
                            self.glowOverlay.show(state: .speaking, glowColor: self.appState.speakingGlowColor, audioLevel: level)
                        }
                        NSLog("[ReadSpeech] Kokoro PCM playback started")
                    }
                    try self.playback?.enqueue(audio)
                    self.glowOverlay.show(state: .speaking, glowColor: self.appState.speakingGlowColor)
                    self.appState.kokoroModelState = .loaded
                }
                await self.playback?.finish()
                try Task.checkCancellation()
            } catch is CancellationError {
                NSLog("[ReadSpeech] Read cancelled")
            } catch {
                if synthesisStarted {
                    let downloaded = await KokoroSpeechEngine.shared.isDownloaded()
                    guard self.requestID == id else { return }
                    self.appState.kokoroModelState = downloaded ? .downloaded : .notDownloaded
                }
                guard self.requestID == id else { return }
                NSLog("[ReadSpeech] Failed: %@", error.localizedDescription)
                NotificationService.shared.showError(message: "Read failed: \(error.localizedDescription)")
            }
        }
        return nil
    }

    private func readSelectedText() throws -> String {
        let isTrusted = AXIsProcessTrusted()
        NSLog("[ReadSelection] Accessibility trusted: %@", isTrusted ? "yes" : "no")
        guard isTrusted else {
            throw SpeechInputError(message: "Allow Speak2 under System Settings > Privacy & Security > Accessibility, then try again.")
        }
        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSLog("[ReadSelection] No frontmost application")
            throw SpeechInputError(message: "Couldn't identify the frontmost app.")
        }
        NSLog("[ReadSelection] Frontmost app: %@ (%@)", app.localizedName ?? "unknown", app.bundleIdentifier ?? "no bundle id")

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedElementValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementValue
        )
        guard focusResult == .success, let focusedElementValue else {
            NSLog("[ReadSelection] Focused element lookup failed: %@", String(describing: focusResult))
            throw SpeechInputError(message: "Couldn't read the focused app. Try selecting the text again.")
        }

        let focusedElement = focusedElementValue as! AXUIElement
        var selectedTextValue: CFTypeRef?
        let selectionResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )
        guard selectionResult == .success,
              let selectedText = selectedTextValue as? String,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            NSLog("[ReadSelection] Selected text unavailable: AXError=%@, value type=%@", String(describing: selectionResult), String(describing: selectedTextValue.map { type(of: $0) }))
            throw SpeechInputError(message: "Couldn't access selected text in this app. Nothing was copied to the clipboard.")
        }

        return selectedText
    }
}
