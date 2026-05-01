import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class PlayerManager: PlaybackController {
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

    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let nowPlaying: NowPlayingService
    @ObservationIgnored private var lastPersistedAt: TimeInterval = 0
    @ObservationIgnored private var wasPlayingBeforeInterruption = false
    @ObservationIgnored private static let saveIntervalSeconds: TimeInterval = 5

    init(engine: AudioEngine, modelContext: ModelContext, nowPlaying: NowPlayingService) {
        self.engine = engine
        self.modelContext = modelContext
        self.nowPlaying = nowPlaying

        engine.onTimeUpdate = { [weak self] t in
            self?.handleTimeUpdate(t)
        }
        engine.onPlaybackEnd = { [weak self] in
            self?.handlePlaybackEnd()
        }

        // Wire system audio events through to manager state. We capture
        // wasPlayingBeforeInterruption on .began so a user who had paused
        // *before* the interruption isn't auto-resumed when it ends.
        engine.onInterruptionBegan = { [weak self] in
            guard let self else { return }
            self.wasPlayingBeforeInterruption = self.isPlaying
            self.isPlaying = false
        }
        engine.onInterruptionEndedShouldResume = { [weak self] in
            guard let self,
                  let episode = self.currentEpisode,
                  !episode.audioURL.isEmpty,
                  self.wasPlayingBeforeInterruption else { return }
            self.engine.play()
            self.isPlaying = true
            self.publishNowPlaying()
        }
        engine.onRouteOldDeviceUnavailable = { [weak self] in
            self?.isPlaying = false
            self?.publishNowPlaying()
        }
    }

    // MARK: - Transport

    func play(_ episode: Episode) {
        // Stop any in-flight audio before switching or restarting.
        engine.pause()

        // Persist position of the previous episode before switching.
        persistCurrentPosition()

        currentEpisode = episode

        guard let url = URL(string: episode.audioURL), !episode.audioURL.isEmpty else {
            // No URL — keep state, do not start the engine.
            elapsed = episode.playbackPosition
            lastPersistedAt = episode.playbackPosition
            isPlaying = false
            return
        }

        // A completed episode replays from the beginning.
        resetIfComplete(episode)

        elapsed = episode.playbackPosition
        lastPersistedAt = episode.playbackPosition

        engine.load(url: url, startAt: episode.playbackPosition)
        engine.play()
        isPlaying = true
        publishNowPlaying()
    }

    func togglePlayPause() {
        guard let episode = currentEpisode, !episode.audioURL.isEmpty else { return }
        if isPlaying {
            engine.pause()
            isPlaying = false
            persistCurrentPosition()
        } else {
            if episode.listenedStatus == .played {
                resetIfComplete(episode)
                elapsed = 0
                lastPersistedAt = 0
                engine.seek(to: 0)
            }
            engine.play()
            isPlaying = true
        }
        publishNowPlaying()
    }

    private func resetIfComplete(_ episode: Episode) {
        guard episode.listenedStatus == .played else { return }
        episode.playbackPosition = 0
        episode.listenedStatus = .inProgress
        try? modelContext.save()
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: elapsed + seconds)
    }

    func skipBack(_ seconds: TimeInterval = 15) {
        seek(to: max(0, elapsed - seconds))
    }

    func seek(to seconds: TimeInterval) {
        let upper = duration > 0 ? duration : seconds
        let clamped = max(0, min(seconds, upper))
        engine.seek(to: clamped)
        elapsed = clamped
        persistCurrentPosition()
        publishNowPlaying()
    }

    // MARK: - Engine callbacks

    private func handleTimeUpdate(_ t: TimeInterval) {
        // Ignore stale callbacks dispatched before pause/switch settled.
        guard isPlaying else { return }

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

        // Rewind transition: played → inProgress when position moves below duration.
        if episode.listenedStatus == .played, duration > 0, t < duration {
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
        let canonicalDuration = duration > 0 ? duration : Double(episode.durationSeconds)
        episode.playbackPosition = canonicalDuration
        elapsed = canonicalDuration
        isPlaying = false
        try? modelContext.save()
        lastPersistedAt = elapsed
        publishNowPlaying()

        // Auto-advance: walk the subscriptions list in sortPosition order and
        // play the latest episode of the next podcast whose latest episode is
        // not already .played. Stop if no such podcast exists.
        advanceToNextPodcast(after: episode)
    }

    /// Where playback should jump after marking the currently-playing
    /// episode as played. Library list expects to flow into the next
    /// podcast; podcast detail expects to flow into the next episode of
    /// the same podcast.
    enum AdvanceBehavior {
        case nextPodcast
        case nextEpisodeInPodcast
    }

    /// Mark an episode as played.
    /// - If it's the currently-loaded episode AND was actively playing:
    ///   pause the engine and auto-advance per `advance`.
    /// - If it's the currently-loaded episode AND was paused: pause/sync,
    ///   then release it (clear `currentEpisode`) so the row drops out of
    ///   the now-playing state and the mini-player dismisses. Don't
    ///   auto-advance — the user's pause was intentional.
    /// - If it's not the currently-loaded episode: persist played state only.
    func markPlayed(_ episode: Episode, advance: AdvanceBehavior = .nextPodcast) {
        let isCurrent = episode.persistentModelID == currentEpisode?.persistentModelID
        let wasCurrentlyPlaying = isCurrent && isPlaying

        let canonicalDuration: Double
        if isCurrent {
            canonicalDuration = duration > 0 ? duration : Double(episode.durationSeconds)
        } else {
            canonicalDuration = Double(episode.durationSeconds)
        }

        episode.listenedStatus = .played
        episode.playbackPosition = canonicalDuration

        if isCurrent {
            engine.pause()
            elapsed = canonicalDuration
            lastPersistedAt = canonicalDuration
            isPlaying = false
            publishNowPlaying()
        }

        try? modelContext.save()

        if wasCurrentlyPlaying {
            switch advance {
            case .nextPodcast:
                advanceToNextPodcast(after: episode)
            case .nextEpisodeInPodcast:
                advanceToNextEpisodeInPodcast(after: episode)
            }
        } else if isCurrent {
            currentEpisode = nil
            elapsed = 0
            lastPersistedAt = 0
            publishNowPlaying()
        }
    }

    /// Walk down the same podcast's publishDate-descending list and play the
    /// next episode that hasn't been played yet. No-op if none remain.
    private func advanceToNextEpisodeInPodcast(after finishedEpisode: Episode) {
        guard let podcast = finishedEpisode.podcast else { return }
        let sorted = podcast.episodes.sorted { $0.publishDate > $1.publishDate }
        guard let idx = sorted.firstIndex(where: {
            $0.persistentModelID == finishedEpisode.persistentModelID
        }) else { return }

        for episode in sorted.dropFirst(idx + 1) {
            if episode.listenedStatus == .played { continue }
            play(episode)
            return
        }
    }

    private func advanceToNextPodcast(after finishedEpisode: Episode) {
        guard let currentPodcast = finishedEpisode.podcast else { return }
        let currentPosition = currentPodcast.sortPosition

        let descriptor = FetchDescriptor<Podcast>(
            predicate: #Predicate { $0.sortPosition > currentPosition },
            sortBy: [SortDescriptor(\.sortPosition)]
        )
        guard let candidates = try? modelContext.fetch(descriptor) else { return }

        for podcast in candidates {
            let latest = podcast.episodes.sorted { $0.publishDate > $1.publishDate }.first
            guard let next = latest else { continue }
            if next.listenedStatus == .played { continue }
            play(next)
            return
        }
    }

    // MARK: - Persistence helper

    /// Flush the current episode's playback position to disk immediately.
    /// Call on scene backgrounding so progress survives abrupt termination.
    func saveCurrentState() {
        persistCurrentPosition()
    }

    private func persistCurrentPosition() {
        guard let episode = currentEpisode else { return }
        episode.playbackPosition = elapsed
        if episode.listenedStatus == .unplayed && elapsed > 0 {
            episode.listenedStatus = .inProgress
        } else if episode.listenedStatus == .played, duration > 0, elapsed < duration {
            episode.listenedStatus = .inProgress
        }
        try? modelContext.save()
        lastPersistedAt = elapsed
    }

    private func publishNowPlaying() {
        guard let episode = currentEpisode else {
            nowPlaying.clear()
            return
        }
        let state = PlaybackState(
            episodeTitle: episode.title,
            podcastTitle: episode.podcast?.title ?? "",
            author: episode.podcast?.author ?? "",
            duration: duration > 0 ? duration : Double(episode.durationSeconds),
            elapsed: elapsed,
            isPlaying: isPlaying,
            artworkURL: episode.podcast?.artworkURL.flatMap(URL.init(string:))
        )
        nowPlaying.update(state: state)
    }
}

import SwiftUI

private struct PlayerManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: PlayerManager? = nil
}

extension EnvironmentValues {
    var playerManager: PlayerManager? {
        get { self[PlayerManagerKey.self] }
        set { self[PlayerManagerKey.self] = newValue }
    }
}
