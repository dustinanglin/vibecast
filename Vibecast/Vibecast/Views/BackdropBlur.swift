import SwiftUI
import UIKit

/// UIKit-bridged backdrop blur with a tunable radius. SwiftUI's `Material`
/// types render fully opaque in our List + `.scrollContentBackground(.hidden)`
/// + light-mode stack, AND their fixed ~20pt Gaussian radius blurs text into
/// unreadability. We drop into `UIVisualEffectView` and reach into the
/// underlying `gaussianBlur` filter to dial the radius down.
///
/// Use as the deepest `.background` layer (so it sees what's behind), with
/// any paper tint applied on top.
///
/// Note: setting `inputRadius` on the filter uses semi-private CALayer
/// behavior. It has been stable across iOS versions and is widely used, but
/// is technically not part of the public SDK. Acceptable for TestFlight; if
/// App Review ever flags it, switch to a system Material at the cost of the
/// tunable radius.
struct BackdropBlur: UIViewRepresentable {
    var radius: CGFloat = 6
    var style: UIBlurEffect.Style = .systemUltraThinMaterial

    func makeUIView(context: Context) -> TunableBlurView {
        TunableBlurView(blurRadius: radius, style: style)
    }

    func updateUIView(_ uiView: TunableBlurView, context: Context) {
        uiView.update(radius: radius, style: style)
    }
}

final class TunableBlurView: UIVisualEffectView {
    private var blurRadius: CGFloat

    init(blurRadius: CGFloat, style: UIBlurEffect.Style) {
        self.blurRadius = blurRadius
        super.init(effect: UIBlurEffect(style: style))
        applyRadius()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(radius: CGFloat, style: UIBlurEffect.Style) {
        if effect as? UIBlurEffect != UIBlurEffect(style: style) {
            effect = UIBlurEffect(style: style)
        }
        if radius != blurRadius {
            blurRadius = radius
        }
        applyRadius()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        // Cold-launch fix. UIVisualEffectView caches its first backdrop
        // render at view appearance time; setting `inputRadius` afterward
        // updates the filter but not the cached render, leaving the
        // visible blur at the system default until something invalidates
        // (background/foreground does it for free, which is the bug we
        // saw). Toggling `effect` off→on forces UIKit to rebuild the
        // backdrop with our radius applied.
        if let savedEffect = effect {
            effect = nil
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.effect = savedEffect
                self.applyRadius()
            }
        } else {
            applyRadius()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyRadius()
    }

    /// UIVisualEffectView creates its backdrop subview + gaussianBlur filter
    /// lazily. On a fresh app launch the filter often doesn't exist yet when
    /// the first applyRadius runs, so we retry on the run-loop until it
    /// appears (or we hit the cap). Once we land it once, the radius sticks.
    private func applyRadius(retriesLeft: Int = 30) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.adjust(view: self, radius: self.blurRadius) { return }
            guard retriesLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
                self?.applyRadius(retriesLeft: retriesLeft - 1)
            }
        }
    }

    /// Returns true if at least one gaussianBlur filter was found and updated.
    @discardableResult
    private func adjust(view: UIView, radius: CGFloat) -> Bool {
        var found = false
        view.subviews.forEach { sub in
            sub.layer.filters?.forEach { filter in
                guard let nsf = filter as? NSObject,
                      nsf.value(forKey: "name") as? String == "gaussianBlur"
                else { return }
                nsf.setValue(radius, forKey: "inputRadius")
                found = true
            }
            if adjust(view: sub, radius: radius) {
                found = true
            }
        }
        return found
    }
}
