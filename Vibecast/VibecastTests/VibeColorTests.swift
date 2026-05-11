import XCTest
import SwiftUI
@testable import Vibecast

final class VibeColorTests: XCTestCase {
    func test_allKeys_haveDistinctColors() {
        let keys = VibeColorKey.allCases
        XCTAssertEqual(keys.count, 5)
        XCTAssertEqual(Set(keys.map { $0.bandHex }).count, 5, "all band hexes should be distinct")
        XCTAssertEqual(Set(keys.map { $0.chipHex }).count, 5, "all chip hexes should be distinct")
        XCTAssertEqual(Set(keys.map { $0.inkHex }).count, 5, "all ink hexes should be distinct")
    }

    func test_morningBand_matchesSpec() {
        XCTAssertEqual(VibeColorKey.morning.bandHex, 0xD89A4F)
    }

    func test_storageRawValue_isStable() {
        XCTAssertEqual(VibeColorKey.morning.rawValue, "morning")
        XCTAssertEqual(VibeColorKey(rawValue: "morning"), .morning)
    }

    /// Two-word default names ("Wind down", "Deep work") are easy to typo into
    /// "Winddown" / "Deepwork" on rename — pinned here as a regression guard.
    func test_defaultNames_matchSpec() {
        XCTAssertEqual(VibeColorKey.morning.defaultName, "Morning")
        XCTAssertEqual(VibeColorKey.around.defaultName, "Around")
        XCTAssertEqual(VibeColorKey.workout.defaultName, "Workout")
        XCTAssertEqual(VibeColorKey.winddown.defaultName, "Wind down")
        XCTAssertEqual(VibeColorKey.deepwork.defaultName, "Deep work")
    }
}
