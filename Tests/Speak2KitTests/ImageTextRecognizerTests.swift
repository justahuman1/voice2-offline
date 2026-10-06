import AppKit
import Testing
@testable import Speak2Kit

struct ImageTextRecognizerTests {
    @Test @MainActor func recognizesGeneratedEnglishText() throws {
        let image = try makeImage(text: "Hello from Speak2.")
        #expect(try ImageTextRecognizer.recognize(image).contains("Hello from Speak2"))
    }

    @Test @MainActor func blankImageReturnsNoText() throws {
        #expect(try ImageTextRecognizer.recognize(makeImage(text: nil)).isEmpty)
    }

    /// Synthetic images only: tests never read screen pixels or request capture permission.
    @MainActor private func makeImage(text: String?) throws -> CGImage {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 900, pixelsHigh: 160,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 900, height: 160)).fill()
        if let text {
            (text as NSString).draw(at: CGPoint(x: 40, y: 60), withAttributes: [
                .font: NSFont.systemFont(ofSize: 48),
                .foregroundColor: NSColor.black,
            ])
        }
        return try #require(bitmap.cgImage)
    }
}
