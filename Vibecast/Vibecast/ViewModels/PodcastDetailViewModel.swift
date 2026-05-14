import Foundation
import Observation

@Observable
final class PodcastDetailViewModel {
    @ObservationIgnored private let podcast: Podcast
    @ObservationIgnored private let pageSize = 10
    /// The fully-sorted episode list under the current `sortOrder`. For
    /// `.oldest` mode this is already capped at `oldestFirstCap` and
    /// reversed; for `.newest` it's the full catalog newest-first.
    @ObservationIgnored private var allEpisodes: [Episode] = []

    private(set) var displayedEpisodes: [Episode] = []
    private(set) var isLoadingMore = false
    /// Mirrors the persisted `podcast.sortOrder` so the view can bind to
    /// it via a SwiftUI Picker without touching the SwiftData model
    /// directly. Setting this re-sorts the catalog and writes the new
    /// preference back to the podcast.
    private(set) var sortOrder: EpisodeSortOrder

    var hasMore: Bool { displayedEpisodes.count < allEpisodes.count }
    var podcastTitle: String { podcast.title }
    var podcastAuthor: String { podcast.author }
    var podcastArtworkURL: String? { podcast.artworkURL }

    init(podcast: Podcast) {
        self.podcast = podcast
        self.sortOrder = podcast.sortOrder
        loadInitial()
    }

    func loadNextPage() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        let start = displayedEpisodes.count
        let end = min(start + pageSize, allEpisodes.count)
        displayedEpisodes.append(contentsOf: allEpisodes[start..<end])
        isLoadingMore = false
    }

    /// Re-run the initial fetch logic. Called from the view's `.task` after
    /// SubscriptionManager.refresh inserts new Episode rows so the cached
    /// displayedEpisodes picks them up.
    func refetch() {
        loadInitial()
    }

    /// Switch sort mode. Persists onto the Podcast model, then re-sorts
    /// from scratch so pagination starts at the top of the new ordering.
    func setSortOrder(_ newValue: EpisodeSortOrder) {
        guard newValue != sortOrder else { return }
        sortOrder = newValue
        podcast.sortOrder = newValue
        loadInitial()
    }

    private func loadInitial() {
        let newestFirst = podcast.episodes.sorted { $0.publishDate > $1.publishDate }
        switch sortOrder {
        case .newest:
            allEpisodes = newestFirst
        case .oldest:
            // Cap at the most recent N, then flip to chronological order so
            // the user sees the earliest of that window first. Showing the
            // full reversed catalog would bury the actually-listenable
            // recent episodes under decades of archive.
            allEpisodes = newestFirst.prefix(EpisodeSortOrder.oldestFirstCap).reversed()
        }
        displayedEpisodes = []
        isLoadingMore = false
        loadNextPage()
    }
}
