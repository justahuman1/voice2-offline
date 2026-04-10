import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
    static let toggleRecordingAlt = Self("toggleRecordingAlt")
    static let pushToTalk = Self("pushToTalk")
    static let showHistory = Self("showHistory")
    static let pasteLastTranscription = Self("pasteLastTranscription")
}

@MainActor
final class HotkeyManager {
    var onToggleRecording: (() -> Void)?
    var onPushToTalkDown: (() -> Void)?
    var onPushToTalkUp: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onPasteLastTranscription: (() -> Void)?
    var onEscapePressed: (() -> Void)?

    private var escapeMonitor: Any?
    private var pttMonitor: Any?
    private var pttDown = false
    private var pttKey: PushToTalkKey = .none

    init() {
        KeyboardShortcuts.setShortcut(.init(.x, modifiers: [.command, .option]), for: .toggleRecording)
        KeyboardShortcuts.setShortcut(.init(.period, modifiers: [.command, .option]), for: .toggleRecordingAlt)
        KeyboardShortcuts.setShortcut(.init(.x, modifiers: [.command, .option, .shift]), for: .pushToTalk)
        KeyboardShortcuts.setShortcut(.init(.a, modifiers: [.command, .option]), for: .showHistory)
        KeyboardShortcuts.setShortcut(.init(.v, modifiers: [.command, .option]), for: .pasteLastTranscription)

        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.onToggleRecording?()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleRecordingAlt) { [weak self] in
            self?.onToggleRecording?()
        }
        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in
            self?.onPushToTalkDown?()
        }
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) { [weak self] in
            self?.onPushToTalkUp?()
        }
        KeyboardShortcuts.onKeyUp(for: .showHistory) { [weak self] in
            self?.onShowHistory?()
        }
        KeyboardShortcuts.onKeyUp(for: .pasteLastTranscription) { [weak self] in
            self?.onPasteLastTranscription?()
        }
    }

    func setPushToTalkKey(_ key: PushToTalkKey) {
        pttKey = key
        pttDown = false
        if let monitor = pttMonitor {
            NSEvent.removeMonitor(monitor)
            pttMonitor = nil
        }
        guard key != .none else { return }
        pttMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let pressed = self.isKeyPressed(key, event: event)
            if pressed && !self.pttDown {
                self.pttDown = true
                self.onPushToTalkDown?()
            } else if !pressed && self.pttDown {
                self.pttDown = false
                self.onPushToTalkUp?()
            }
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

    private func isKeyPressed(_ key: PushToTalkKey, event: NSEvent) -> Bool {
        switch key {
        case .none:
            return false
        case .fn:
            return event.modifierFlags.contains(.function)
        case .rightCommand:
            return event.keyCode == 54 && event.modifierFlags.contains(.command)
        case .rightOption:
            return event.keyCode == 61 && event.modifierFlags.contains(.option)
        case .rightControl:
            return event.keyCode == 62 && event.modifierFlags.contains(.control)
        }
    }
}
