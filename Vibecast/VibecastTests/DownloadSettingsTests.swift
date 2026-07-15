import XCTest
@testable import Vibecast

final class DownloadSettingsTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.downloads.\(UUID().uuidString)")!
    }

    func test_defaults_whenNothingStored() {
        let d = freshDefaults()
        XCTAssertTrue(DownloadSettings.autoDownloadEnabled(defaults: d))
        XCTAssertEqual(DownloadSettings.keepLastN(defaults: d), 3)
        XCTAssertFalse(DownloadSettings.deleteWhenPlayed(defaults: d))
        XCTAssertTrue(DownloadSettings.wifiOnly(defaults: d))
    }

    func test_roundTrips() {
        let d = freshDefaults()
        DownloadSettings.setAutoDownloadEnabled(false, defaults: d)
        DownloadSettings.setKeepLastN(10, defaults: d)
        DownloadSettings.setDeleteWhenPlayed(true, defaults: d)
        DownloadSettings.setWifiOnly(false, defaults: d)
        XCTAssertFalse(DownloadSettings.autoDownloadEnabled(defaults: d))
        XCTAssertEqual(DownloadSettings.keepLastN(defaults: d), 10)
        XCTAssertTrue(DownloadSettings.deleteWhenPlayed(defaults: d))
        XCTAssertFalse(DownloadSettings.wifiOnly(defaults: d))
    }

    func test_keepLastN_zeroMeansUnlimited_roundTrips() {
        let d = freshDefaults()
        DownloadSettings.setKeepLastN(0, defaults: d)
        XCTAssertEqual(DownloadSettings.keepLastN(defaults: d), 0)
    }
}
