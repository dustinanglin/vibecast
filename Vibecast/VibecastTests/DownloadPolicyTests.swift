import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class DownloadPolicyTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, QueueState.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func makeEpisode(podcast: Podcast, title: String, daysAgo: Int) -> Episode {
        let episode = Episode(
            podcast: podcast,
            title: title,
            publishDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            descriptionText: "",
            durationSeconds: 1800,
            audioURL: "https://example.com/\(UUID().uuidString).mp3"
        )
        context.insert(episode)
        podcast.episodes.append(episode)
        return episode
    }

    private func makePodcast(title: String) -> Podcast {
        let podcast = Podcast(title: title, author: "A", artworkURL: nil, feedURL: "https://example.com/\(title)", sortPosition: 0)
        context.insert(podcast)
        return podcast
    }

    // MARK: - DownloadState accessor

    func test_downloadState_defaultsToNone() throws {
        let podcast = makePodcast(title: "Show")
        let episode = makeEpisode(podcast: podcast, title: "Ep", daysAgo: 0)
        XCTAssertEqual(episode.downloadState, DownloadState.none)
        XCTAssertFalse(episode.isManualDownload)
        XCTAssertNil(episode.downloadedAt)
    }

    func test_downloadState_roundTripsThroughRaw() throws {
        let podcast = makePodcast(title: "Show")
        let episode = makeEpisode(podcast: podcast, title: "Ep", daysAgo: 0)
        episode.downloadState = .downloaded
        XCTAssertEqual(episode.downloadStateRaw, "downloaded")
        XCTAssertEqual(episode.downloadState, .downloaded)
    }

    func test_downloadState_garbageRawFallsBackToNone() throws {
        let podcast = makePodcast(title: "Show")
        let episode = makeEpisode(podcast: podcast, title: "Ep", daysAgo: 0)
        episode.downloadStateRaw = "garbage"
        XCTAssertEqual(episode.downloadState, DownloadState.none)
    }
}
