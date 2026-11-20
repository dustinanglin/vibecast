import XCTest
@testable import Vibecast

final class DownloadProgressBufferTests: XCTestCase {

    func test_record_firstValue_asksForFlush() {
        let buffer = DownloadProgressBuffer()
        XCTAssertTrue(buffer.record(fraction: 0.1, for: "a"))
    }

    func test_record_whileFlushPending_doesNotAskAgain() {
        let buffer = DownloadProgressBuffer()
        _ = buffer.record(fraction: 0.1, for: "a")
        XCTAssertFalse(buffer.record(fraction: 0.2, for: "a"))
        XCTAssertFalse(buffer.record(fraction: 0.5, for: "b"))
    }

    func test_drain_returnsLatestValuePerKey_andEmptiesBuffer() {
        let buffer = DownloadProgressBuffer()
        _ = buffer.record(fraction: 0.1, for: "a")
        _ = buffer.record(fraction: 0.4, for: "a")
        _ = buffer.record(fraction: 0.5, for: "b")
        XCTAssertEqual(buffer.drain(), ["a": 0.4, "b": 0.5])
        XCTAssertEqual(buffer.drain(), [:])
    }

    func test_record_afterDrain_asksForFlushAgain() {
        let buffer = DownloadProgressBuffer()
        _ = buffer.record(fraction: 0.1, for: "a")
        _ = buffer.drain()
        XCTAssertTrue(buffer.record(fraction: 0.2, for: "a"))
    }
}
