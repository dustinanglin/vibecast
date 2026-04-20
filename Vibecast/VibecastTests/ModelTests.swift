import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class ModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Podcast.self, Episode.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    func test_podcast_defaultSortPosition_isZero() throws {
        let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
        context.insert(p)
        try context.save()
        XCTAssertEqual(p.sortPosition, 0)
    }

    func test_episode_defaultListenedStatus_isUnplayed() throws {
        let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
        let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "Desc", durationSeconds: 3600, audioURL: "")
        context.insert(p)
        context.insert(e)
        try context.save()
        XCTAssertEqual(e.listenedStatus, .unplayed)
        XCTAssertEqual(e.playbackPosition, 0)
    }

    func test_episode_progressFraction_isZeroWhenUnplayed() throws {
        let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
        let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "", durationSeconds: 3600, audioURL: "")
        XCTAssertEqual(e.progressFraction, 0.0)
    }

    func test_episode_progressFraction_isCorrectWhenInProgress() throws {
        let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
        let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "", durationSeconds: 3600, audioURL: "")
        e.playbackPosition = 1800
        XCTAssertEqual(e.progressFraction, 0.5, accuracy: 0.001)
    }

    func test_episode_remainingSeconds_decreasesWithPlayback() throws {
        let p = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
        let e = Episode(podcast: p, title: "Ep 1", publishDate: .now, descriptionText: "", durationSeconds: 3600, audioURL: "")
        e.playbackPosition = 600
        XCTAssertEqual(e.remainingSeconds, 3000)
    }
}
