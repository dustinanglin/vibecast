import XCTest
import UIKit
@testable import Vibecast

@MainActor
final class DuoPoseTests: XCTestCase {
    func test_supportedOrientations_notFoldable_isPortrait() {
        XCTAssertEqual(DuoPose.notFoldable.supportedOrientations, .portrait)
    }

    func test_supportedOrientations_closed_isPortrait() {
        XCTAssertEqual(DuoPose.closed.supportedOrientations, .portrait)
    }

    func test_supportedOrientations_partiallyOpen_allowsLandscape() {
        XCTAssertEqual(DuoPose.partiallyOpen.supportedOrientations, .allButUpsideDown)
    }

    func test_supportedOrientations_fullyOpen_allowsLandscape() {
        XCTAssertEqual(DuoPose.fullyOpen.supportedOrientations, .allButUpsideDown)
    }

    func test_monitor_update_changesPose() {
        let monitor = DuoPoseMonitor()
        XCTAssertEqual(monitor.pose, .notFoldable)
        monitor.update(.fullyOpen)
        XCTAssertEqual(monitor.pose, .fullyOpen)
    }
}
