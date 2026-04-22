import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class PlayerManager {
    private(set) var currentEpisode: Episode?
    private(set) var isPlaying: Bool = false
    private(set) var elapsed: TimeInterval = 0

    /// Preferred duration: the engine's if loaded, otherwise the episode's stored duration.
    var duration: TimeInterval {
        let engineDuration = engine.duration
        if engineDuration > 0 { return engineDuration }
        if let seconds = currentEpisode?.durationSeconds { return TimeInterval(seconds) }
        return 0
    }

    var volume: Float {
        get { engine.volume }
        set { engine.volume = newValue }
    }

    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private var lastPersistedAt: TimeInterval = 0
    @ObservationIgnored private static let saveIntervalSeconds: TimeInterval = 5

    init(engine: AudioEngine, modelContext: ModelContext) {
        self.engine = engine
        self.modelContext = modelContext

        engine.onTimeUpdate = { [weak self] t in
            self?.handleTimeUpdate(t)
        }
        engine.onPlaybackEnd = { [weak self] in
            self?.handlePlaybackEnd()
        }
    }

    // MARK: - Transport

    func play(_ episode: Episode) {
        // Persist position of the previous episode before switching.
        persistCurrentPosition()

        currentEpisode = episode
        elapsed = episode.playbackPosition
        lastPersistedAt = episode.playbackPosition

        guard let url = URL(string: episode.audioURL), !episode.audioURL.isEmpty else {
            // No URL — keep state, do not start the engine.
            isPlaying = false
            return
        }

        engine.load(url: url, startAt: episode.playbackPosition)
        engine.play()
        isPlaying = true
    }

    func togglePlayPause() {
        guard currentEpisode != nil else { return }
        if isPlaying {
            engine.pause()
            isPlaying = false
            persistCurrentPosition()
        } else {
            engine.play()
            isPlaying = true
        }
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: elapsed + seconds)
    }

    func skipBack(_ seconds: TimeInterval = 15) {
        seek(to: max(0, elapsed - seconds))
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(0, seconds)
        engine.seek(to: clamped)
        elapsed = clamped
        persistCurrentPosition()
    }

    // MARK: - Engine callbacks

    private func handleTimeUpdate(_ t: TimeInterval) {
        elapsed = t
        guard let episode = currentEpisode else { return }

        // First-touch transition: unplayed → inProgress.
        if episode.listenedStatus == .unplayed, t > 0 {
            episode.listenedStatus = .inProgress
            episode.playbackPosition = t
            try? modelContext.save()
            lastPersistedAt = t
            return
        }

        // Throttled periodic save.
        if t - lastPersistedAt >= Self.saveIntervalSeconds {
            episode.playbackPosition = t
            try? modelContext.save()
            lastPersistedAt = t
        }
    }

    private func handlePlaybackEnd() {
        guard let episode = currentEpisode else { return }
        episode.listenedStatus = .played
        episode.playbackPosition = Double(episode.durationSeconds)
        elapsed = Double(episode.durationSeconds)
        isPlaying = false
        try? modelContext.save()
        lastPersistedAt = elapsed
    }

    // MARK: - Persistence helper

    private func persistCurrentPosition() {
        guard let episode = currentEpisode else { return }
        episode.playbackPosition = elapsed
        if episode.listenedStatus == .unplayed && elapsed > 0 {
            episode.listenedStatus = .inProgress
        }
        try? modelContext.save()
        lastPersistedAt = elapsed
    }
}
