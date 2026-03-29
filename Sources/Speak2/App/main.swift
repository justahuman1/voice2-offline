import AppKit

nonisolated(unsafe) var appDelegate: AppDelegate?

@MainActor
func bootstrap() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    appDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    delegate.setup()
    app.run()
}

MainActor.assumeIsolated {
    bootstrap()
}
