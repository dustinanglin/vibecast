import SwiftUI
import UIKit
import os

/// Invisible view that watches the iPhone Duo hinge and publishes the pose
/// to `DuoPoseMonitor`. Lives in the SwiftUI hierarchy rather than a scene
/// delegate: UIKit only asks for a scene configuration when a session is
/// first created, so a delegate added in an update would never be attached
/// for people upgrading from an earlier version.
struct HingeObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        if #available(iOS 27.1, *) {
            view.addInteraction(UIHingeInteraction { [weak view] _, update in
                Self.publish(Self.pose(for: update.hinge), from: view)
            })
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private static let logger = Logger(subsystem: "Vibecast", category: "DuoPose")

    @MainActor
    private static func publish(_ pose: DuoPose, from view: UIView?) {
        let monitor = DuoPoseMonitor.shared
        guard pose != monitor.pose else { return }
        logger.notice("pose changed: \(String(describing: pose), privacy: .public)")
        monitor.update(pose)
        // The app delegate's answer depends on the pose; ask UIKit to re-read it.
        view?.window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
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
