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

    // MARK: - autoDownloadCandidates

    func test_autoDownloadCandidates_picksNewestPerShow() throws {
        let showA = makePodcast(title: "A")
        let showB = makePodcast(title: "B")
        let aOld = makeEpisode(podcast: showA, title: "a-old", daysAgo: 2)
        let aNew = makeEpisode(podcast: showA, title: "a-new", daysAgo: 0)
        let bOnly = makeEpisode(podcast: showB, title: "b", daysAgo: 1)

        let picked = DownloadPolicy.autoDownloadCandidates(from: [aOld, aNew, bOnly])

        XCTAssertEqual(picked.count, 2)
        XCTAssertTrue(picked.contains(where: { $0.title == "a-new" }))
        XCTAssertTrue(picked.contains(where: { $0.title == "b" }))
        XCTAssertFalse(picked.contains(where: { $0.title == "a-old" }))
    }

    func test_autoDownloadCandidates_skipsAlreadyDownloadedOrDownloading() throws {
        let show = makePodcast(title: "A")
        let episode = makeEpisode(podcast: show, title: "ep", daysAgo: 0)
        episode.downloadState = .downloaded
        XCTAssertTrue(DownloadPolicy.autoDownloadCandidates(from: [episode]).isEmpty)
        episode.downloadState = .downloading
        XCTAssertTrue(DownloadPolicy.autoDownloadCandidates(from: [episode]).isEmpty)
    }

    func test_autoDownloadCandidates_emptyInput() {
        XCTAssertTrue(DownloadPolicy.autoDownloadCandidates(from: []).isEmpty)
    }

    // MARK: - pruneCandidates

    func test_pruneCandidates_keepsNewestN_dropsRest() throws {
        let show = makePodcast(title: "A")
        var episodes: [Episode] = []
        for i in 0..<5 {
            let e = makeEpisode(podcast: show, title: "ep\(i)", daysAgo: i)
            e.downloadState = .downloaded
            episodes.append(e)
        }

        let victims = DownloadPolicy.pruneCandidates(in: episodes, keepLastN: 3)

        XCTAssertEqual(victims.count, 2)
        XCTAssertEqual(Set(victims.map(\.title)), ["ep3", "ep4"])  // the two oldest
    }

    func test_pruneCandidates_manualDownloadsExempt() throws {
        let show = makePodcast(title: "A")
        var episodes: [Episode] = []
        for i in 0..<4 {
            let e = makeEpisode(podcast: show, title: "ep\(i)", daysAgo: i)
            e.downloadState = .downloaded
            e.isManualDownload = (i == 3)  // the oldest is manual
            episodes.append(e)
        }

        let victims = DownloadPolicy.pruneCandidates(in: episodes, keepLastN: 3)

        // 3 auto-downloads exist (ep0-ep2), all within keep-3; the manual
        // ep3 is exempt even though it's oldest.
        XCTAssertTrue(victims.isEmpty)
    }

    func test_pruneCandidates_zeroMeansUnlimited() throws {
        let show = makePodcast(title: "A")
        var episodes: [Episode] = []
        for i in 0..<5 {
            let e = makeEpisode(podcast: show, title: "ep\(i)", daysAgo: i)
            e.downloadState = .downloaded
            episodes.append(e)
        }
        XCTAssertTrue(DownloadPolicy.pruneCandidates(in: episodes, keepLastN: 0).isEmpty)
    }

    func test_pruneCandidates_ignoresNonDownloaded() throws {
        let show = makePodcast(title: "A")
        let e = makeEpisode(podcast: show, title: "ep", daysAgo: 0)
        e.downloadState = .failed
        XCTAssertTrue(DownloadPolicy.pruneCandidates(in: [e], keepLastN: 1).isEmpty)
    }
}
