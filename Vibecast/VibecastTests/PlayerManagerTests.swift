import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class PlayerManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var engine: MockAudioEngine!
    var manager: PlayerManager!
    var podcast: Podcast!
    var episode: Episode!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)

        podcast = Podcast(title: "T", author: "A", artworkURL: nil, feedURL: "https://example.com/f")
        episode = Episode(
            podcast: podcast,
            title: "Ep",
            publishDate: .now,
            descriptionText: "",
            durationSeconds: 100,
            audioURL: "https://example.com/a.mp3"
        )
        context.insert(podcast)
        context.insert(episode)
        podcast.episodes.append(episode)
        try context.save()

        engine = MockAudioEngine()
        manager = PlayerManager(engine: engine, modelContext: context)
    }

    func test_play_setsCurrentEpisodeAndStartsEngine() {
        manager.play(episode)
        XCTAssertEqual(manager.currentEpisode?.persistentModelID, episode.persistentModelID)
        XCTAssertTrue(manager.isPlaying)
        XCTAssertTrue(engine.playCalled)
        XCTAssertEqual(engine.loadedURL?.absoluteString, "https://example.com/a.mp3")
    }

    func test_play_resumesFromSavedPosition() {
        episode.playbackPosition = 42
        manager.play(episode)
        XCTAssertEqual(engine.loadedStart, 42, accuracy: 0.001)
    }

    func test_play_withEmptyURL_setsStateWithoutStartingEngine() {
        episode.audioURL = ""
        manager.play(episode)
        XCTAssertEqual(manager.currentEpisode?.persistentModelID, episode.persistentModelID)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertFalse(engine.playCalled)
    }

    func test_timeUpdate_flipsUnplayedToInProgress() {
        XCTAssertEqual(episode.listenedStatus, .unplayed)
        manager.play(episode)
        engine.simulateTimeUpdate(1.0)
        XCTAssertEqual(episode.listenedStatus, .inProgress)
        XCTAssertEqual(episode.playbackPosition, 1.0, accuracy: 0.001)
    }

    func test_playbackEnd_flipsStatusToPlayed_andPersistsFullDuration() {
        manager.play(episode)
        engine.simulatePlaybackEnd()
        XCTAssertEqual(episode.listenedStatus, .played)
        XCTAssertEqual(episode.playbackPosition, Double(episode.durationSeconds), accuracy: 0.001)
        XCTAssertFalse(manager.isPlaying)
    }

    func test_togglePlayPause_pausesAndPersists() {
        manager.play(episode)
        engine.simulateTimeUpdate(10)
        manager.togglePlayPause()
        XCTAssertTrue(engine.pauseCalled)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(episode.playbackPosition, 10, accuracy: 0.001)
    }

    func test_togglePlayPause_resumes() {
        manager.play(episode)
        manager.togglePlayPause() // pause
        engine.playCalled = false
        manager.togglePlayPause() // resume
        XCTAssertTrue(manager.isPlaying)
        XCTAssertTrue(engine.playCalled)
    }

    func test_skipForward_advancesByThirty() {
        manager.play(episode)
        engine.simulateTimeUpdate(10)
        manager.skipForward()
        XCTAssertEqual(engine.seekedTo ?? -1, 40, accuracy: 0.001)
    }

    func test_skipBack_rewindsByFifteen_clampedAtZero() {
        manager.play(episode)
        engine.simulateTimeUpdate(10)
        manager.skipBack()
        XCTAssertEqual(engine.seekedTo ?? -1, 0, accuracy: 0.001)
    }

    func test_seek_updatesElapsedAndPersists() {
        manager.play(episode)
        manager.seek(to: 55)
        XCTAssertEqual(engine.seekedTo ?? -1, 55, accuracy: 0.001)
        XCTAssertEqual(manager.elapsed, 55, accuracy: 0.001)
        XCTAssertEqual(episode.playbackPosition, 55, accuracy: 0.001)
    }

    func test_seek_clampsAgainstDuration() {
        manager.play(episode)
        manager.seek(to: 9999)
        XCTAssertEqual(engine.seekedTo ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(manager.elapsed, 100, accuracy: 0.001)
    }

    func test_skipForward_pastEnd_clampsAtDuration() {
        manager.play(episode)
        engine.simulateTimeUpdate(90)
        manager.skipForward()
        XCTAssertEqual(engine.seekedTo ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(manager.elapsed, 100, accuracy: 0.001)
    }

    func test_seek_backFromPlayed_flipsToInProgress() {
        manager.play(episode)
        engine.simulatePlaybackEnd()
        XCTAssertEqual(episode.listenedStatus, .played)

        manager.seek(to: 30)
        XCTAssertEqual(episode.listenedStatus, .inProgress)
        XCTAssertEqual(episode.playbackPosition, 30, accuracy: 0.001)
    }

    func test_seek_toEnd_keepsPlayedStatus() {
        manager.play(episode)
        engine.simulatePlaybackEnd()
        XCTAssertEqual(episode.listenedStatus, .played)

        manager.seek(to: 100)
        XCTAssertEqual(episode.listenedStatus, .played)
    }

    func test_play_replaysEndedEpisodeFromStart() {
        manager.play(episode)
        engine.simulatePlaybackEnd()
        XCTAssertEqual(episode.listenedStatus, .played)
        XCTAssertEqual(episode.playbackPosition, 100, accuracy: 0.001)

        manager.play(episode)
        XCTAssertEqual(episode.listenedStatus, .inProgress)
        XCTAssertEqual(episode.playbackPosition, 0, accuracy: 0.001)
        XCTAssertEqual(manager.elapsed, 0, accuracy: 0.001)
        XCTAssertEqual(engine.loadedStart, 0, accuracy: 0.001)
        XCTAssertTrue(manager.isPlaying)
    }

    func test_togglePlayPause_atEnd_restartsFromZero() {
        manager.play(episode)
        engine.simulatePlaybackEnd()
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(episode.listenedStatus, .played)

        manager.togglePlayPause()
        XCTAssertTrue(manager.isPlaying)
        XCTAssertEqual(episode.listenedStatus, .inProgress)
        XCTAssertEqual(manager.elapsed, 0, accuracy: 0.001)
        XCTAssertEqual(engine.seekedTo ?? -1, 0, accuracy: 0.001)
    }

    func test_play_switchingEpisodes_pausesEngineAndPersistsPreviousPosition() {
        manager.play(episode)
        engine.simulateTimeUpdate(30)
        engine.pauseCalled = false

        let other = Episode(
            podcast: podcast,
            title: "Other",
            publishDate: .now,
            descriptionText: "",
            durationSeconds: 60,
            audioURL: "https://example.com/b.mp3"
        )
        context.insert(other)

        manager.play(other)
        XCTAssertTrue(engine.pauseCalled)
        XCTAssertEqual(episode.playbackPosition, 30, accuracy: 0.001)
        XCTAssertEqual(manager.currentEpisode?.persistentModelID, other.persistentModelID)
        XCTAssertTrue(manager.isPlaying)
    }

    func test_play_switchingToEmptyURLEpisode_pausesEngineWithoutPlaying() {
        manager.play(episode)
        engine.simulateTimeUpdate(30)
        engine.pauseCalled = false
        engine.playCalled = false

        let silent = Episode(
            podcast: podcast,
            title: "NoURL",
            publishDate: .now,
            descriptionText: "",
            durationSeconds: 60,
            audioURL: ""
        )
        context.insert(silent)

        manager.play(silent)
        XCTAssertTrue(engine.pauseCalled)
        XCTAssertFalse(engine.playCalled)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(episode.playbackPosition, 30, accuracy: 0.001)
    }

    func test_togglePlayPause_ignoresEmptyURLEpisode() {
        episode.audioURL = ""
        manager.play(episode)
        XCTAssertFalse(manager.isPlaying)
        engine.playCalled = false

        manager.togglePlayPause()
        XCTAssertFalse(engine.playCalled)
        XCTAssertFalse(manager.isPlaying)
    }

    func test_handleTimeUpdate_ignoredWhenNotPlaying() {
        manager.play(episode)
        engine.simulateTimeUpdate(20)
        XCTAssertEqual(manager.elapsed, 20, accuracy: 0.001)

        manager.togglePlayPause() // pause
        XCTAssertFalse(manager.isPlaying)

        // A stale callback dispatched before pause fully settled must not
        // overwrite the displayed elapsed.
        engine.simulateTimeUpdate(99)
        XCTAssertEqual(manager.elapsed, 20, accuracy: 0.001)
    }

    func test_saveCurrentState_flushesElapsedBetweenThrottledSaves() {
        manager.play(episode)
        engine.simulateTimeUpdate(1)  // first-touch: .unplayed → .inProgress, saves playbackPosition=1
        XCTAssertEqual(episode.playbackPosition, 1, accuracy: 0.001)

        engine.simulateTimeUpdate(3)  // below 5s throttle; no save
        XCTAssertEqual(episode.playbackPosition, 1, accuracy: 0.001)

        manager.saveCurrentState()
        XCTAssertEqual(episode.playbackPosition, 3, accuracy: 0.001)
    }

    func test_play_switchingToEmptyURLEpisode_ignoresStaleTimeUpdate() {
        manager.play(episode)
        engine.simulateTimeUpdate(11)

        let silent = Episode(
            podcast: podcast,
            title: "NoURL",
            publishDate: .now,
            descriptionText: "",
            durationSeconds: 1800,
            audioURL: ""
        )
        silent.playbackPosition = 1260
        context.insert(silent)

        manager.play(silent)
        XCTAssertEqual(manager.elapsed, 1260, accuracy: 0.001)

        // Stale tick from the engine's last pre-pause callback arrives:
        engine.simulateTimeUpdate(11)
        XCTAssertEqual(manager.elapsed, 1260, accuracy: 0.001)
    }

    func test_throttledSave_persistsEveryFiveSeconds() throws {
        manager.play(episode)
        engine.simulateTimeUpdate(1) // flips to inProgress, saves
        episode.playbackPosition = 0 // reset to verify subsequent saves
        engine.simulateTimeUpdate(2) // below 5s delta — no save
        XCTAssertEqual(episode.playbackPosition, 0, accuracy: 0.001)
        engine.simulateTimeUpdate(7) // above 5s delta since last save — saves
        XCTAssertEqual(episode.playbackPosition, 7, accuracy: 0.001)
    }

    func test_handlePlaybackEnd_usesEngineDuration_whenAvailable() throws {
        // Episode duration from feed: 1234 seconds (Int rounded).
        // Engine reports actual duration of 1234.5 seconds.
        episode.durationSeconds = 1234
        engine.duration = 1234.5
        try context.save()

        manager.play(episode)
        engine.simulatePlaybackEnd()

        XCTAssertEqual(episode.playbackPosition, 1234.5, accuracy: 0.001)
        XCTAssertEqual(manager.elapsed, 1234.5, accuracy: 0.001)
        XCTAssertEqual(episode.listenedStatus, .played)
    }

    func test_handlePlaybackEnd_fallsBackToFeedDuration_whenEngineDurationZero() throws {
        episode.durationSeconds = 1234
        engine.duration = 0   // engine never resolved actual duration
        try context.save()

        manager.play(episode)
        engine.simulatePlaybackEnd()

        XCTAssertEqual(episode.playbackPosition, 1234.0, accuracy: 0.001)
        XCTAssertEqual(manager.elapsed, 1234.0, accuracy: 0.001)
        XCTAssertEqual(episode.listenedStatus, .played)
    }
}

// MARK: - Test Double

@MainActor
final class MockAudioEngine: AudioEngine {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0

    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnd: (() -> Void)?

    // Captured for assertions
    var loadedURL: URL?
    var loadedStart: TimeInterval = 0
    var playCalled = false
    var pauseCalled = false
    var seekedTo: TimeInterval?

    func load(url: URL, startAt: TimeInterval) {
        loadedURL = url
        loadedStart = startAt
        currentTime = startAt
    }

    func play() {
        playCalled = true
        isPlaying = true
    }

    func pause() {
        pauseCalled = true
        isPlaying = false
    }

    func seek(to seconds: TimeInterval) {
        seekedTo = seconds
        currentTime = seconds
    }

    // Test helpers
    func simulateTimeUpdate(_ t: TimeInterval) {
        currentTime = t
        onTimeUpdate?(t)
    }

    func simulatePlaybackEnd() {
        onPlaybackEnd?()
    }
}
