import Foundation
import SwiftData

/// Pure resolver: turn a Vibe's memberships into a playable queue of
/// (Podcast, latest-unplayed Episode) pairs in per-vibe `position` order.
/// "Latest unplayed" is the most-recently-published episode whose status is
/// not `.played` and whose playbackPosition is below the 0.95-of-duration
/// completion threshold.
enum VibeQueueResolver {
    /// Completion threshold matching PlayerManager's resetIfComplete semantics.
    static let completionThreshold: Double = 0.95

    static func resolve(vibe: Vibe, from start: Podcast? = nil) -> [(podcast: Podcast, episode: Episode)] {
        let ordered = vibe.memberships
            .sorted(by: { $0.position < $1.position })
            .compactMap { $0.podcast }

        // If `from` is given AND present, drop everything before it. If
        // `from` is given but not in the vibe, ignore the slice request.
        let sliced: [Podcast]
        if let start, let idx = ordered.firstIndex(where: { $0.persistentModelID == start.persistentModelID }) {
            sliced = Array(ordered[idx...])
        } else {
            sliced = ordered
        }

        return sliced.compactMap { podcast in
            guard let episode = latestUnplayedEpisode(in: podcast) else { return nil }
            return (podcast, episode)
        }
    }

    static func latestUnplayedEpisode(in podcast: Podcast) -> Episode? {
        podcast.episodes
            .sorted(by: { $0.publishDate > $1.publishDate })
            .first(where: { isUnplayed($0) })
    }

    private static func isUnplayed(_ episode: Episode) -> Bool {
        if episode.listenedStatus == .played { return false }
        let duration = Double(episode.durationSeconds)
        guard duration > 0 else { return episode.listenedStatus != .played }
        return episode.playbackPosition < duration * completionThreshold
    }
}
