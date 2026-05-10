import XCTest
import SwiftUI
@testable import Vibecast

final class VibeColorTests: XCTestCase {
    func test_allKeys_haveDistinctColors() {
        let keys = VibeColorKey.allCases
        XCTAssertEqual(keys.count, 5)
        let bands = Set(keys.map { $0.bandHex })
        XCTAssertEqual(bands.count, 5, "all band hexes should be distinct")
    }

    func test_morningBand_matchesSpec() {
        XCTAssertEqual(VibeColorKey.morning.bandHex, 0xD89A4F)
    }

    func test_storageRawValue_isStable() {
        XCTAssertEqual(VibeColorKey.morning.rawValue, "morning")
        XCTAssertEqual(VibeColorKey(rawValue: "morning"), .morning)
    }
}
