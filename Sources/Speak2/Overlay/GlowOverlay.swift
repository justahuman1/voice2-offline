import AppKit
import QuartzCore
import Speak2Kit

enum OverlayState {
    case recording
    case processing
    case done
    case error
    case cancelled
}

extension GlowColor {
    var nsColor: NSColor {
        switch self {
        case .cyan:   return NSColor(red: 0.0, green: 0.749, blue: 1.0, alpha: 1.0)
        case .purple: return NSColor(red: 0.749, green: 0.353, blue: 0.949, alpha: 1.0)
        case .green:  return NSColor(red: 0.188, green: 0.82, blue: 0.345, alpha: 1.0)
        case .pink:   return NSColor(red: 1.0, green: 0.216, blue: 0.373, alpha: 1.0)
        case .orange: return NSColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0)
        case .system: return NSColor.controlAccentColor
        }
    }
}

final class GlowOverlay {

    private var window: NSWindow?
    private var gradientLayer: CAGradientLayer?

    func show(state: OverlayState, glowColor: GlowColor = .cyan, audioLevel: CGFloat = 0.0) {
        setupWindowIfNeeded()
        repositionToMainScreen()

        guard let window = window, let layer = gradientLayer else { return }

        let color: NSColor
        switch state {
        case .recording:
            color = glowColor.nsColor
        case .processing:
            color = NSColor(red: 1.0, green: 0.69, blue: 0.125, alpha: 1.0) // #FFB020
        case .done:
            color = NSColor(red: 0.188, green: 0.82, blue: 0.345, alpha: 1.0) // #30D158
        case .error:
            color = NSColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1.0) // #FF453A
        case .cancelled:
            fadeOut()
            return
        }

        let cgColor = color.cgColor
        layer.colors = [NSColor.clear.cgColor, cgColor, cgColor, NSColor.clear.cgColor]
        layer.removeAllAnimations()

        switch state {
        case .recording:
            let opacity = Float(0.3 + 0.7 * min(max(audioLevel, 0.0), 1.0))
            layer.opacity = opacity

        case .processing:
            layer.opacity = 1.0
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.4
            pulse.toValue = 0.9
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            layer.add(pulse, forKey: "pulse")

        case .done, .error:
            layer.opacity = 1.0
            let flash = CAKeyframeAnimation(keyPath: "opacity")
            flash.values = [1.0, 1.0, 0.0]
            flash.keyTimes = [0, 0.5, 1.0]
            flash.duration = 0.6
            flash.isRemovedOnCompletion = false
            flash.fillMode = .forwards
            layer.add(flash, forKey: "flash")

        case .cancelled:
            break
        }

        window.orderFront(nil)
    }

    func hide() {
        gradientLayer?.removeAllAnimations()
        window?.orderOut(nil)
    }

    private func fadeOut() {
        guard let layer = gradientLayer else { return }
        layer.removeAllAnimations()
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = layer.opacity
        fade.toValue = 0.0
        fade.duration = 0.2
        fade.isRemovedOnCompletion = false
        fade.fillMode = .forwards
        layer.add(fade, forKey: "fadeOut")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    private func setupWindowIfNeeded() {
        guard window == nil else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = NSRect(x: screen.frame.origin.x, y: screen.frame.origin.y, width: screen.frame.width, height: 6)

        let win = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.ignoresMouseEvents = true
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false

        let contentView = NSView(frame: win.contentView!.bounds)
        contentView.wantsLayer = true
        win.contentView = contentView

        let layer = CAGradientLayer()
        layer.frame = contentView.bounds
        layer.type = .axial
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.locations = [0.0, 0.3, 0.7, 1.0]
        layer.colors = [NSColor.clear.cgColor, NSColor.clear.cgColor, NSColor.clear.cgColor, NSColor.clear.cgColor]
        contentView.layer?.addSublayer(layer)

        self.window = win
        self.gradientLayer = layer
    }

    private func repositionToMainScreen() {
        guard let window = window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = NSRect(x: screen.frame.origin.x, y: screen.frame.origin.y, width: screen.frame.width, height: 6)
        window.setFrame(frame, display: true)
        gradientLayer?.frame = window.contentView?.bounds ?? frame
    }
}
