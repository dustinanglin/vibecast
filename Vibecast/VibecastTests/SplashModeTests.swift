import XCTest
@testable import Vibecast

final class SplashModeTests: XCTestCase {

    func test_splashMode_returnsFullWhenFlagAbsent() {
        let suiteName = "test.splash.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        XCTAssertEqual(VibecastApp.splashMode(defaults: defaults), .full)
    }

    func test_splashMode_returnsBriefWhenFlagSet() {
        let suiteName = "test.splash.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: VibecastApp.hasCompletedFirstLaunchKey)
        XCTAssertEqual(VibecastApp.splashMode(defaults: defaults), .brief)
    }
}
