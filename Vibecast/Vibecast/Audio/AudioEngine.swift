import Foundation
import AVFoundation

@MainActor
protocol AudioEngine: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var volume: Float { get set }

    /// Invoked on the main actor at most a few times per second while playing.
    var onTimeUpdate: ((TimeInterval) -> Void)? { get set }

    /// Invoked on the main actor when the loaded item reaches its end.
    var onPlaybackEnd: (() -> Void)? { get set }

    func load(url: URL, startAt: TimeInterval)
    func play()
    func pause()
    func seek(to: TimeInterval)
}

@MainActor
final class AVPlayerAudioEngine: AudioEngine {
    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var loadedURL: URL?
    private var awaitingInitialSeek = false

    var isPlaying: Bool { player.timeControlStatus == .playing }

    var currentTime: TimeInterval {
        let t = player.currentTime()
        return t.isValid && !t.isIndefinite ? CMTimeGetSeconds(t) : 0
    }

    var duration: TimeInterval {
        guard let item = player.currentItem else { return 0 }
        let d = item.duration
        return d.isValid && !d.isIndefinite ? CMTimeGetSeconds(d) : 0
    }

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnd: (() -> Void)?

    init() {
        configureAudioSession()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        statusObservation?.invalidate()
    }

    func load(url: URL, startAt: TimeInterval) {
        // Fast path: the requested URL is already loaded. Seek in place so we
        // don't trigger a replaceCurrentItem → re-fetch → KVO-deferred-seek
        // race. This is the common resume-same-episode case.
        if loadedURL == url,
           let currentItem = player.currentItem,
           currentItem.status == .readyToPlay {
            let target = CMTime(seconds: max(0, startAt), preferredTimescale: 600)
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            return
        }

        loadedURL = url
        awaitingInitialSeek = false

        // Tear down observers from any previous item.
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        if startAt > 0 {
            let target = CMTime(seconds: startAt, preferredTimescale: 600)
            awaitingInitialSeek = true
            // AVPlayer drops seek requests until the item reaches
            // .readyToPlay, so wait for that status transition before seeking.
            statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                switch item.status {
                case .readyToPlay:
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.player.seek(to: target, toleranceBefore: .positiveInfinity, toleranceAfter: .zero)
                        self.awaitingInitialSeek = false
                        self.statusObservation?.invalidate()
                        self.statusObservation = nil
                    }
                case .failed:
                    Task { @MainActor [weak self] in
                        self?.awaitingInitialSeek = false
                        self?.statusObservation?.invalidate()
                        self?.statusObservation = nil
                    }
                default:
                    break
                }
            }
        }

        // Periodic time observer: ~4 callbacks per second.
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                // Closure runs on main queue, hop to MainActor explicitly.
                Task { @MainActor [weak self] in
                    guard let self, !self.awaitingInitialSeek else { return }
                    self.onTimeUpdate?(seconds)
                }
            }
        }

        // End-of-item notification.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onPlaybackEnd?()
            }
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: TimeInterval) {
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Playback will still work for the simulator/foreground; log and continue.
            print("AVAudioSession config failed: \(error)")
        }
    }
}
