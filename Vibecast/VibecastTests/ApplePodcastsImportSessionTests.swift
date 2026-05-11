import XCTest
@testable import Vibecast

@MainActor
final class ApplePodcastsImportSessionTests: XCTestCase {
    func test_initial_state_isEmpty() {
        let s = ApplePodcastsImportSession()
        XCTAssertNil(s.pendingFeedURLs)
        XCTAssertNil(s.receivedAt)
        XCTAssertFalse(s.shouldPresentWizard)
        XCTAssertFalse(s.isFresh)
    }

    func test_receive_setsAllFields() {
        let s = ApplePodcastsImportSession()
        let urls = [URL(string: "https://a.example/feed.xml")!,
                    URL(string: "https://b.example/feed.xml")!]
        s.receive(urls)
        XCTAssertEqual(s.pendingFeedURLs, urls)
        XCTAssertNotNil(s.receivedAt)
        XCTAssertTrue(s.shouldPresentWizard)
        XCTAssertTrue(s.isFresh)
    }

    func test_isFresh_falseAfterFiveMinutes() {
        let s = ApplePodcastsImportSession()
        s.receive([URL(string: "https://a.example/feed.xml")!])
        // Simulate clock advance: directly stomp receivedAt back in time.
        s.receivedAt = Date().addingTimeInterval(-301)
        XCTAssertFalse(s.isFresh)
    }

    func test_clear_resetsAllFields() {
        let s = ApplePodcastsImportSession()
        s.receive([URL(string: "https://a.example/feed.xml")!])
        s.clear()
        XCTAssertNil(s.pendingFeedURLs)
        XCTAssertNil(s.receivedAt)
        XCTAssertFalse(s.shouldPresentWizard)
    }
}
