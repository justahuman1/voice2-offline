import CoreGraphics

public enum ScreenRegionGeometry {
    /// AppKit uses a bottom-left origin; ScreenCaptureKit source rectangles use top-left points.
    /// Keep this in points: Retina scaling applies only to the output image dimensions.
    public static func captureRect(selection: CGRect, displaySize: CGSize) -> CGRect? {
        let bounds = CGRect(origin: .zero, size: displaySize)
        let rect = selection.standardized.intersection(bounds)
        guard !rect.isNull, rect.width >= 2, rect.height >= 2 else { return nil }
        return CGRect(x: rect.minX, y: displaySize.height - rect.maxY, width: rect.width, height: rect.height)
    }
}
