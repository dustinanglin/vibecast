import Foundation
import SwiftData
import Observation
import SwiftUI

/// Owns episode audio downloads end-to-end: enqueue, progress, terminal
/// state transitions, retention pruning, and delete-when-played.
///
/// Uses a background-configured URLSession so in-flight downloads keep
/// going when the app is backgrounded or terminated. Task↔episode mapping
/// is `taskDescription = episode.audioURL`, which survives process death —
/// on relaunch the session reconnects by identifier and episodes are
/// re-fetched from the model context by audioURL.
///
/// Live progress is in-memory only (never persisted); terminal states are
/// written to the Episode model so `@Query`-driven rows react.
@Observable
@MainActor
final class DownloadManager: NSObject {

    static let sessionIdentifier = "AnglinVibes.Vibecast.downloads"

    /// Fractional progress per in-flight episode, keyed by persistent ID.
    private(set) var progress: [PersistentIdentifier: Double] = [:]

    /// Stored by AppDelegate when iOS relaunches us for background session
    /// events; called once the session drains its event queue.
    @ObservationIgnored var backgroundCompletionHandler: (() -> Void)?

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private var session: URLSession!

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        reconcileOnLaunch()
    }

    // MARK: - Public API

    func download(_ episode: Episode, manual: Bool) {
        guard episode.downloadState != .downloaded,
              episode.downloadState != .downloading,
              !episode.audioURL.isEmpty,
              let url = URL(string: episode.audioURL) else { return }

        var request = URLRequest(url: url)
        // Wifi-only is read at enqueue time; tasks keep the policy they
        // were enqueued with.
        request.allowsCellularAccess = !DownloadSettings.wifiOnly()

        episode.downloadState = .downloading
        if manual { episode.isManualDownload = true }
        try? modelContext.save()
        progress[episode.persistentModelID] = 0

        let task = session.downloadTask(with: request)
        task.taskDescription = episode.audioURL
        task.resume()
    }

    func cancelDownload(_ episode: Episode) {
        let audioURL = episode.audioURL
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription == audioURL {
                task.cancel()
            }
        }
        episode.downloadState = DownloadState.none
        episode.isManualDownload = false
        progress[episode.persistentModelID] = nil
        try? modelContext.save()
    }

    func deleteDownload(_ episode: Episode) {
        DownloadStore.delete(for: episode.audioURL)
        episode.downloadState = DownloadState.none
        episode.isManualDownload = false
        episode.downloadedAt = nil
        progress[episode.persistentModelID] = nil
        try? modelContext.save()
    }

    func deleteAllDownloads() {
        let downloaded = DownloadState.downloaded.rawValue
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.downloadStateRaw == downloaded }
        )
        let episodes = (try? modelContext.fetch(descriptor)) ?? []
        for episode in episodes {
            episode.downloadState = DownloadState.none
            episode.isManualDownload = false
            episode.downloadedAt = nil
        }
        DownloadStore.deleteAll()
        try? modelContext.save()
    }

    func totalStorageBytes() -> Int64 {
        DownloadStore.totalBytes()
    }

    /// Honors the delete-when-played setting. Call from every code path
    /// that transitions an episode to `.played`.
    func episodeWasPlayed(_ episode: Episode) {
        guard DownloadSettings.deleteWhenPlayed(),
              episode.downloadState == .downloaded else { return }
        deleteDownload(episode)
    }

    /// Auto-download entry point, wired to SubscriptionManager's
    /// new-episode callback. Newest 1 per show; pruning runs when each
    /// download COMPLETES (pruning at enqueue would count the in-flight
    /// episode before it exists on disk).
    func autoDownload(newEpisodes: [Episode]) {
        guard DownloadSettings.autoDownloadEnabled() else { return }
        for episode in DownloadPolicy.autoDownloadCandidates(from: newEpisodes) {
            download(episode, manual: false)
        }
    }

    func pruneAll() {
        let podcasts = (try? modelContext.fetch(FetchDescriptor<Podcast>())) ?? []
        for podcast in podcasts { prune(podcast) }
    }

    // MARK: - Internals

    private func prune(_ podcast: Podcast) {
        let victims = DownloadPolicy.pruneCandidates(
            in: podcast.episodes,
            keepLastN: DownloadSettings.keepLastN()
        )
        for episode in victims { deleteDownload(episode) }
    }

    private func episode(forAudioURL audioURL: String) -> Episode? {
        var descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.audioURL == audioURL }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    fileprivate func finishDownload(audioURL: String, success: Bool) {
        guard let episode = episode(forAudioURL: audioURL) else { return }
        progress[episode.persistentModelID] = nil
        if success {
            episode.downloadState = .downloaded
            episode.downloadedAt = .now
            try? modelContext.save()
            if !episode.isManualDownload, let podcast = episode.podcast {
                prune(podcast)
            }
        } else {
            episode.downloadState = .failed
            try? modelContext.save()
        }
    }

    fileprivate func failDownload(audioURL: String) {
        finishDownload(audioURL: audioURL, success: false)
    }

    fileprivate func updateProgress(audioURL: String, fraction: Double) {
        guard let episode = episode(forAudioURL: audioURL) else { return }
        progress[episode.persistentModelID] = fraction
    }

    /// After relaunch: any episode stuck in `.downloading` with no live
    /// task resolves to `.downloaded` (file arrived while we were dead) or
    /// `.failed` (it didn't).
    private func reconcileOnLaunch() {
        session.getAllTasks { [weak self] tasks in
            let active = Set(tasks.compactMap(\.taskDescription))
            Task { @MainActor [weak self] in
                self?.reconcileStuckDownloads(activeAudioURLs: active)
            }
        }
    }

    private func reconcileStuckDownloads(activeAudioURLs: Set<String>) {
        let downloading = DownloadState.downloading.rawValue
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.downloadStateRaw == downloading }
        )
        let stuck = (try? modelContext.fetch(descriptor)) ?? []
        var changed = false
        for episode in stuck where !activeAudioURLs.contains(episode.audioURL) {
            if DownloadStore.exists(for: episode.audioURL) {
                episode.downloadState = .downloaded
                episode.downloadedAt = episode.downloadedAt ?? .now
            } else {
                episode.downloadState = .failed
            }
            changed = true
        }
        if changed { try? modelContext.save() }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let audioURL = downloadTask.taskDescription else { return }
        // The temp file dies when this method returns — move it NOW, on
        // this thread, before hopping to the main actor.
        let stored = (try? DownloadStore.store(tempFile: location, for: audioURL)) != nil
        Task { @MainActor in
            self.finishDownload(audioURL: audioURL, success: stored)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0,
              let audioURL = downloadTask.taskDescription else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.updateProgress(audioURL: audioURL, fraction: fraction)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Success and cancellation are handled elsewhere; only real
        // failures land here.
        guard let error, (error as NSError).code != NSURLErrorCancelled,
              let audioURL = task.taskDescription else { return }
        Task { @MainActor in
            self.failDownload(audioURL: audioURL)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - Environment

private struct DownloadManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: DownloadManager? = nil
}

extension EnvironmentValues {
    var downloadManager: DownloadManager? {
        get { self[DownloadManagerKey.self] }
        set { self[DownloadManagerKey.self] = newValue }
    }
}
