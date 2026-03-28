import AppKit
import Carbon.HIToolbox

enum PasteService {
    static var onProblematicApp: (() -> Void)?

    private static let problematicBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systempreferences",
    ]

    static func pasteAtCursor(_ text: String, autoPasteEnabled: Bool) {
        let pasteboard = NSPasteboard.general

        if autoPasteEnabled {
            // 1. Save current pasteboard items
            let savedItems = savePasteboardItems(pasteboard)

            // 2. Set text on pasteboard
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            // 3. Simulate Cmd+V
            simulatePaste()

            // 4. After delay, check for problematic apps and restore clipboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                   problematicBundleIDs.contains(bundleID) {
                    onProblematicApp?()
                }

                // 5. Restore original clipboard
                restorePasteboardItems(savedItems, to: pasteboard)
            }
        } else {
            // Just set clipboard, no paste
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }

    // MARK: - Private

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

    private static func simulatePaste() {
        let vKeyCode: CGKeyCode = 0x09

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
