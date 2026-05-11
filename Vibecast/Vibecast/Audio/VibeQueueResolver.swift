import Foundation
import SwiftData

/// Pure resolver: turn a Vibe's memberships into a playable queue of
/// (Podcast, Episode) pairs in per-vibe `position` order.
///
/// **Semantics.** For each podcast we look at *only* the most-recently
/// published episode. If that latest episode is unplayed (and below the
/// 0.95-of-duration completion threshold), we include the pair. If the
/// latest is played, we skip the podcast entirely — even if it has older
/// unplayed episodes. This matches the vibe-listening model: each show
/// contributes its newest episode to the queue or nothing. Older episodes
/// remain in the library and can be played individually from the row.
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
            guard let episode = latestEpisodeIfUnplayed(in: podcast) else { return nil }
            return (podcast, episode)
        }
    }

    /// Returns the most-recently-published episode for `podcast` only if
    /// that episode is still unplayed. Returns `nil` (skipping the show)
    /// when the latest is `.played` or has crossed the 95% threshold,
    /// regardless of whether older episodes remain unplayed.
    static func latestEpisodeIfUnplayed(in podcast: Podcast) -> Episode? {
        guard let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first else {
            return nil
        }
        return isUnplayed(latest) ? latest : nil
    }

    private static func isUnplayed(_ episode: Episode) -> Bool {
        if episode.listenedStatus == .played { return false }
        let duration = Double(episode.durationSeconds)
        guard duration > 0 else { return episode.listenedStatus != .played }
        return episode.playbackPosition < duration * completionThreshold
    }
}
