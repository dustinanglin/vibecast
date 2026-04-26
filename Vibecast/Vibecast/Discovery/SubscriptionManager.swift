import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SubscriptionManager {
    private(set) var inFlightSubscriptions: Set<URL> = []

    @ObservationIgnored private let searcher: PodcastSearchService
    @ObservationIgnored private let fetcher: FeedFetcher
    @ObservationIgnored private let modelContext: ModelContext

    init(searcher: PodcastSearchService, fetcher: FeedFetcher, modelContext: ModelContext) {
        self.searcher = searcher
        self.fetcher = fetcher
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

        inFlightSubscriptions.insert(result.feedURL)
        defer { inFlightSubscriptions.remove(result.feedURL) }

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
        try? modelContext.save()

        do {
            let feed = try await fetcher.fetch(result.feedURL)
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
        } catch {
            // Leave podcast row in place with no episodes; user can pull-to-refresh in Plan 4.
        }
    }

    private func nextAvailableSortPosition() -> Int {
        let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition, order: .reverse)])
        let last = (try? modelContext.fetch(descriptor))?.first
        return (last?.sortPosition ?? -1) + 1
    }
}
