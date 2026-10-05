import AppKit
import ApplicationServices
import CoreAudio

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
    private lazy var speechService = SpeechService(appState: appState, glowOverlay: glowOverlay)
    private var transientTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "ear", accessibilityDescription: "Speak2") {
                button.image = image
            } else {
                button.title = "S2"
            }
        }
        statusItem.menu = buildMenu()

        hotkeyManager.onToggleRecording = { [weak self] in self?.handleToggleHotkey() }
        hotkeyManager.onPushToTalkDown = { [weak self] in self?.handlePushToTalkDown() }
        hotkeyManager.onPushToTalkUp = { [weak self] in self?.handlePushToTalkUp() }
        hotkeyManager.onEscapePressed = { [weak self] in self?.handleEscape() }
        hotkeyManager.onShowHistory = { [weak self] in self?.openHistory() }
        hotkeyManager.onPasteLastTranscription = { [weak self] in
            guard let self, let text = self.appState.recentTranscription else { return }
            PasteService.pasteAtCursor(text, autoPasteEnabled: true)
        }
        hotkeyManager.onReadSelection = { [weak self] in
            NSLog("[ReadSelection] Hotkey fired")
            guard let self else { return }
            // Recording/transcription owns the overlay; TTS never interrupts it.
            guard self.appState.recordingState != .recording,
                  self.appState.recordingState != .processing,
                  self.loadingIndicatorTask == nil else { return }
            self.cancelTransientTimer()
            self.appState.recordingState = .idle
            if let error = self.speechService.toggleSpeakingSelection() {
                NotificationService.shared.showError(message: error)
            }
        }

        hotkeyManager.setPushToTalkKey(appState.pushToTalkKey)
        appState.onPushToTalkKeyChanged = { [weak self] key in
            self?.hotkeyManager.setPushToTalkKey(key)
        }
        TranscriptionHistory.shared.load()
        AudioDeviceManager.shared.loadPreferences()
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

    private func handlePushToTalkDown() {
        switch appState.recordingState {
        case .idle:
            startRecording()
        case .done, .error, .cancelled:
            cancelTransientTimer()
            startRecording()
        default:
            return
        }
    }

    private func handlePushToTalkUp() {
        guard appState.recordingState == .recording else { return }
        stopAndTranscribe()
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

    private var loadingIndicatorTask: Task<Void, Never>?

    private func showLoadingIndicator() {
        guard loadingIndicatorTask == nil else { return }
        glowOverlay.show(state: .loading)
        loadingIndicatorTask = Task {
            while appState.engineLoadingState != .loaded {
                try? await Task.sleep(for: .milliseconds(200))
            }
            glowOverlay.hide()
            loadingIndicatorTask = nil
        }
    }

    // MARK: - Recording Flow

    private func startRecording() {
        // Recording wins, including when speech is still generating its first chunk.
        cancelTransientTimer()
        speechService.stop()
        guard appState.engineLoadingState == .loaded else {
            showLoadingIndicator()
            return
        }
        appState.recordingState = .recording
        glowOverlay.show(state: .recording, glowColor: appState.glowColor)
        hotkeyManager.installEscapeMonitor()

        let mgr = AudioDeviceManager.shared
        mgr.refreshDevices()

        let deviceID: AudioDeviceID?
        if mgr.useSystemDefaultInput {
            NSLog("[AudioDebug] Input mode: system default")
            deviceID = nil
        } else if let device = mgr.availableInputDevices.first(where: {
            $0.uid == mgr.selectedInputDeviceUID
        }) {
            NSLog("[AudioDebug] Requested input: name=%@ uid=%@ id=%u", device.name, device.uid, device.id)
            deviceID = device.id
        } else {
            appState.recordingState = .error
            glowOverlay.show(state: .error)
            NotificationService.shared.showError(message: "The selected input device is unavailable.")
            hotkeyManager.removeEscapeMonitor()
            scheduleTransientTimer(duration: 0.6)
            return
        }

        Task {
            do {
                try await audioRecorder.startRecording(deviceID: deviceID) { [weak self] level in
                    Task { @MainActor in
                        guard let self else { return }
                        self.appState.audioLevel = Double(level)
                        self.glowOverlay.show(state: .recording, glowColor: self.appState.glowColor, audioLevel: CGFloat(level))
                    }
                }
            } catch {
                NSLog("[AudioDebug] Recording start failed: %@", error as NSError)
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
