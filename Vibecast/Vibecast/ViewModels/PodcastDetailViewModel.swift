import Observation

@Observable
final class PodcastDetailViewModel {
    @ObservationIgnored private let podcast: Podcast
    @ObservationIgnored private let pageSize = 10
    @ObservationIgnored private lazy var allEpisodes: [Episode] = {
        podcast.episodes.sorted { $0.publishDate > $1.publishDate }
    }()

    private(set) var displayedEpisodes: [Episode] = []
    private(set) var isLoadingMore = false

    var hasMore: Bool { displayedEpisodes.count < allEpisodes.count }
    var podcastTitle: String { podcast.title }
    var podcastAuthor: String { podcast.author }
    var podcastArtworkURL: String? { podcast.artworkURL }

    init(podcast: Podcast) {
        self.podcast = podcast
        loadNextPage()
    }

    func loadNextPage() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        let start = displayedEpisodes.count
        let end = min(start + pageSize, allEpisodes.count)
        displayedEpisodes.append(contentsOf: allEpisodes[start..<end])
        isLoadingMore = false
    }
}
