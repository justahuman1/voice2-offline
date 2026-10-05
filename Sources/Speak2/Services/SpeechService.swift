import AVFoundation
import AppKit
import ApplicationServices

@MainActor
final class SpeechService {
    private let appState: AppState
    private let glowOverlay: GlowOverlay
    private var player: AVAudioPlayer?
    private var synthesisTask: Task<Void, Never>?

    init(appState: AppState, glowOverlay: GlowOverlay) {
        self.appState = appState
        self.glowOverlay = glowOverlay
    }

    /// Stops current playback/generation, or reads and speaks the focused app's selection.
    func toggleSpeakingSelection() -> String? {
        if let synthesisTask {
            NSLog("[ReadSelection] Cancelling Kokoro synthesis")
            synthesisTask.cancel()
            return nil
        }
        if let player, player.isPlaying {
            NSLog("[ReadSelection] Stopping Kokoro playback")
            player.stop()
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
        synthesisTask = Task { [weak self] in
            guard let self else { return }
            defer { self.synthesisTask = nil }
            do {
                let engine = KokoroSpeechEngine.shared
                self.appState.kokoroModelState = await engine.isDownloaded() ? .loading : .downloading(status: "Preparing download…")
                let wavData = try await engine.synthesizeWAV(
                    text: selectedText,
                    onDownloadStatus: { [weak self] status in
                        guard let self else { return }
                        self.appState.kokoroModelState = .downloading(status: status)
                        self.glowOverlay.show(state: .loading, message: status)
                    },
                    onDownloadComplete: { [weak self] in
                        guard let self else { return }
                        self.glowOverlay.hide()
                        self.appState.kokoroModelState = .loading
                    }
                )
                guard !Task.isCancelled else {
                    self.glowOverlay.hide()
                    self.appState.kokoroModelState = .loaded
                    return
                }
                let audioPlayer = try AVAudioPlayer(data: wavData)
                guard audioPlayer.play() else {
                    throw NSError(domain: "Speak2.AudioPlayback", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "The synthesized audio could not be played."
                    ])
                }
                self.player = audioPlayer
                self.appState.kokoroModelState = .loaded
                self.glowOverlay.hide()
                NSLog("[ReadSelection] Kokoro playback started")
            } catch is CancellationError {
                self.glowOverlay.hide()
                self.appState.kokoroModelState = await KokoroSpeechEngine.shared.isDownloaded() ? .downloaded : .notDownloaded
                NSLog("[ReadSelection] Kokoro synthesis cancelled")
            } catch {
                self.glowOverlay.hide()
                self.appState.kokoroModelState = await KokoroSpeechEngine.shared.isDownloaded() ? .downloaded : .notDownloaded
                NSLog("[ReadSelection] Kokoro failed: %@", error.localizedDescription)
                NotificationService.shared.showError(message: "Speech failed: \(error.localizedDescription)")
            }
        }
        return nil
    }
}
