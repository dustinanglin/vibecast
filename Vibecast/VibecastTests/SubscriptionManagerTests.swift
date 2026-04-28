import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var searcher: MockSearchService!
    var fetcher: MockFeedFetcher!
    var importer: MockOPMLImporter!
    var manager: SubscriptionManager!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)
        searcher = MockSearchService()
        fetcher = MockFeedFetcher()
        importer = MockOPMLImporter()
        manager = SubscriptionManager(
            searcher: searcher,
            fetcher: fetcher,
            importer: importer,
            modelContext: context
        )
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

    func test_subscribeFeedURL_insertsRowOnSuccess() async {
        let url = URL(string: "https://feeds.example.com/podcastA")!
        fetcher.feed = ParsedFeed(
            podcastTitle: "Parsed Title",
            podcastAuthor: "Parsed Author",
            artworkURL: URL(string: "https://example.com/art.jpg"),
            episodes: [
                ParsedEpisode(title: "E1", publishDate: .now, descriptionText: "d", durationSeconds: 1800, audioURL: "https://x/1.mp3", isExplicit: false),
            ]
        )
        await manager.subscribe(to: url)

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)
        XCTAssertEqual(podcasts[0].title, "Parsed Title")
        XCTAssertEqual(podcasts[0].author, "Parsed Author")
        XCTAssertEqual(podcasts[0].artworkURL, "https://example.com/art.jpg")
        XCTAssertEqual(podcasts[0].feedURL, url.absoluteString)
        XCTAssertNil(podcasts[0].iTunesCollectionId)  // no iTunes metadata for OPML path
        XCTAssertEqual(podcasts[0].episodes.count, 1)
    }

    func test_subscribeFeedURL_skipsRowOnFetchFailure() async {
        fetcher.error = URLError(.notConnectedToInternet)
        await manager.subscribe(to: URL(string: "https://feeds.example.com/podcastA")!)

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 0)
    }

    func test_subscribeFeedURL_dedupesByFeedURL() async {
        let url = URL(string: "https://feeds.example.com/podcastA")!
        let existing = Podcast(title: "Already", author: "Subscribed", artworkURL: nil, feedURL: url.absoluteString)
        context.insert(existing)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.subscribe(to: url)

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)
        XCTAssertEqual(podcasts[0].title, "Already")  // existing record left alone
    }

    func test_importOPML_addsSucceeded_skipsAlreadySubscribed() async throws {
        // Pre-subscribe one feed (so it counts in alreadySubscribed)
        let preexistingURL = URL(string: "https://feeds.example.com/preexisting")!
        let existing = Podcast(title: "Pre", author: "P", artworkURL: nil, feedURL: preexistingURL.absoluteString)
        context.insert(existing)
        try! context.save()

        importer.urls = [
            preexistingURL,                                      // already subscribed
            URL(string: "https://feeds.example.com/new1")!,      // succeeds
            URL(string: "https://feeds.example.com/new2")!,      // succeeds
        ]
        fetcher.feed = sampleFeed()

        try await manager.importOPML(from: Data())

        XCTAssertEqual(manager.lastImportSummary?.attempted, 3)
        XCTAssertEqual(manager.lastImportSummary?.succeeded, 2)
        XCTAssertEqual(manager.lastImportSummary?.alreadySubscribed, 1)
        XCTAssertEqual(manager.lastImportSummary?.failed, 0)
    }

    func test_importOPML_tallisFailedSubscribes() async throws {
        importer.urls = [
            URL(string: "https://feeds.example.com/good")!,
            URL(string: "https://feeds.example.com/bad")!,
        ]
        // Fetcher fails on every call — both attempts fail. Use this to verify
        // failed counts; mid-loop selectivity is not necessary for this contract.
        fetcher.error = URLError(.notConnectedToInternet)

        try await manager.importOPML(from: Data())

        XCTAssertEqual(manager.lastImportSummary?.attempted, 2)
        XCTAssertEqual(manager.lastImportSummary?.succeeded, 0)
        XCTAssertEqual(manager.lastImportSummary?.failed, 2)
    }

    func test_importOPML_setsLastImportSummary() async throws {
        XCTAssertNil(manager.lastImportSummary)

        importer.urls = [URL(string: "https://feeds.example.com/x")!]
        fetcher.feed = sampleFeed()
        try await manager.importOPML(from: Data())

        XCTAssertNotNil(manager.lastImportSummary)
    }

    func test_importOPML_throwsOnMalformedFile() async {
        importer.error = OPMLImportError.malformed(line: 1, column: 1)

        do {
            try await manager.importOPML(from: Data())
            XCTFail("expected throw")
        } catch let error as OPMLImportError {
            if case .malformed = error { /* pass */ } else {
                XCTFail("expected .malformed, got \(error)")
            }
        } catch {
            XCTFail("expected OPMLImportError, got \(error)")
        }
    }

    func test_refreshAll_iteratesAllSubscribedPodcasts() async {
        let urlA = "https://feeds.example.com/a"
        let urlB = "https://feeds.example.com/b"
        context.insert(Podcast(title: "A", author: "A", artworkURL: nil, feedURL: urlA))
        context.insert(Podcast(title: "B", author: "B", artworkURL: nil, feedURL: urlB))
        try! context.save()

        var fetchedURLs: [URL] = []
        fetcher.feed = sampleFeed()
        fetcher.beforeFetch = { url in fetchedURLs.append(url) }

        await manager.refreshAll()

        XCTAssertEqual(Set(fetchedURLs.map(\.absoluteString)), [urlA, urlB])
    }

    func test_refreshAll_mergesEpisodesByAudioURL_preservingUserState() async {
        let url = URL(string: "https://feeds.example.com/a")!
        let podcast = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: url.absoluteString)
        context.insert(podcast)

        // Pre-existing episode with user state
        let existing = Episode(
            podcast: podcast,
            title: "OLD title",
            publishDate: .now.addingTimeInterval(-86400),
            descriptionText: "old desc",
            durationSeconds: 1000,
            audioURL: "https://x/1.mp3"
        )
        existing.playbackPosition = 250
        existing.listenedStatus = .inProgress
        context.insert(existing)
        podcast.episodes.append(existing)
        try! context.save()

        // Fetch returns: 1 update for the same audioURL, 1 net-new episode
        fetcher.feed = ParsedFeed(
            podcastTitle: nil, podcastAuthor: nil, artworkURL: nil,
            episodes: [
                ParsedEpisode(title: "NEW title", publishDate: .now, descriptionText: "new desc", durationSeconds: 1500, audioURL: "https://x/1.mp3", isExplicit: false),
                ParsedEpisode(title: "Brand new", publishDate: .now, descriptionText: "n", durationSeconds: 600, audioURL: "https://x/2.mp3", isExplicit: false),
            ]
        )

        await manager.refreshAll()

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.first?.episodes.count, 2)
        let updated = podcasts.first?.episodes.first { $0.audioURL == "https://x/1.mp3" }
        XCTAssertEqual(updated?.title, "NEW title")          // metadata refreshed
        XCTAssertEqual(updated?.descriptionText, "new desc") // metadata refreshed
        XCTAssertEqual(updated?.durationSeconds, 1500)       // metadata refreshed
        XCTAssertEqual(updated?.playbackPosition, 250)       // user state preserved
        XCTAssertEqual(updated?.listenedStatus, .inProgress) // user state preserved
    }

    func test_refresh_skipsWhenLastFetchedAtIsRecent() async {
        let podcast = Podcast(
            title: "A", author: "A", artworkURL: nil,
            feedURL: "https://feeds.example.com/a",
            lastFetchedAt: .now  // just-fetched
        )
        context.insert(podcast)
        try! context.save()

        var fetchCount = 0
        fetcher.feed = sampleFeed()
        fetcher.beforeFetch = { _ in fetchCount += 1 }

        await manager.refresh(podcast)

        XCTAssertEqual(fetchCount, 0)
    }

    func test_refresh_updatesLastFetchedAtOnSuccess() async {
        let podcast = Podcast(
            title: "A", author: "A", artworkURL: nil,
            feedURL: "https://feeds.example.com/a",
            lastFetchedAt: .now.addingTimeInterval(-3600)  // an hour ago
        )
        context.insert(podcast)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.refresh(podcast)

        XCTAssertNotNil(podcast.lastFetchedAt)
        XCTAssertGreaterThan(podcast.lastFetchedAt!, .now.addingTimeInterval(-5))
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
    var beforeFetch: ((URL) -> Void)?

    func fetch(_ feedURL: URL) async throws -> ParsedFeed {
        beforeFetch?(feedURL)
        if let error { throw error }
        return feed ?? ParsedFeed(podcastTitle: nil, podcastAuthor: nil, artworkURL: nil, episodes: [])
    }
}

@MainActor
final class MockOPMLImporter: OPMLImporter {
    var urls: [URL] = []
    var error: Error?

    func extractFeedURLs(from data: Data) throws -> [URL] {
        if let error { throw error }
        return urls
    }
}
