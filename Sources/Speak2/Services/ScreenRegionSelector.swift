import AppKit
import Speak2Kit

struct ScreenRegion {
    let displayID: CGDirectDisplayID
    let sourceRect: CGRect
}

/// One nonactivating panel per display. Regions stay on the display where the drag starts.
@MainActor
final class ScreenRegionSelector {
    private var panels: [NSPanel] = []
    private var continuation: CheckedContinuation<ScreenRegion?, Never>?

    func select() async -> ScreenRegion? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            for screen in NSScreen.screens {
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
                let panel = RegionPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                panel.level = .screenSaver
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                let view = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
                view.onFinish = { [weak self] rect in
                    guard let self else { return }
                    guard let rect,
                          let source = ScreenRegionGeometry.captureRect(selection: rect, displaySize: screen.frame.size) else {
                        self.cancel()
                        return
                    }
                    self.finish(ScreenRegion(displayID: number.uint32Value, sourceRect: source))
                }
                panel.contentView = view
                panels.append(panel)
                panel.orderFrontRegardless()
                if screen.frame.contains(NSEvent.mouseLocation) {
                    panel.makeKey()
                    panel.makeFirstResponder(view)
                }
            }
            if panels.isEmpty { finish(nil) }
        }
    }

    func cancel() { finish(nil) }

    private func finish(_ region: ScreenRegion?) {
        panels.forEach { $0.close() }
        panels.removeAll()
        let pending = continuation
        continuation = nil
        pending?.resume(returning: region)
    }
}

private final class RegionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class RegionSelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var start: CGPoint?
    private var selection: CGRect?
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        start = convert(event.locationInWindow, from: nil)
        selection = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let point = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                           width: abs(point.x - start.x), height: abs(point.y - start.y)).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        onFinish?(selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onFinish?(nil) }
        else { super.keyDown(with: event) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.clear(bounds)
        let shade = NSBezierPath(rect: bounds)
        if let selection { shade.append(NSBezierPath(rect: selection)) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.35).setFill()
        shade.fill()
        if let selection {
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 1.5
            border.stroke()
        }
        let hint = "Drag over text to read · Esc to cancel" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = hint.size(withAttributes: attributes)
        hint.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height - 60), withAttributes: attributes)
    }
}
