import XCTest
@testable import Vibecast

final class DownloadStoreTests: XCTestCase {

    override func tearDown() {
        DownloadStore.deleteAll()
        super.tearDown()
    }

    func test_fileURL_isStableForSameInput() {
        let a = DownloadStore.fileURL(for: "https://example.com/ep1.mp3")
        let b = DownloadStore.fileURL(for: "https://example.com/ep1.mp3")
        XCTAssertEqual(a, b)
    }

    func test_fileURL_differsForDifferentInputs() {
        let a = DownloadStore.fileURL(for: "https://example.com/ep1.mp3")
        let b = DownloadStore.fileURL(for: "https://example.com/ep2.mp3")
        XCTAssertNotEqual(a, b)
    }

    func test_fileURL_preservesKnownAudioExtension() {
        XCTAssertEqual(DownloadStore.fileURL(for: "https://example.com/ep.m4a").pathExtension, "m4a")
    }

    func test_fileURL_fallsBackToMp3ForUnknownExtension() {
        XCTAssertEqual(DownloadStore.fileURL(for: "https://example.com/stream?id=42").pathExtension, "mp3")
        XCTAssertEqual(DownloadStore.fileURL(for: "https://example.com/ep.php").pathExtension, "mp3")
    }

    func test_fileURL_queryStringVariantsHashDifferently() {
        let a = DownloadStore.fileURL(for: "https://example.com/ep.mp3?token=1")
        let b = DownloadStore.fileURL(for: "https://example.com/ep.mp3?token=2")
        XCTAssertNotEqual(a, b)
    }

    func test_storeExistsDeleteAndTotalBytes_lifecycle() throws {
        let audioURL = "https://example.com/lifecycle-\(UUID().uuidString).mp3"
        XCTAssertFalse(DownloadStore.exists(for: audioURL))

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let payload = Data(repeating: 0xAB, count: 1024)
        try payload.write(to: temp)

        let stored = try DownloadStore.store(tempFile: temp, for: audioURL)
        XCTAssertTrue(DownloadStore.exists(for: audioURL))
        XCTAssertEqual(stored, DownloadStore.fileURL(for: audioURL))
        XCTAssertGreaterThanOrEqual(DownloadStore.totalBytes(), 1024)

        DownloadStore.delete(for: audioURL)
        XCTAssertFalse(DownloadStore.exists(for: audioURL))
    }
}
