import AVFoundation
import AppKit
import ApplicationServices
import Speak2Kit

@MainActor
final class SpeechService {
    private let appState: AppState
    private let glowOverlay: GlowOverlay
    private var playback: SpeechPlayback?
    private var synthesisTask: Task<Void, Never>?
    private var requestID = UUID()

    func stop() {
        requestID = UUID()
        synthesisTask?.cancel()
        synthesisTask = nil
        playback?.stop()
        playback = nil
        glowOverlay.hide()
    }

    init(appState: AppState, glowOverlay: GlowOverlay) {
        self.appState = appState
        self.glowOverlay = glowOverlay
    }

    /// Stops current playback/generation, or reads and speaks the focused app's selection.
    func toggleSpeakingSelection() -> String? {
        if synthesisTask != nil {
            stop()
            return nil
        }

        let isTrusted = AXIsProcessTrusted()
        NSLog("[ReadSelection] Accessibility trusted: %@", isTrusted ? "yes" : "no")
        guard isTrusted else {
            return "Allow Speak2 under System Settings > Privacy & Security > Accessibility, then try again."
        }
        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSLog("[ReadSelection] No frontmost application")
            return "Couldn't identify the frontmost app."
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
            return "Couldn't read the focused app. Try selecting the text again."
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
            return "Couldn't access selected text in this app. Nothing was copied to the clipboard."
        }

        NSLog("[ReadSelection] Sending %d characters to Kokoro", selectedText.count)
        let id = UUID()
        requestID = id
        synthesisTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.requestID == id {
                    self.playback?.stop()
                    self.playback = nil
                    self.synthesisTask = nil
                    self.glowOverlay.hide()
                }
            }
            do {
                let engine = KokoroSpeechEngine.shared
                let downloaded = await engine.isDownloaded()
                try Task.checkCancellation()
                guard self.requestID == id else { throw CancellationError() }
                self.appState.kokoroModelState = downloaded ? .loading : .downloading(status: "Preparing download…")
                for text in SpeechChunks.split(selectedText) {
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
                        self.playback = try SpeechPlayback(sampleRate: audio.sampleRate)
                        self.glowOverlay.hide()
                        NSLog("[ReadSelection] Kokoro PCM playback started")
                    }
                    try self.playback?.enqueue(audio)
                    self.appState.kokoroModelState = .loaded
                }
                await self.playback?.finish()
                try Task.checkCancellation()
            } catch is CancellationError {
                NSLog("[ReadSelection] Kokoro synthesis cancelled")
            } catch {
                let downloaded = await KokoroSpeechEngine.shared.isDownloaded()
                guard self.requestID == id else { return }
                self.appState.kokoroModelState = downloaded ? .downloaded : .notDownloaded
                NSLog("[ReadSelection] Kokoro failed: %@", error.localizedDescription)
                NotificationService.shared.showError(message: "Speech failed: \(error.localizedDescription)")
            }
        }
        return nil
    }
}
