#if DEBUG
import SwiftData
import Foundation

/// Simulator conveniences for checking layouts without tapping through the
/// app. Debug builds only; none of this ships.
///
/// - `-debugSeedSampleData YES` fills an empty library with sample shows.
/// - `-debugLoadFirstEpisode YES` loads the first show's latest episode so
///   the mini-player and Now Playing have content.
@MainActor
enum DebugLaunch {
    static func apply(context: ModelContext, player: PlayerManager) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "debugSeedSampleData") {
            let count = (try? context.fetchCount(FetchDescriptor<Podcast>())) ?? 0
            if count == 0 {
                SampleData.insertSampleData(into: context)
                try? context.save()
            }
        }
        if defaults.bool(forKey: "debugLoadFirstEpisode") {
            let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
            let first = (try? context.fetch(descriptor))?.first
            if let episode = first?.episodes.max(by: { $0.publishDate < $1.publishDate }) {
                player.play(episode)
                player.togglePlayPause()
            }
        }
    }
}
#endif
