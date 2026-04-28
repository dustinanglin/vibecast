import Foundation
import SwiftData

struct PodcastRowSnapshot: Identifiable, Hashable {
    let id: PersistentIdentifier
    let artworkURL: String?
    let latestEpisode: EpisodeRowSnapshot?
}

struct EpisodeRowSnapshot: Hashable {
    let id: PersistentIdentifier
    let title: String
    let publishDate: Date
    let descriptionText: String
    let listenedStatus: ListenedStatus
    let isExplicit: Bool
    // Computed values captured at snapshot time — no SwiftData fault possible
    let progressFraction: Double
    let formattedDuration: String
    let formattedRemaining: String
}

extension PodcastRowSnapshot {
    init(_ podcast: Podcast) {
        self.id = podcast.persistentModelID
        self.artworkURL = podcast.artworkURL
        let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
        self.latestEpisode = latest.map(EpisodeRowSnapshot.init)
    }
}

extension EpisodeRowSnapshot {
    init(_ episode: Episode) {
        self.id = episode.persistentModelID
        self.title = episode.title
        self.publishDate = episode.publishDate
        self.descriptionText = episode.descriptionText
        self.listenedStatus = episode.listenedStatus
        self.isExplicit = episode.isExplicit
        self.progressFraction = episode.progressFraction
        self.formattedDuration = episode.formattedDuration
        self.formattedRemaining = episode.formattedRemaining
    }
}
