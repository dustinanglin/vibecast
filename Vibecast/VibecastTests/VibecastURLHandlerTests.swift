import XCTest
@testable import Vibecast

@MainActor
final class VibecastURLHandlerTests: XCTestCase {

    // MARK: - parseImportFeedsURL

    func test_parse_singleFeed() {
        let url = URL(string: "vibecast://import-feeds?urls=https%3A%2F%2Fa.example%2Ffeed.xml")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://a.example/feed.xml")!])
    }

    func test_parse_multipleFeeds_newlineSeparated() {
        // Newline-joined: %0A is URL-encoded \n
        let encoded = [
            "https%3A%2F%2Fa.example%2Ffeed.xml",
            "https%3A%2F%2Fb.example%2Ffeed.xml",
            "https%3A%2F%2Fc.example%2Ffeed.xml",
        ].joined(separator: "%0A")
        let url = URL(string: "vibecast://import-feeds?urls=\(encoded)")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [
            URL(string: "https://a.example/feed.xml")!,
            URL(string: "https://b.example/feed.xml")!,
            URL(string: "https://c.example/feed.xml")!,
        ])
    }

    func test_parse_trailingNewline_ignored() {
        let url = URL(string: "vibecast://import-feeds?urls=https%3A%2F%2Fa.example%2Ffeed.xml%0A")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://a.example/feed.xml")!])
    }

    func test_parse_dedupes_duplicateURLs() {
        let encoded = "https%3A%2F%2Fa.example%2Ffeed.xml%0Ahttps%3A%2F%2Fa.example%2Ffeed.xml"
        let url = URL(string: "vibecast://import-feeds?urls=\(encoded)")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://a.example/feed.xml")!])
    }

    func test_parse_filtersOutMalformedURLs() {
        // Mix of valid + obviously-bogus
        let encoded = "https%3A%2F%2Fvalid.example%2Ffeed.xml%0Anot%20a%20url"
        let url = URL(string: "vibecast://import-feeds?urls=\(encoded)")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://valid.example/feed.xml")!])
    }

    func test_parse_emptyUrlsParam_returnsEmpty() {
        let url = URL(string: "vibecast://import-feeds?urls=")!
        XCTAssertEqual(VibecastURLHandler.parseImportFeedsURL(url), [])
    }

    func test_parse_missingUrlsParam_returnsEmpty() {
        let url = URL(string: "vibecast://import-feeds")!
        XCTAssertEqual(VibecastURLHandler.parseImportFeedsURL(url), [])
    }

    // MARK: - handle

    func test_handle_validImportFeedsURL_writesToSession() {
        let session = ApplePodcastsImportSession()
        let url = URL(string: "vibecast://import-feeds?urls=https%3A%2F%2Fa.example%2Ffeed.xml")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertTrue(handled)
        XCTAssertEqual(session.pendingFeedURLs, [URL(string: "https://a.example/feed.xml")!])
        XCTAssertTrue(session.shouldPresentWizard)
    }

    func test_handle_emptyList_stillWritesEmptyArray() {
        // The wizard needs to distinguish "no shortcut run yet" (nil) from
        // "shortcut ran but returned 0 feeds" (empty array). The handler
        // writes [] for an empty payload so the wizard can show the
        // "all Apple Originals" message.
        let session = ApplePodcastsImportSession()
        let url = URL(string: "vibecast://import-feeds?urls=")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertTrue(handled)
        XCTAssertEqual(session.pendingFeedURLs, [])
        XCTAssertTrue(session.shouldPresentWizard)
    }

    func test_handle_unknownHost_returnsFalse() {
        let session = ApplePodcastsImportSession()
        let url = URL(string: "vibecast://unknown-action?x=y")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertFalse(handled)
        XCTAssertNil(session.pendingFeedURLs)
    }

    func test_handle_wrongScheme_returnsFalse() {
        let session = ApplePodcastsImportSession()
        let url = URL(string: "https://import-feeds?urls=...")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertFalse(handled)
    }
}
