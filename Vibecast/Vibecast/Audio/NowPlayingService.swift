import Foundation
import MediaPlayer
import UIKit

/// Snapshot of the current playback state, passed to `NowPlayingService.update`.
struct PlaybackState {
    let episodeTitle: String
    let podcastTitle: String
    let author: String
    let duration: TimeInterval
    let elapsed: TimeInterval
    let isPlaying: Bool
    let artworkURL: URL?
}

@Observable
@MainActor
final class NowPlayingService {
    /// Routes lock-screen / Control Center / AirPods commands back to
    /// the player. Set during app wiring.
    weak var controller: (any PlaybackController)?

    /// Cache of resolved artwork keyed by URL string.
    @ObservationIgnored private var artworkCache: [String: UIImage] = [:]
    @ObservationIgnored private var lastArtworkURL: URL?

    @ObservationIgnored private let infoCenter = MPNowPlayingInfoCenter.default()

    init() {
        configureRemoteCommands()
    }

    // MARK: - Public API

    /// Push current playback state to the system. Call on play, pause,
    /// seek, episode-change. The system extrapolates `elapsed` from
    /// `playbackRate` so per-tick updates are not needed.
    func update(state: PlaybackState) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = state.episodeTitle
        info[MPMediaItemPropertyAlbumTitle] = state.podcastTitle
        info[MPMediaItemPropertyArtist] = state.author
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.isPlaying ? 1.0 : 0.0

        if let cached = state.artworkURL.flatMap({ artworkCache[$0.absoluteString] }) {
            info[MPMediaItemPropertyArtwork] = makeArtwork(image: cached)
        }

        infoCenter.nowPlayingInfo = info

        // Async-load artwork if not cached and write back when ready.
        if let url = state.artworkURL,
           artworkCache[url.absoluteString] == nil,
           lastArtworkURL != url {
            lastArtworkURL = url
            Task { [weak self] in
                guard let image = await Self.loadImage(from: url) else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.artworkCache[url.absoluteString] = image
                    var current = self.infoCenter.nowPlayingInfo ?? [:]
                    current[MPMediaItemPropertyArtwork] = self.makeArtwork(image: image)
                    self.infoCenter.nowPlayingInfo = current
                }
            }
        }
    }

    /// Clear all Now Playing info (e.g., when no episode is loaded).
    func clear() {
        infoCenter.nowPlayingInfo = nil
        lastArtworkURL = nil
    }

    // MARK: - Private

    private func makeArtwork(image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private static func loadImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // MPRemoteCommandCenter is a process singleton; addTarget appends.
        // Clear any prior targets first so re-instantiating the service
        // (especially in tests) doesn't stack stale closures.
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.controller?.togglePlayPause()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.controller?.togglePlayPause()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.controller?.togglePlayPause()
            }
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 30
            Task { @MainActor [weak self] in
                self?.controller?.skipForward(interval)
            }
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor [weak self] in
                self?.controller?.skipBack(interval)
            }
            return .success
        }

        // Scrubber needs the seek to land before .success returns, otherwise
        // the lock-screen scrubber visibly snaps back to the old elapsed for
        // a frame. addTarget closures are dispatched on the main thread at
        // runtime, so MainActor.assumeIsolated is safe and synchronous.
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let pos = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                return .commandFailed
            }
            MainActor.assumeIsolated {
                self?.controller?.seek(to: pos)
            }
            return .success
        }

        // Multi-episode queue is Plan 7 territory.
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }
}
