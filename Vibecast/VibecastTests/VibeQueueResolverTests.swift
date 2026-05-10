import XCTest
import SwiftData
@testable import Vibecast

final class VibeQueueResolverTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, QueueState.self, configurations: config)
        context = ModelContext(container)
    }

    private func makePodcast(_ title: String, episodes: [(date: Date, status: ListenedStatus, position: Double, duration: Int)]) -> Podcast {
        let p = Podcast(title: title, author: "A", artworkURL: nil, feedURL: "https://example.com/\(title).xml")
        context.insert(p)
        for spec in episodes {
            let e = Episode(podcast: p, title: "ep@\(spec.date.timeIntervalSince1970)", publishDate: spec.date, descriptionText: "", durationSeconds: spec.duration, audioURL: "https://example.com/a.mp3")
            e.listenedStatus = spec.status
            e.playbackPosition = spec.position
            context.insert(e)
            p.episodes.append(e)
        }
        return p
    }

    private func bind(_ podcasts: [Podcast], to vibe: Vibe) {
        for (i, p) in podcasts.enumerated() {
            context.insert(VibeMembership(vibe: vibe, podcast: p, position: i))
        }
    }

    func test_resolve_returnsLatestUnplayedPerPodcastInVibeOrder() throws {
        let now = Date()
        let p1 = makePodcast("HF", episodes: [
            (now, .unplayed, 0, 100),
            (now.addingTimeInterval(-86400), .played, 100, 100),
        ])
        let p2 = makePodcast("99PI", episodes: [
            (now.addingTimeInterval(-3600), .unplayed, 0, 200),
        ])
        let vibe = Vibe(name: "Mix", colorKey: .around, sortPosition: 0, isSeeded: false)
        context.insert(vibe)
        bind([p1, p2], to: vibe)
        try context.save()

        let queue = VibeQueueResolver.resolve(vibe: vibe)
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue[0].podcast.title, "HF")
        XCTAssertEqual(queue[1].podcast.title, "99PI")
    }

    func test_resolve_dropsPodcastsWithNoUnplayed() throws {
        let now = Date()
        let p1 = makePodcast("HF", episodes: [(now, .played, 100, 100)])
        let p2 = makePodcast("99PI", episodes: [(now, .unplayed, 0, 100)])
        let vibe = Vibe(name: "Mix", colorKey: .around, sortPosition: 0, isSeeded: false)
        context.insert(vibe)
        bind([p1, p2], to: vibe)
        try context.save()

        let queue = VibeQueueResolver.resolve(vibe: vibe)
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue[0].podcast.title, "99PI")
    }

    func test_resolve_treatsNearComplete_asPlayed() throws {
        // 96% played counts as played per the existing 0.95 threshold.
        let now = Date()
        let p1 = makePodcast("HF", episodes: [(now, .inProgress, 96, 100)])
        let p2 = makePodcast("99PI", episodes: [(now, .unplayed, 0, 100)])
        let vibe = Vibe(name: "Mix", colorKey: .around, sortPosition: 0, isSeeded: false)
        context.insert(vibe)
        bind([p1, p2], to: vibe)
        try context.save()

        let queue = VibeQueueResolver.resolve(vibe: vibe)
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue[0].podcast.title, "99PI")
    }

    func test_resolve_with_from_slicesQueue() throws {
        let now = Date()
        let p1 = makePodcast("HF", episodes: [(now, .unplayed, 0, 100)])
        let p2 = makePodcast("99PI", episodes: [(now, .unplayed, 0, 100)])
        let p3 = makePodcast("Daily", episodes: [(now, .unplayed, 0, 100)])
        let vibe = Vibe(name: "Mix", colorKey: .around, sortPosition: 0, isSeeded: false)
        context.insert(vibe)
        bind([p1, p2, p3], to: vibe)
        try context.save()

        let queue = VibeQueueResolver.resolve(vibe: vibe, from: p2)
        XCTAssertEqual(queue.map { $0.podcast.title }, ["99PI", "Daily"])
    }

    func test_resolve_with_from_unknownPodcast_returnsFullQueue() throws {
        let now = Date()
        let p1 = makePodcast("HF", episodes: [(now, .unplayed, 0, 100)])
        let p2 = makePodcast("99PI", episodes: [(now, .unplayed, 0, 100)])
        let vibe = Vibe(name: "Mix", colorKey: .around, sortPosition: 0, isSeeded: false)
        context.insert(vibe)
        bind([p1], to: vibe) // only p1 is a member
        try context.save()

        // p2 is not in the vibe; resolver should not crash, just return full queue.
        let queue = VibeQueueResolver.resolve(vibe: vibe, from: p2)
        XCTAssertEqual(queue.map { $0.podcast.title }, ["HF"])
    }

    func test_resolve_emptyVibe_returnsEmpty() throws {
        let vibe = Vibe(name: "Empty", colorKey: .winddown, sortPosition: 0, isSeeded: false)
        context.insert(vibe)
        try context.save()
        XCTAssertTrue(VibeQueueResolver.resolve(vibe: vibe).isEmpty)
    }
}
