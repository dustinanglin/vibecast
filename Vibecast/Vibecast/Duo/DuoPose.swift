import SwiftUI
import UIKit

/// How an iPhone Duo is currently folded. Every other iPhone reports
/// `notFoldable` and keeps the single-screen, portrait-only behavior.
enum DuoPose: Equatable {
    case notFoldable
    case closed
    case partiallyOpen
    case fullyOpen

    /// Landscape is only offered on the inner display; the outer display and
    /// ordinary iPhones stay portrait.
    var supportedOrientations: UIInterfaceOrientationMask {
        switch self {
        case .notFoldable, .closed: return .portrait
        case .partiallyOpen, .fullyOpen: return .allButUpsideDown
        }
    }
}

@Observable
@MainActor
final class DuoPoseMonitor {
    static let shared = DuoPoseMonitor()

    private(set) var pose: DuoPose = .notFoldable

    func update(_ newPose: DuoPose) {
        guard newPose != pose else { return }
        pose = newPose
    }
}

extension EnvironmentValues {
    @Entry var duoPose: DuoPose = .notFoldable
}
