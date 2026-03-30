import AppKit
import ApplicationServices

enum PasteService {
    static var onProblematicApp: (() -> Void)?

    static func pasteAtCursor(_ text: String, autoPasteEnabled: Bool) {
        // Always put text on clipboard so user can manually paste
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard autoPasteEnabled else { return }

        // Primary: insert directly via Accessibility API
        if insertViaAccessibility(text) {
            return
        }

        // Fallback: synthetic Cmd+V (clipboard already set above)
        pasteViaClipboard(text)
    }

    // MARK: - Accessibility API insertion

    private static func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        )

        guard focusResult == .success, let focused = focusedRef else {
            return false
        }

        let element = focused as! AXUIElement

        // Check if this element actually supports writable selected text
        var settable: DarwinBoolean = false
        let checkResult = AXUIElementIsAttributeSettable(
            element, kAXSelectedTextAttribute as CFString, &settable
        )
        guard checkResult == .success, settable.boolValue else {
            return false
        }

        let setResult = AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFString
        )

        return setResult == .success
    }

    // MARK: - Clipboard + CGEvent fallback

    private static func pasteViaClipboard(_ text: String) {
        // Clipboard is already set by the caller — just simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.simulatePaste()
        }
    }

    private static func simulatePaste() {
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

    // MARK: - Pasteboard save/restore

    private static func savePasteboardItems(_ pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
    }

    private static func restorePasteboardItems(
        _ savedItems: [[(NSPasteboard.PasteboardType, Data)]],
        to pasteboard: NSPasteboard
    ) {
        pasteboard.clearContents()
        let newItems = savedItems.map { typesAndData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typesAndData {
                item.setData(data, forType: type)
            }
            return item
        }
        if !newItems.isEmpty {
            pasteboard.writeObjects(newItems)
        }
    }
}
