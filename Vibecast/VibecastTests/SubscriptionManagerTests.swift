import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var searcher: MockSearchService!
    var fetcher: MockFeedFetcher!
    var manager: SubscriptionManager!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)
        searcher = MockSearchService()
        fetcher = MockFeedFetcher()
        manager = SubscriptionManager(searcher: searcher, fetcher: fetcher, modelContext: context)
    }

    private func makeResult() -> PodcastSearchResult {
        PodcastSearchResult(
            id: 42,
            title: "Hard Fork",
            author: "NYT",
            artworkURL: URL(string: "https://x/a.jpg"),
            feedURL: URL(string: "https://feeds.example.com/hardfork")!
        )
    }

    private func sampleFeed() -> ParsedFeed {
        ParsedFeed(
            podcastTitle: "Hard Fork",
            podcastAuthor: "NYT",
            artworkURL: nil,
            episodes: [
                ParsedEpisode(title: "E1", publishDate: .now, descriptionText: "d1", durationSeconds: 1800, audioURL: "https://x/1.mp3", isExplicit: false),
                ParsedEpisode(title: "E2", publishDate: .now.addingTimeInterval(-86400), descriptionText: "d2", durationSeconds: 1500, audioURL: "https://x/2.mp3", isExplicit: false),
            ]
        )
    }

    func test_subscribe_insertsPodcastRowImmediately() async {
        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)
        XCTAssertEqual(podcasts[0].title, "Hard Fork")
        XCTAssertEqual(podcasts[0].iTunesCollectionId, 42)
    }

    func test_subscribe_populatesEpisodesAfterFetch() async {
        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts[0].episodes.count, 2)
        XCTAssertNotNil(podcasts[0].lastFetchedAt)
    }

    func test_subscribe_appendsAtBottomOfSortOrder() async {
        let existing = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: "https://a/", sortPosition: 0)
        context.insert(existing)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)]))
        XCTAssertEqual(podcasts.count, 2)
        XCTAssertEqual(podcasts[1].title, "Hard Fork")
        XCTAssertEqual(podcasts[1].sortPosition, 1)
    }

    func test_subscribe_dedupesByFeedURL() async {
        let existing = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: "https://feeds.example.com/hardfork")
        context.insert(existing)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1) // no duplicate
        XCTAssertEqual(podcasts[0].title, "A") // existing record left alone
    }

    func test_isSubscribed_truthyWhenFeedURLMatches() async {
        let existing = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: "https://feeds.example.com/hardfork")
        context.insert(existing)
        try! context.save()

        XCTAssertTrue(manager.isSubscribed(feedURL: URL(string: "https://feeds.example.com/hardfork")!))
        XCTAssertFalse(manager.isSubscribed(feedURL: URL(string: "https://feeds.example.com/other")!))
    }

    func test_subscribe_clearsInFlightOnSuccess() async {
        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())
        XCTAssertTrue(manager.inFlightSubscriptions.isEmpty)
    }

    func test_subscribe_skipsRowOnFetchFailure() async {
        fetcher.error = URLError(.notConnectedToInternet)
        await manager.subscribe(to: makeResult())

        // No stub row left behind — feed fetch is required before insert
        // because the user has no recovery path until Plan 4 adds refresh.
        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 0)
        XCTAssertTrue(manager.inFlightSubscriptions.isEmpty)
    }

    func test_subscribe_recordsFailedSubscribeOnFetchFailure() async {
        fetcher.error = URLError(.notConnectedToInternet)
        let result = makeResult()
        await manager.subscribe(to: result)

        XCTAssertTrue(manager.failedSubscribes.contains(result.feedURL))
    }

    func test_subscribe_clearsFailedSubscribeOnRetrySuccess() async {
        let result = makeResult()
        fetcher.error = URLError(.notConnectedToInternet)
        await manager.subscribe(to: result)
        XCTAssertTrue(manager.failedSubscribes.contains(result.feedURL))

        // Retry: failure flag cleared at start of subscribe, then a successful
        // fetch leaves it cleared.
        fetcher.error = nil
        fetcher.feed = sampleFeed()
        await manager.subscribe(to: result)
        XCTAssertFalse(manager.failedSubscribes.contains(result.feedURL))

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)
    }
}

// MARK: - Test Doubles

@MainActor
final class MockSearchService: PodcastSearchService {
    var results: [PodcastSearchResult] = []
    var error: Error?

    func search(_ query: String) async throws -> [PodcastSearchResult] {
        if let error { throw error }
        return results
    }
}

@MainActor
final class MockFeedFetcher: FeedFetcher {
    var feed: ParsedFeed?
    var error: Error?

    func fetch(_ feedURL: URL) async throws -> ParsedFeed {
        if let error { throw error }
        return feed ?? ParsedFeed(podcastTitle: nil, podcastAuthor: nil, artworkURL: nil, episodes: [])
    }
}
