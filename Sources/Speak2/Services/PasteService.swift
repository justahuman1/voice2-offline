import AppKit

enum PasteService {

    static func pasteAtCursor(_ text: String, autoPasteEnabled: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard autoPasteEnabled else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        usleep(20_000)
        keyUp.post(tap: .cghidEventTap)
    }
}
