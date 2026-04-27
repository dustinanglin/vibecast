import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SubscriptionManager {
    private(set) var inFlightSubscriptions: Set<URL> = []
    private(set) var failedSubscribes: Set<URL> = []
    private(set) var lastImportSummary: ImportSummary?
    private(set) var isImportingOPML: Bool = false

    /// Auto-clear duration for failed-subscribe state. Picked so a stale red
    /// error doesn't linger after the user has moved on.
    @ObservationIgnored private static let failureClearAfter: UInt64 = 5_000_000_000  // 5s

    @ObservationIgnored private let searcher: PodcastSearchService
    @ObservationIgnored private let fetcher: FeedFetcher
    @ObservationIgnored private let importer: OPMLImporter
    @ObservationIgnored private let modelContext: ModelContext

    init(
        searcher: PodcastSearchService,
        fetcher: FeedFetcher,
        importer: OPMLImporter,
        modelContext: ModelContext
    ) {
        self.searcher = searcher
        self.fetcher = fetcher
        self.importer = importer
        self.modelContext = modelContext
    }

    func search(_ query: String) async throws -> [PodcastSearchResult] {
        try await searcher.search(query)
    }

    func isSubscribed(feedURL: URL) -> Bool {
        let target = feedURL.absoluteString
        let descriptor = FetchDescriptor<Podcast>(predicate: #Predicate { $0.feedURL == target })
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    func subscribe(to result: PodcastSearchResult) async {
        guard !isSubscribed(feedURL: result.feedURL) else { return }

        // Clear any prior failure state so the row reverts to the spinner
        // when the user retries.
        failedSubscribes.remove(result.feedURL)

        inFlightSubscriptions.insert(result.feedURL)
        defer { inFlightSubscriptions.remove(result.feedURL) }

        // Fetch the RSS feed first. If it fails (offline, bad feed, server
        // error), do NOT insert a Podcast row — an episode-less row leaves
        // the user with no recovery path until Plan 4 adds pull-to-refresh.
        let feed: ParsedFeed
        do {
            feed = try await fetcher.fetch(result.feedURL)
        } catch {
            failedSubscribes.insert(result.feedURL)
            let url = result.feedURL
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: Self.failureClearAfter)
                self?.failedSubscribes.remove(url)
            }
            return
        }

        let nextSortPosition = nextAvailableSortPosition()
        let podcast = Podcast(
            title: result.title,
            author: result.author,
            artworkURL: result.artworkURL?.absoluteString,
            feedURL: result.feedURL.absoluteString,
            sortPosition: nextSortPosition,
            iTunesCollectionId: result.id
        )
        modelContext.insert(podcast)

        for parsed in feed.episodes {
            let episode = Episode(
                podcast: podcast,
                title: parsed.title,
                publishDate: parsed.publishDate,
                descriptionText: parsed.descriptionText,
                durationSeconds: parsed.durationSeconds,
                audioURL: parsed.audioURL
            )
            episode.isExplicit = parsed.isExplicit
            modelContext.insert(episode)
            podcast.episodes.append(episode)
        }
        podcast.lastFetchedAt = .now
        try? modelContext.save()
    }

    /// OPML path: subscribe by feed URL alone, with no iTunes metadata.
    /// Title/author/artwork come from the parsed RSS. Same fail-first contract
    /// as subscribe(to: PodcastSearchResult): if the RSS fetch fails, no
    /// Podcast row is inserted.
    func subscribe(to feedURL: URL) async {
        guard !isSubscribed(feedURL: feedURL) else { return }

        inFlightSubscriptions.insert(feedURL)
        defer { inFlightSubscriptions.remove(feedURL) }

        let feed: ParsedFeed
        do {
            feed = try await fetcher.fetch(feedURL)
        } catch {
            return
        }

        let nextSortPosition = nextAvailableSortPosition()
        let podcast = Podcast(
            title: feed.podcastTitle ?? feedURL.host ?? feedURL.absoluteString,
            author: feed.podcastAuthor ?? "",
            artworkURL: feed.artworkURL?.absoluteString,
            feedURL: feedURL.absoluteString,
            sortPosition: nextSortPosition
        )
        modelContext.insert(podcast)

        for parsed in feed.episodes {
            let episode = Episode(
                podcast: podcast,
                title: parsed.title,
                publishDate: parsed.publishDate,
                descriptionText: parsed.descriptionText,
                durationSeconds: parsed.durationSeconds,
                audioURL: parsed.audioURL
            )
            episode.isExplicit = parsed.isExplicit
            modelContext.insert(episode)
            podcast.episodes.append(episode)
        }
        podcast.lastFetchedAt = .now
        try? modelContext.save()
    }

    private func nextAvailableSortPosition() -> Int {
        let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition, order: .reverse)])
        let last = (try? modelContext.fetch(descriptor))?.first
        return (last?.sortPosition ?? -1) + 1
    }

    /// Parses OPML data, deduplicates within-file, iterates subscribe(to: URL)
    /// sequentially, and tallies an ImportSummary. Sets isImportingOPML true
    /// for the duration. Throws if the OPML data itself is malformed; per-feed
    /// failures are counted into the summary, not thrown.
    func importOPML(from data: Data) async throws {
        isImportingOPML = true
        defer { isImportingOPML = false }

        let urls = try importer.extractFeedURLs(from: data)
        var succeeded = 0
        var alreadySubscribed = 0
        var failed = 0

        for url in urls {
            if isSubscribed(feedURL: url) {
                alreadySubscribed += 1
                continue
            }
            let beforeCount = (try? modelContext.fetchCount(FetchDescriptor<Podcast>())) ?? 0
            await subscribe(to: url)
            let afterCount = (try? modelContext.fetchCount(FetchDescriptor<Podcast>())) ?? 0
            if afterCount > beforeCount {
                succeeded += 1
            } else {
                failed += 1
            }
        }

        lastImportSummary = ImportSummary(
            attempted: urls.count,
            succeeded: succeeded,
            alreadySubscribed: alreadySubscribed,
            failed: failed
        )
    }

    /// Pull-to-refresh on the subscriptions list. Iterates every subscribed
    /// podcast sequentially. Per-podcast errors are swallowed (refresh is
    /// best-effort; the user pulls again to retry). Episodes are merged by
    /// audioURL — existing episodes get metadata updates, new episodes are
    /// inserted, none are deleted, and user state (playbackPosition,
    /// listenedStatus) on existing episodes is preserved.
    func refreshAll() async {
        let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
        let podcasts = (try? modelContext.fetch(descriptor)) ?? []
        for podcast in podcasts {
            await fetchAndMerge(podcast)
        }
    }

    /// Detail-open refresh. No-op if the podcast was fetched within the last
    /// `refreshDebounceSeconds` seconds — prevents in/out navigation from
    /// spamming the network.
    func refresh(_ podcast: Podcast) async {
        if let last = podcast.lastFetchedAt,
           Date().timeIntervalSince(last) < Self.refreshDebounceSeconds {
            return
        }
        await fetchAndMerge(podcast)
    }

    private static let refreshDebounceSeconds: TimeInterval = 60

    private func fetchAndMerge(_ podcast: Podcast) async {
        guard let url = URL(string: podcast.feedURL) else { return }

        let feed: ParsedFeed
        do {
            feed = try await fetcher.fetch(url)
        } catch {
            return
        }

        // `uniquingKeysWith: { first, _ in first }` so a malformed feed or a
        // historical bad-insert with duplicate audioURLs doesn't crash the
        // refresh path. The class doesn't enforce audioURL uniqueness on
        // Episode, so we can't assume it.
        let existingByAudioURL = Dictionary(
            podcast.episodes.map { ($0.audioURL, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for parsed in feed.episodes {
            if let existing = existingByAudioURL[parsed.audioURL] {
                existing.title = parsed.title
                existing.publishDate = parsed.publishDate
                existing.descriptionText = parsed.descriptionText
                existing.durationSeconds = parsed.durationSeconds
                existing.isExplicit = parsed.isExplicit
                // playbackPosition + listenedStatus deliberately untouched.
            } else {
                let episode = Episode(
                    podcast: podcast,
                    title: parsed.title,
                    publishDate: parsed.publishDate,
                    descriptionText: parsed.descriptionText,
                    durationSeconds: parsed.durationSeconds,
                    audioURL: parsed.audioURL
                )
                episode.isExplicit = parsed.isExplicit
                modelContext.insert(episode)
                podcast.episodes.append(episode)
            }
        }
        podcast.lastFetchedAt = .now
        try? modelContext.save()
    }
}

struct ImportSummary: Equatable {
    let attempted: Int
    let succeeded: Int
    let alreadySubscribed: Int
    let failed: Int
}
