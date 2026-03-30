import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
    static let toggleRecordingAlt = Self("toggleRecordingAlt")
    static let showHistory = Self("showHistory")
    static let pasteLastTranscription = Self("pasteLastTranscription")
}

@MainActor
final class HotkeyManager {
    var onToggleRecording: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onPasteLastTranscription: (() -> Void)?
    var onEscapePressed: (() -> Void)?

    private var escapeMonitor: Any?

    init() {
        KeyboardShortcuts.setShortcut(.init(.x, modifiers: [.command, .option]), for: .toggleRecording)
        KeyboardShortcuts.setShortcut(.init(.period, modifiers: [.command, .option]), for: .toggleRecordingAlt)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.command, .option]), for: .showHistory)
        KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .option]), for: .pasteLastTranscription)

        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.onToggleRecording?()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleRecordingAlt) { [weak self] in
            self?.onToggleRecording?()
        }
        KeyboardShortcuts.onKeyUp(for: .showHistory) { [weak self] in
            self?.onShowHistory?()
        }
        KeyboardShortcuts.onKeyUp(for: .pasteLastTranscription) { [weak self] in
            self?.onPasteLastTranscription?()
        }
    }

    func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onEscapePressed?()
            }
        }
    }

    func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }
}
