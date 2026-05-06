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

    override func layoutSubviews() {
        super.layoutSubviews()
        applyRadius()
    }

    private func applyRadius() {
        // Walk the view hierarchy and adjust the inputRadius of any
        // gaussianBlur filter we find on a CALayer.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.adjust(view: self, radius: self.blurRadius)
        }
    }

    private func adjust(view: UIView, radius: CGFloat) {
        view.subviews.forEach { sub in
            sub.layer.filters?.forEach { filter in
                guard let nsf = filter as? NSObject,
                      nsf.value(forKey: "name") as? String == "gaussianBlur"
                else { return }
                nsf.setValue(radius, forKey: "inputRadius")
            }
            adjust(view: sub, radius: radius)
        }
    }
}
