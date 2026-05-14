import SwiftData
import Foundation

@Model
final class Podcast {
    var title: String
    var author: String
    var artworkURL: String?
    var feedURL: String
    var sortPosition: Int
    var lastFetchedAt: Date?
    var iTunesCollectionId: Int?
    /// Raw value of `EpisodeSortOrder`. Stored as a String so SwiftData's
    /// lightweight migration can add it with a default for existing rows
    /// without a schema bump. Read/write the typed `sortOrder` instead of
    /// touching this directly.
    var episodeSortOrderRaw: String = EpisodeSortOrder.newest.rawValue
    @Relationship(deleteRule: .cascade) var episodes: [Episode]
    @Relationship(deleteRule: .cascade, inverse: \VibeMembership.podcast)
    var vibeMemberships: [VibeMembership] = []

    init(
        title: String,
        author: String,
        artworkURL: String?,
        feedURL: String,
        sortPosition: Int = 0,
        lastFetchedAt: Date? = nil,
        iTunesCollectionId: Int? = nil
    ) {
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.feedURL = feedURL
        self.sortPosition = sortPosition
        self.lastFetchedAt = lastFetchedAt
        self.iTunesCollectionId = iTunesCollectionId
        self.episodes = []
    }

    /// Per-podcast persistent sort preference for the detail view's episode
    /// list. Falls back to `.newest` if the stored raw value ever drifts.
    var sortOrder: EpisodeSortOrder {
        get { EpisodeSortOrder(rawValue: episodeSortOrderRaw) ?? .newest }
        set { episodeSortOrderRaw = newValue.rawValue }
    }
}

/// Episode list sort mode for `PodcastDetailView`. `.newest` shows the full
/// catalog newest-first (paginated). `.oldest` flips the recent N episodes
/// into oldest-first order — for serialized podcasts (sermons, multi-part
/// series) where listeners want to hear part 1 before part 2.
enum EpisodeSortOrder: String, CaseIterable {
    case newest
    case oldest

    /// Cap for `.oldest` mode. The user sees the oldest of the most recent
    /// `cap` episodes first — protects against a 500-episode backlog when
    /// the user really just wants "the last few weeks in chronological
    /// order."
    static let oldestFirstCap = 25
}
