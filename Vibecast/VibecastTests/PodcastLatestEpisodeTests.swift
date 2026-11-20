import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class PodcastLatestEpisodeTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func makePodcast(episodeDates: [Date]) throws -> Podcast {
        let podcast = Podcast(title: "Test", author: "Author", artworkURL: nil, feedURL: "https://example.com/feed")
        context.insert(podcast)
        for (index, date) in episodeDates.enumerated() {
            context.insert(Episode(
                podcast: podcast, title: "Ep \(index)", publishDate: date,
                descriptionText: "", durationSeconds: 60, audioURL: "https://example.com/\(index).mp3"
            ))
        }
        try context.save()
        return podcast
    }

    func test_latestEpisode_noEpisodes_isNil() throws {
        XCTAssertNil(try makePodcast(episodeDates: []).latestEpisode)
    }

    func test_latestEpisode_returnsMostRecentlyPublished() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let podcast = try makePodcast(episodeDates: [
            base, base.addingTimeInterval(500), base.addingTimeInterval(100),
        ])
        XCTAssertEqual(podcast.latestEpisode?.title, "Ep 1")
    }

    func test_latestEpisode_matchesNewestFirstSort_forLargeCatalog() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let dates = (0..<400).map { base.addingTimeInterval(Double(($0 * 7919) % 400) * 3600) }
        let podcast = try makePodcast(episodeDates: dates)
        let expected = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
        XCTAssertEqual(podcast.latestEpisode?.persistentModelID, expected?.persistentModelID)
    }
}
