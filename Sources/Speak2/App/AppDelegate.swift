import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var autoPasteMenuItem: NSMenuItem!
    let appState = AppState()
    private lazy var settingsWindow = SettingsWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Speak2")
        }
        statusItem.menu = buildMenu()
    }

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
}
