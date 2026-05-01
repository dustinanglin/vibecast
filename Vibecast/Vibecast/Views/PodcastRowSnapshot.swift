import Foundation
import SwiftData

struct PodcastRowSnapshot: Identifiable, Hashable {
    let id: PersistentIdentifier
    let title: String
    let artworkURL: String?
    let latestEpisode: EpisodeRowSnapshot?
    /// 1-indexed position for human-readable display in the left slot.
    let position: Int
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
    /// Raw playback position in seconds, captured at snapshot time.
    let playbackPosition: TimeInterval
    /// Raw total duration in seconds, captured at snapshot time.
    let totalDuration: TimeInterval

    /// Elapsed time formatted like formattedDuration (e.g., "14m", "1h 2m").
    var formattedElapsed: String {
        let total = Int(playbackPosition)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

extension PodcastRowSnapshot {
    init(_ podcast: Podcast) {
        self.id = podcast.persistentModelID
        self.title = podcast.title
        self.artworkURL = podcast.artworkURL
        self.position = podcast.sortPosition + 1
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
        self.playbackPosition = episode.playbackPosition
        self.totalDuration = TimeInterval(episode.durationSeconds)
    }
}
