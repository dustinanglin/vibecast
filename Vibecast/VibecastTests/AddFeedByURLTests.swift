import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class AddFeedByURLTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var fetcher: MockFeedFetcher!
    private var manager: SubscriptionManager!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)
        fetcher = MockFeedFetcher()
        manager = SubscriptionManager(
            searcher: MockSearchService(),
            fetcher: fetcher,
            importer: MockOPMLImporter(),
            modelContext: context
        )
    }

    private func feed(title: String = "Premium Show") -> ParsedFeed {
        ParsedFeed(
            podcastTitle: title,
            podcastAuthor: "Author",
            artworkURL: nil,
            episodes: [
                ParsedEpisode(title: "E1", publishDate: .now, descriptionText: "d", durationSeconds: 60, audioURL: "https://x/1.mp3", isExplicit: false),
            ]
        )
    }

    // MARK: - Reading what the user pasted

    func test_feedURL_fullHTTPSURL_isKept() {
        XCTAssertEqual(
            SubscriptionManager.feedURL(fromUserText: "https://example.com/feed.xml?token=abc123"),
            URL(string: "https://example.com/feed.xml?token=abc123")
        )
    }

    func test_feedURL_trimsWhitespaceAndNewlines() {
        XCTAssertEqual(
            SubscriptionManager.feedURL(fromUserText: "  https://example.com/feed \n"),
            URL(string: "https://example.com/feed")
        )
    }

    func test_feedURL_missingScheme_assumesHTTPS() {
        XCTAssertEqual(
            SubscriptionManager.feedURL(fromUserText: "example.com/private/feed"),
            URL(string: "https://example.com/private/feed")
        )
    }

    func test_feedURL_feedScheme_becomesHTTPS() {
        XCTAssertEqual(
            SubscriptionManager.feedURL(fromUserText: "feed://example.com/rss"),
            URL(string: "https://example.com/rss")
        )
    }

    func test_feedURL_emptyOrNotAURL_isNil() {
        XCTAssertNil(SubscriptionManager.feedURL(fromUserText: "   "))
        XCTAssertNil(SubscriptionManager.feedURL(fromUserText: "not a url"))
        XCTAssertNil(SubscriptionManager.feedURL(fromUserText: "mailto:someone@example.com"))
        XCTAssertNil(SubscriptionManager.feedURL(fromUserText: "https://"))
    }

    // MARK: - Subscribing

    func test_addFeed_validFeed_subscribesAndReportsTitle() async {
        fetcher.feed = feed()
        let result = await manager.addFeed(fromUserText: "example.com/private/feed")
        XCTAssertEqual(result, .added(title: "Premium Show"))
        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.map(\.feedURL), ["https://example.com/private/feed"])
    }

    func test_addFeed_alreadySubscribed_reportsItAndAddsNothing() async {
        context.insert(Podcast(title: "Have", author: "", artworkURL: nil, feedURL: "https://example.com/feed"))
        try! context.save()
        fetcher.feed = feed()
        let result = await manager.addFeed(fromUserText: "https://example.com/feed")
        XCTAssertEqual(result, .alreadySubscribed)
        XCTAssertEqual(try! context.fetchCount(FetchDescriptor<Podcast>()), 1)
    }

    func test_addFeed_unreadableText_reportsInvalidURL() async {
        let result = await manager.addFeed(fromUserText: "not a url")
        XCTAssertEqual(result, .invalidURL)
    }

    func test_addFeed_fetchFails_reportsFailureAndAddsNothing() async {
        fetcher.error = URLError(.badServerResponse)
        let result = await manager.addFeed(fromUserText: "https://example.com/feed")
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(try! context.fetchCount(FetchDescriptor<Podcast>()), 0)
    }
}
