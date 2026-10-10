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
    private let diagnosticID = String(UUID().uuidString.prefix(8))

    static func checkPermission() -> String? {
        let granted = CGPreflightScreenCaptureAccess()
        let parent = NSRunningApplication(processIdentifier: getppid())
        // The parent can be a shell; this is a launch clue, not macOS's authoritative TCC identity.
        NSLog("[ScreenOCR] Permission preflight=%@ pid=%d executable=%@ bundle=%@ parentPID=%d parentApp=%@",
              granted ? "granted" : "denied", ProcessInfo.processInfo.processIdentifier,
              Bundle.main.executableURL?.lastPathComponent ?? "unknown",
              Bundle.main.bundleIdentifier ?? "unbundled", getppid(), parent?.bundleIdentifier ?? "unknown/shell")
        guard granted else {
            let requested = CGRequestScreenCaptureAccess()
            let afterRequest = CGPreflightScreenCaptureAccess()
            NSLog("[ScreenOCR] Permission request returned=%@; subsequent preflight=%@",
                  requested ? "true" : "false", afterRequest ? "granted" : "denied")
            if afterRequest { return nil }
            return "Allow screen capture under System Settings > Privacy & Security > Screen Recording (Screen & System Audio Recording on newer macOS), then retry. You may need to restart Speak2 or its launching terminal."
        }
        return nil
    }

    func cancel() {
        if !cancelled { log("Cancel/cleanup requested") }
        cancelled = true
        selector.cancel()
    }

    func readText() async throws -> String {
        let start = ContinuousClock.now
        var stage = "region selection"
        do {
            try checkCancellation()
            log("Waiting for region selection")
            guard let region = await selector.select() else {
                log("Region selection ended without a region")
                throw CancellationError()
            }
            try checkCancellation()
            log("Selected display=\(region.displayID), region=\(region.sourceRect.width)x\(region.sourceRect.height) points")
            stage = "shareable content"
            log("Requesting ScreenCaptureKit display/window metadata")
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            try checkCancellation()
            log("Metadata ready: displays=\(content.displays.count), windows=\(content.windows.count)")
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
            stage = "screenshot capture"
            log("Capturing \(config.width)x\(config.height) pixels; scale=\(scale), excludedOwnWindows=\(ownWindows.count)")
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            try checkCancellation()
            log("Capture ready: \(image.width)x\(image.height) pixels")
            stage = "Vision recognition"
            log("Starting local Vision OCR")
            // Vision performs synchronous CPU work; never run it on the UI actor.
            let text = try await Task.detached(priority: .userInitiated) {
                try ImageTextRecognizer.recognize(image)
            }.value
            try checkCancellation()
            log("Vision complete: characters=\(text.count), lines=\(text.split(separator: "\n").count), elapsed=\(start.duration(to: .now))")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ScreenTextError(message: "No readable text was found in that region. Try a larger or clearer region, or copy text and use Read Clipboard.")
            }
            // Do not log recognized text or retain screenshots; both can contain private information.
            return text
        } catch is CancellationError {
            log("Cancelled during \(stage); elapsed=\(start.duration(to: .now))")
            throw CancellationError()
        } catch {
            let failure = error as NSError
            log("Failed during \(stage): domain=\(failure.domain), code=\(failure.code); elapsed=\(start.duration(to: .now))")
            throw error
        }
    }

    private func log(_ message: String) {
        NSLog("[ScreenOCR] %@ %@", diagnosticID, message)
    }

    private func checkCancellation() throws {
        try Task.checkCancellation()
        if cancelled { throw CancellationError() }
    }
}
