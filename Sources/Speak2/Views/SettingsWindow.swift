import AppKit
import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case settings
    case history
    case statistics
    case audioDevices
}

@Observable
@MainActor
final class SettingsTabState {
    var selectedTab: SettingsTab = .settings
}

struct SettingsContentView: View {
    @Bindable var tabState: SettingsTabState

    var body: some View {
        TabView(selection: $tabState.selectedTab) {
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(SettingsTab.settings)

            Text("History")
                .tabItem { Label("History", systemImage: "clock") }
                .tag(SettingsTab.history)

            Text("Statistics")
                .tabItem { Label("Statistics", systemImage: "chart.bar") }
                .tag(SettingsTab.statistics)

            Text("Audio Devices")
                .tabItem { Label("Audio Devices", systemImage: "speaker.wave.2") }
                .tag(SettingsTab.audioDevices)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

@MainActor
final class SettingsWindow {
    private let window: NSWindow
    private let tabState = SettingsTabState()

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Speak2 Settings"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 600, height: 400)
        window.center()

        let hostingView = NSHostingView(rootView: SettingsContentView(tabState: tabState))
        window.contentView = hostingView
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func showHistoryTab() {
        tabState.selectedTab = .history
        show()
    }
}
