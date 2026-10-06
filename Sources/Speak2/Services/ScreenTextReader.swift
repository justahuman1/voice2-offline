import AppKit
import ScreenCaptureKit
import Speak2Kit

private struct ScreenTextError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class ScreenTextReader {
    private let selector = ScreenRegionSelector()
    private var cancelled = false

    static func checkPermission() -> String? {
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            return "Allow screen capture under System Settings > Privacy & Security > Screen Recording (Screen & System Audio Recording on newer macOS), then retry. You may need to restart Speak2 or its launching terminal."
        }
        return nil
    }

    func cancel() {
        cancelled = true
        selector.cancel()
    }

    func readText() async throws -> String {
        try checkCancellation()
        guard let region = await selector.select() else { throw CancellationError() }
        try checkCancellation()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        try checkCancellation()
        guard let display = content.displays.first(where: { $0.displayID == region.displayID }) else {
            throw ScreenTextError(message: "The selected display is no longer available. Try again.")
        }
        // Exclude our panels even if WindowServer hasn't yet processed their dismissal.
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let config = SCStreamConfiguration()
        config.sourceRect = region.sourceRect
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(ceil(region.sourceRect.width * scale))
        config.height = Int(ceil(region.sourceRect.height * scale))
        config.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try checkCancellation()
        // Vision performs synchronous CPU work; never run it on the UI actor.
        let text = try await Task.detached(priority: .userInitiated) {
            try ImageTextRecognizer.recognize(image)
        }.value
        try checkCancellation()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScreenTextError(message: "No readable text was found in that region. Try a larger or clearer region, or copy text and use Read Clipboard.")
        }
        // Do not log recognized text or retain screenshots; both can contain private information.
        NSLog("[ScreenOCR] Recognized %d characters", text.count)
        return text
    }

    private func checkCancellation() throws {
        try Task.checkCancellation()
        if cancelled { throw CancellationError() }
    }
}
