import AppKit

enum PasteService {

    static func pasteAtCursor(_ text: String, autoPasteEnabled: Bool) {
        let pasteboard = NSPasteboard.general
        let saved = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard autoPasteEnabled else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            restorePasteboard(pasteboard, from: saved)
            return
        }

        keyDown.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        usleep(20_000)
        keyUp.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            restorePasteboard(pasteboard, from: saved)
        }
    }

    private static func savePasteboard(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict
        }
    }

    private static func restorePasteboard(_ pasteboard: NSPasteboard, from items: [[NSPasteboard.PasteboardType: Data]]) {
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        let pasteboardItems = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
    }
}
