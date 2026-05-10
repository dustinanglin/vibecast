import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class PlayerManagerVibeTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var engine: MockAudioEngine!
    var manager: PlayerManager!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, QueueState.self, configurations: config)
        context = ModelContext(container)
        engine = MockAudioEngine()
        manager = PlayerManager(engine: engine, modelContext: context, nowPlaying: NowPlayingService())
    }

    private func makePodcastWithEpisode(_ title: String, sortPosition: Int = 0) -> (Podcast, Episode) {
        let p = Podcast(title: title, author: "A", artworkURL: nil, feedURL: "https://example.com/\(title).xml", sortPosition: sortPosition)
        context.insert(p)
        let e = Episode(podcast: p, title: "\(title) latest", publishDate: .now, descriptionText: "", durationSeconds: 100, audioURL: "https://example.com/a.mp3")
        context.insert(e)
        p.episodes.append(e)
        return (p, e)
    }

    private func makeVibe(_ name: String, with podcasts: [Podcast]) -> Vibe {
        let v = Vibe(name: name, colorKey: .around, sortPosition: 0, isSeeded: false)
        context.insert(v)
        for (i, p) in podcasts.enumerated() {
            context.insert(VibeMembership(vibe: v, podcast: p, position: i))
        }
        return v
    }

    func test_startVibe_emptyResolved_returnsAllCaughtUp() throws {
        let (p, e) = makePodcastWithEpisode("HF")
        e.listenedStatus = .played
        e.playbackPosition = 100
        let vibe = makeVibe("Mix", with: [p])
        try context.save()

        let result = manager.startVibe(vibe)
        XCTAssertEqual(result, .allCaughtUp)
        XCTAssertNil(manager.currentEpisode)
        XCTAssertNil(manager.queueSourceVibe)
    }

    func test_startVibe_playsFirst_andSetsSource() throws {
        let (p1, _) = makePodcastWithEpisode("HF")
        let (p2, _) = makePodcastWithEpisode("99PI")
        let vibe = makeVibe("Mix", with: [p1, p2])
        try context.save()

        let result = manager.startVibe(vibe)
        XCTAssertEqual(result, .started)
        XCTAssertEqual(manager.currentEpisode?.podcast?.title, "HF")
        XCTAssertEqual(manager.queueSourceVibe?.persistentModelID, vibe.persistentModelID)
    }

    func test_startVibe_with_from_slices() throws {
        let (p1, _) = makePodcastWithEpisode("HF")
        let (p2, _) = makePodcastWithEpisode("99PI")
        let vibe = makeVibe("Mix", with: [p1, p2])
        try context.save()

        _ = manager.startVibe(vibe, from: p2)
        XCTAssertEqual(manager.currentEpisode?.podcast?.title, "99PI")
    }

    func test_outOfBandPlay_clearsQueueSource() throws {
        let (p1, _) = makePodcastWithEpisode("HF")
        let (p2, e2) = makePodcastWithEpisode("99PI", sortPosition: 1)
        let vibe = makeVibe("Mix", with: [p1])
        try context.save()

        _ = manager.startVibe(vibe)
        XCTAssertNotNil(manager.queueSourceVibe)

        manager.play(e2) // out-of-band tap from subscriptions list
        XCTAssertNil(manager.queueSourceVibe)
    }

    func test_autoAdvance_picksNextInVibeOrder() throws {
        let (p1, _) = makePodcastWithEpisode("HF")
        let (p2, _) = makePodcastWithEpisode("99PI")
        let vibe = makeVibe("Mix", with: [p1, p2])
        try context.save()

        _ = manager.startVibe(vibe)
        XCTAssertEqual(manager.currentEpisode?.podcast?.title, "HF")
        engine.simulatePlaybackEnd()
        XCTAssertEqual(manager.currentEpisode?.podcast?.title, "99PI")
    }

    func test_autoAdvance_skipsExhaustedPodcast() throws {
        let (p1, _) = makePodcastWithEpisode("HF")
        let (p2, e2) = makePodcastWithEpisode("99PI")
        e2.listenedStatus = .played
        e2.playbackPosition = 100
        let (p3, _) = makePodcastWithEpisode("Daily")
        let vibe = makeVibe("Mix", with: [p1, p2, p3])
        try context.save()

        _ = manager.startVibe(vibe)
        engine.simulatePlaybackEnd() // ends HF, should skip 99PI to Daily
        XCTAssertEqual(manager.currentEpisode?.podcast?.title, "Daily")
    }

    func test_autoAdvance_exhaustedQueue_clearsSource() throws {
        let (p1, _) = makePodcastWithEpisode("HF")
        let vibe = makeVibe("Mix", with: [p1])
        try context.save()

        _ = manager.startVibe(vibe)
        engine.simulatePlaybackEnd()
        XCTAssertNil(manager.queueSourceVibe)
        XCTAssertNotNil(manager.currentEpisode) // last episode stays for mini-player
    }

    func test_restore_recoversCurrentEpisodeAndSource() throws {
        let (p1, e1) = makePodcastWithEpisode("HF")
        let vibe = makeVibe("Mix", with: [p1])
        try context.save()
        _ = manager.startVibe(vibe)
        e1.playbackPosition = 42
        try context.save()

        // New PlayerManager on the same context (sim app restart).
        let engine2 = MockAudioEngine()
        let restored = PlayerManager(engine: engine2, modelContext: context, nowPlaying: NowPlayingService())
        XCTAssertEqual(restored.currentEpisode?.persistentModelID, e1.persistentModelID)
        XCTAssertEqual(restored.elapsed, 42, accuracy: 0.001)
        XCTAssertFalse(restored.isPlaying) // do not auto-resume
        XCTAssertEqual(restored.queueSourceVibe?.persistentModelID, vibe.persistentModelID)
    }
}
