import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var autoPasteMenuItem: NSMenuItem!
    let appState = AppState()
    private lazy var settingsWindow = SettingsWindow(appState: appState, engineManager: engineManager)

    private let audioRecorder = AudioRecorder()
    private lazy var engineManager = EngineManager(appState: appState)
    private let glowOverlay = GlowOverlay()
    private let hotkeyManager = HotkeyManager()
    private var transientTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Speak2") {
                button.image = image
            } else {
                button.title = "S2"
            }
        }
        statusItem.menu = buildMenu()

        hotkeyManager.onToggleRecording = { [weak self] in self?.handleToggleHotkey() }
        hotkeyManager.onEscapePressed = { [weak self] in self?.handleEscape() }
        hotkeyManager.onShowHistory = { [weak self] in self?.openHistory() }
        hotkeyManager.onPasteLastTranscription = { [weak self] in
            guard let self, let text = self.appState.recentTranscription else { return }
            PasteService.pasteAtCursor(text, autoPasteEnabled: true)
        }

        TranscriptionHistory.shared.load()
        checkAccessibilityPermission()

        if engineManager.isModelDownloaded(version: appState.selectedVersion) {
            appState.engineLoadingState = .downloaded
            engineManager.loadModel(version: appState.selectedVersion)
        } else {
            engineManager.downloadAndLoadModel(version: appState.selectedVersion)
        }

    }

    // MARK: - State Machine

    private func handleToggleHotkey() {
        switch appState.recordingState {
        case .idle:
            startRecording()
        case .recording:
            stopAndTranscribe()
        case .processing:
            return
        case .done, .error, .cancelled:
            cancelTransientTimer()
            startRecording()
        }
    }

    private func handleEscape() {
        guard appState.recordingState == .recording else { return }
        hotkeyManager.removeEscapeMonitor()

        Task {
            await audioRecorder.cancelRecording()
            appState.recordingState = .cancelled
            glowOverlay.show(state: .cancelled)
            NotificationService.shared.showCancelled()
            scheduleTransientTimer(duration: 0.3)
        }
    }

    // MARK: - Recording Flow

    private func startRecording() {
        appState.recordingState = .recording
        glowOverlay.show(state: .recording, glowColor: appState.glowColor)
        hotkeyManager.installEscapeMonitor()

        Task {
            do {
                try await audioRecorder.startRecording { [weak self] level in
                    Task { @MainActor in
                        guard let self else { return }
                        self.appState.audioLevel = Double(level)
                        self.glowOverlay.show(state: .recording, glowColor: self.appState.glowColor, audioLevel: CGFloat(level))
                    }
                }
            } catch {
                appState.recordingState = .error
                glowOverlay.show(state: .error)
                NotificationService.shared.showError(message: error.localizedDescription)
                hotkeyManager.removeEscapeMonitor()
                scheduleTransientTimer(duration: 0.6)
            }
        }
    }

    private func stopAndTranscribe() {
        hotkeyManager.removeEscapeMonitor()

        Task {
            let samples = await audioRecorder.stopRecording()

            guard let samples else {
                appState.recordingState = .cancelled
                glowOverlay.show(state: .cancelled)
                NotificationService.shared.showSkipped()
                scheduleTransientTimer(duration: 0.3)
                return
            }

            appState.recordingState = .processing
            glowOverlay.show(state: .processing)

            do {
                let rawText = try await engineManager.transcribe(audioSamples: samples)
                let text = TextReplacements.shared.processText(rawText)
                appState.recordingState = .done
                appState.recentTranscription = text
                TranscriptionHistory.shared.addEntry(text)
                glowOverlay.show(state: .done)
                NotificationService.shared.showTranscriptionComplete(text: text)
                PasteService.pasteAtCursor(text, autoPasteEnabled: appState.autoPasteEnabled)
                scheduleTransientTimer(duration: 0.6)
            } catch {
                appState.recordingState = .error
                glowOverlay.show(state: .error)
                NotificationService.shared.showError(message: error.localizedDescription)
                scheduleTransientTimer(duration: 0.6)
            }
        }
    }

    // MARK: - Transient Timer

    private func scheduleTransientTimer(duration: TimeInterval) {
        transientTimer?.invalidate()
        transientTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.appState.recordingState = .idle
                self?.appState.audioLevel = 0.0
                self?.glowOverlay.hide()
            }
        }
    }

    private func cancelTransientTimer() {
        transientTimer?.invalidate()
        transientTimer = nil
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let historyItem = NSMenuItem(title: "View History...", action: #selector(openHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        autoPasteMenuItem = NSMenuItem(title: "Auto-Paste", action: #selector(toggleAutoPaste), keyEquivalent: "")
        autoPasteMenuItem.target = self
        autoPasteMenuItem.state = appState.autoPasteEnabled ? .on : .off
        menu.addItem(autoPasteMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Speak2", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.show()
    }

    @objc private func openHistory() {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.showHistoryTab()
    }

    @objc private func toggleAutoPaste() {
        appState.autoPasteEnabled.toggle()
        autoPasteMenuItem.state = appState.autoPasteEnabled ? .on : .off
    }

    // MARK: - Permissions

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            print("Speak2: Accessibility permission required for global hotkeys and paste.")
        }
    }
}
