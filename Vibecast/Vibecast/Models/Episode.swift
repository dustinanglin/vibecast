import SwiftData
import Foundation

enum ListenedStatus: String, Codable {
    case unplayed
    case inProgress
    case played
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
