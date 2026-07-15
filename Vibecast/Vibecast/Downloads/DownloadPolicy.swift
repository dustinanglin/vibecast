import Foundation
import SwiftData

/// Pure selection logic for auto-download and retention. No I/O, no
/// UserDefaults — callers pass everything in, which keeps these fully
/// unit-testable against an in-memory container.
@MainActor
enum DownloadPolicy {

    /// From a batch of newly discovered episodes, the newest per show that
    /// isn't already downloaded or in flight. "Newest 1 per show per
    /// refresh" per the spec.
    static func autoDownloadCandidates(from newEpisodes: [Episode]) -> [Episode] {
        let eligible = newEpisodes.filter {
            $0.downloadState == DownloadState.none || $0.downloadState == .failed
        }
        let byShow = Dictionary(grouping: eligible) { $0.podcast?.persistentModelID }
        return byShow.compactMap { key, episodes in
            guard key != nil else { return nil }   // orphaned episodes: skip
            return episodes.max(by: { $0.publishDate < $1.publishDate })
        }
    }

    /// Downloaded, non-manual episodes beyond the newest `keepLastN`.
    /// `keepLastN == 0` means unlimited (prune nothing).
    static func pruneCandidates(in episodes: [Episode], keepLastN: Int) -> [Episode] {
        guard keepLastN > 0 else { return [] }
        let autoDownloaded = episodes
            .filter { $0.downloadState == .downloaded && !$0.isManualDownload }
            .sorted { $0.publishDate > $1.publishDate }
        guard autoDownloaded.count > keepLastN else { return [] }
        return Array(autoDownloaded.dropFirst(keepLastN))
    }
}
