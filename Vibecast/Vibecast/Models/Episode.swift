import SwiftData
import Foundation

enum ListenedStatus: String, Codable {
    case unplayed
    case inProgress
    case played
}

/// Offline-download lifecycle for an episode's audio file. Stored on
/// Episode as a raw string with a default so SwiftData lightweight
/// migration adds it to existing rows (same pattern as
/// `Podcast.episodeSortOrderRaw`).
enum DownloadState: String, Codable, Sendable {
    case none
    case downloading
    case downloaded
    case failed
}

@Model
final class Episode {
    var podcast: Podcast?
    var title: String
    var publishDate: Date
    var descriptionText: String
    var durationSeconds: Int
    var audioURL: String
    var listenedStatus: ListenedStatus
    var playbackPosition: Double
    var isExplicit: Bool
    var downloadStateRaw: String = DownloadState.none.rawValue
    var isManualDownload: Bool = false
    var downloadedAt: Date?

    init(podcast: Podcast, title: String, publishDate: Date, descriptionText: String, durationSeconds: Int, audioURL: String, isExplicit: Bool = false) {
        self.podcast = podcast
        self.title = title
        self.publishDate = publishDate
        self.descriptionText = descriptionText
        self.durationSeconds = durationSeconds
        self.audioURL = audioURL
        self.isExplicit = isExplicit
        self.listenedStatus = .unplayed
        self.playbackPosition = 0
    }

    var downloadState: DownloadState {
        get { DownloadState(rawValue: downloadStateRaw) ?? .none }
        set { downloadStateRaw = newValue.rawValue }
    }

    var progressFraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(playbackPosition / Double(durationSeconds), 1.0)
    }

    var remainingSeconds: Int {
        max(0, durationSeconds - Int(playbackPosition))
    }

    var formattedDuration: String {
        Self.format(seconds: durationSeconds)
    }

    var formattedRemaining: String {
        Self.format(seconds: remainingSeconds)
    }

    /// Elapsed playback time formatted like formattedDuration (e.g., "14m", "1h 2m").
    var formattedElapsed: String {
        Self.format(seconds: Int(playbackPosition))
    }

    private static func format(seconds total: Int) -> String {
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
