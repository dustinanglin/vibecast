import UIKit

/// Observes the hinge and tells the system which orientations the scene
/// supports. Info.plist stays portrait-only; this widens it for an open Duo.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    private var observedWindow: UIWindow?

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        observeHinge(in: windowScene)
    }

    func supportedInterfaceOrientations(for windowScene: UIWindowScene) -> UIInterfaceOrientationMask {
        DuoPoseMonitor.shared.pose.supportedOrientations
    }

    private func observeHinge(in windowScene: UIWindowScene) {
        guard #available(iOS 27.1, *) else { return }
        guard let window = windowScene.keyWindow ?? windowScene.windows.first,
              window !== observedWindow else { return }
        observedWindow = window
        let interaction = UIHingeInteraction { [weak window] _, update in
            DuoPoseMonitor.shared.update(Self.pose(for: update.hinge))
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        window.addInteraction(interaction)
    }

    @available(iOS 27.1, *)
    private static func pose(for hinge: UIHinge?) -> DuoPose {
        guard let hinge else { return .notFoldable }
        switch hinge.status {
        case .partiallyOpen: return .partiallyOpen
        case .fullyOpen: return .fullyOpen
        case .closed, .unknown: return .closed
        @unknown default: return .closed
        }
    }
}
