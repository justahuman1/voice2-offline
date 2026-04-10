import AppKit
import QuartzCore
import Speak2Kit

enum OverlayState {
    case loading
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

    private static let windowHeight: CGFloat = 38
    private static let hueShift: CGFloat = 0.10

    private var window: NSWindow?
    private var bloomLayer: CAGradientLayer?
    private var coreLayer: CAGradientLayer?
    private var textLayer: CATextLayer?
    private var smoothedLevel: CGFloat = 0.0

    private static func shiftedColor(_ color: NSColor) -> NSColor {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: fmod(h + hueShift, 1.0), saturation: s, brightness: b, alpha: a)
    }

    func show(state: OverlayState, glowColor: GlowColor = .cyan, audioLevel: CGFloat = 0.0) {
        setupWindowIfNeeded()
        repositionToMainScreen()

        guard let window = window,
              let bloom = bloomLayer,
              let core = coreLayer else { return }

        let color: NSColor
        switch state {
        case .loading:
            color = NSColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1.0)
        case .recording:
            color = glowColor.nsColor
        case .processing:
            color = NSColor(red: 1.0, green: 0.69, blue: 0.125, alpha: 1.0)
        case .done:
            color = NSColor(red: 0.188, green: 0.82, blue: 0.345, alpha: 1.0)
        case .error:
            color = NSColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1.0)
        case .cancelled:
            smoothedLevel = 0.0
            fadeOut()
            return
        }

        let cgColor = color.cgColor
        bloom.removeAllAnimations()
        core.removeAllAnimations()

        switch state {
        case .loading:
            smoothedLevel = 0.0
            let shifted = Self.shiftedColor(color).cgColor
            core.colors = [NSColor.clear.cgColor, cgColor, cgColor, NSColor.clear.cgColor]
            core.locations = [0.0, 0.35, 0.65, 1.0]
            core.opacity = 0.4
            bloom.colors = [NSColor.clear.cgColor, shifted, shifted, NSColor.clear.cgColor]
            bloom.locations = [0.0, 0.3, 0.7, 1.0]
            bloom.opacity = 0.2

            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.2
            pulse.toValue = 0.5
            pulse.duration = 1.5
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            core.add(pulse, forKey: "pulse")

        case .recording:
            let level = min(max(audioLevel, 0.0), 1.0)
            // Smooth the level for the bloom layer (trailing glow)
            smoothedLevel += (level - smoothedLevel) * 0.3

            // Core layer: sharp, bright, bottom 8px
            let coreOpacity = Float(0.5 + 0.5 * level)
            core.opacity = coreOpacity
            let coreSpread = 0.15 + 0.35 * Double(level)
            let coreLeft = NSNumber(value: 0.5 - coreSpread)
            let coreRight = NSNumber(value: 0.5 + coreSpread)
            core.locations = [0.0, coreLeft, coreRight, 1.0]
            core.colors = [NSColor.clear.cgColor, cgColor, cgColor, NSColor.clear.cgColor]

            // Bloom layer: wider, hue-shifted, uses smoothed level for trailing glow
            let bloomOpacity = Float(0.5 + 0.5 * smoothedLevel)
            bloom.opacity = bloomOpacity
            let bloomSpread = 0.10 + 0.40 * Double(smoothedLevel)
            let bloomLeft = NSNumber(value: 0.5 - bloomSpread)
            let bloomRight = NSNumber(value: 0.5 + bloomSpread)
            bloom.locations = [0.0, bloomLeft, bloomRight, 1.0]
            let shifted = Self.shiftedColor(color).cgColor
            bloom.colors = [NSColor.clear.cgColor, shifted, shifted, NSColor.clear.cgColor]

        case .processing:
            smoothedLevel = 0.0
            let shifted = Self.shiftedColor(color).cgColor
            core.colors = [NSColor.clear.cgColor, cgColor, cgColor, NSColor.clear.cgColor]
            core.locations = [0.0, 0.3, 0.7, 1.0]
            core.opacity = 1.0
            bloom.colors = [NSColor.clear.cgColor, shifted, shifted, NSColor.clear.cgColor]
            bloom.locations = [0.0, 0.2, 0.8, 1.0]
            bloom.opacity = 0.5

            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.4
            pulse.toValue = 0.9
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            core.add(pulse, forKey: "pulse")

            let bloomPulse = CABasicAnimation(keyPath: "opacity")
            bloomPulse.fromValue = 0.2
            bloomPulse.toValue = 0.5
            bloomPulse.duration = 0.8
            bloomPulse.autoreverses = true
            bloomPulse.repeatCount = .infinity
            bloom.add(bloomPulse, forKey: "pulse")

        case .done, .error:
            smoothedLevel = 0.0
            let shifted = Self.shiftedColor(color).cgColor
            core.colors = [NSColor.clear.cgColor, cgColor, cgColor, NSColor.clear.cgColor]
            core.locations = [0.0, 0.3, 0.7, 1.0]
            core.opacity = 1.0
            bloom.colors = [NSColor.clear.cgColor, shifted, shifted, NSColor.clear.cgColor]
            bloom.locations = [0.0, 0.2, 0.8, 1.0]
            bloom.opacity = 0.5

            let flash = CAKeyframeAnimation(keyPath: "opacity")
            flash.values = [1.0, 1.0, 0.0]
            flash.keyTimes = [0, 0.5, 1.0]
            flash.duration = 0.6
            flash.isRemovedOnCompletion = false
            flash.fillMode = .forwards
            core.add(flash, forKey: "flash")

            let bloomFlash = CAKeyframeAnimation(keyPath: "opacity")
            bloomFlash.values = [0.5, 0.5, 0.0]
            bloomFlash.keyTimes = [0, 0.5, 1.0]
            bloomFlash.duration = 0.6
            bloomFlash.isRemovedOnCompletion = false
            bloomFlash.fillMode = .forwards
            bloom.add(bloomFlash, forKey: "flash")

        case .cancelled:
            break
        }

        textLayer?.isHidden = state != .loading
        window.orderFront(nil)
    }

    func hide() {
        smoothedLevel = 0.0
        bloomLayer?.removeAllAnimations()
        coreLayer?.removeAllAnimations()
        window?.orderOut(nil)
    }

    private func fadeOut() {
        guard let core = coreLayer, let bloom = bloomLayer else { return }
        core.removeAllAnimations()
        bloom.removeAllAnimations()

        let coreFade = CABasicAnimation(keyPath: "opacity")
        coreFade.fromValue = core.opacity
        coreFade.toValue = 0.0
        coreFade.duration = 0.2
        coreFade.isRemovedOnCompletion = false
        coreFade.fillMode = .forwards
        core.add(coreFade, forKey: "fadeOut")

        let bloomFade = CABasicAnimation(keyPath: "opacity")
        bloomFade.fromValue = bloom.opacity
        bloomFade.toValue = 0.0
        bloomFade.duration = 0.3
        bloomFade.isRemovedOnCompletion = false
        bloomFade.fillMode = .forwards
        bloom.add(bloomFade, forKey: "fadeOut")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.window?.orderOut(nil)
        }
    }

    private func setupWindowIfNeeded() {
        guard window == nil else { return }

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = NSRect(x: screen.frame.origin.x, y: screen.frame.origin.y,
                           width: screen.frame.width, height: Self.windowHeight)

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

        let clearColors = [NSColor.clear.cgColor, NSColor.clear.cgColor,
                           NSColor.clear.cgColor, NSColor.clear.cgColor]

        // Bloom layer: full window height, vertical fade from bottom
        let bloom = CAGradientLayer()
        bloom.frame = contentView.bounds
        bloom.type = .axial
        bloom.startPoint = CGPoint(x: 0, y: 0.5)
        bloom.endPoint = CGPoint(x: 1, y: 0.5)
        bloom.locations = [0.0, 0.3, 0.7, 1.0]
        bloom.colors = clearColors
        bloom.opacity = 0

        // Vertical fade mask: bright at bottom, rapid falloff upward
        let mask = CAGradientLayer()
        mask.frame = bloom.bounds
        mask.type = .axial
        mask.startPoint = CGPoint(x: 0.5, y: 0)  // bottom
        mask.endPoint = CGPoint(x: 0.5, y: 1)      // top
        mask.colors = [
            NSColor.white.cgColor,
            NSColor.white.withAlphaComponent(0.4).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ]
        mask.locations = [0.0, 0.3, 0.75]
        bloom.mask = mask

        contentView.layer?.addSublayer(bloom)

        // Core layer: bottom 8px, sharp bright glow
        let coreHeight: CGFloat = 10
        let core = CAGradientLayer()
        core.frame = CGRect(x: 0, y: 0, width: contentView.bounds.width, height: coreHeight)
        core.type = .axial
        core.startPoint = CGPoint(x: 0, y: 0.5)
        core.endPoint = CGPoint(x: 1, y: 0.5)
        core.locations = [0.0, 0.3, 0.7, 1.0]
        core.colors = clearColors
        core.opacity = 0
        contentView.layer?.addSublayer(core)

        let text = CATextLayer()
        text.string = "Loading model…"
        text.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        text.fontSize = 11
        text.foregroundColor = NSColor.white.withAlphaComponent(0.7).cgColor
        text.alignmentMode = .center
        text.contentsScale = (NSScreen.main?.backingScaleFactor ?? 2.0)
        text.frame = CGRect(x: 0, y: 4, width: contentView.bounds.width, height: 16)
        text.isHidden = true
        contentView.layer?.addSublayer(text)

        self.window = win
        self.bloomLayer = bloom
        self.coreLayer = core
        self.textLayer = text
    }

    private func repositionToMainScreen() {
        guard let window = window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = NSRect(x: screen.frame.origin.x, y: screen.frame.origin.y,
                           width: screen.frame.width, height: Self.windowHeight)
        window.setFrame(frame, display: true)

        let bounds = window.contentView?.bounds ?? frame
        bloomLayer?.frame = bounds
        (bloomLayer?.mask as? CALayer)?.frame = bounds

        let coreHeight: CGFloat = 10
        coreLayer?.frame = CGRect(x: 0, y: 0, width: bounds.width, height: coreHeight)
        textLayer?.frame = CGRect(x: 0, y: 4, width: bounds.width, height: 16)
    }
}
