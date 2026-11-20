import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class StageModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, configurations: config
        )
        context = ModelContext(container)
    }

    private func makePodcast(_ title: String = "Radiolab") -> Podcast {
        let podcast = Podcast(title: title, author: "A", artworkURL: nil, feedURL: "https://example.com/\(title).xml")
        context.insert(podcast)
        return podcast
    }

    private func assertShow(_ content: StageContent, _ expected: Podcast, line: UInt = #line) {
        guard case .show(let podcast) = content else {
            return XCTFail("expected .show, got \(content)", line: line)
        }
        XCTAssertEqual(podcast.persistentModelID, expected.persistentModelID, line: line)
    }

    func test_openShow_singlePane_pushesPodcast() {
        let model = StageModel()
        let podcast = makePodcast()
        model.openShow(podcast)
        XCTAssertEqual(model.pushedPodcast?.persistentModelID, podcast.persistentModelID)
        XCTAssertNil(model.shownPodcast)
    }

    func test_openShow_twoPane_showsOnStageWithoutPush() {
        let model = StageModel()
        model.setTwoPane(true)
        let podcast = makePodcast()
        model.openShow(podcast)
        XCTAssertNil(model.pushedPodcast)
        assertShow(model.content(hasLoadedEpisode: true), podcast)
    }

    func test_setTwoPane_false_whileShowOnStage_becomesPush() {
        let model = StageModel()
        model.setTwoPane(true)
        let podcast = makePodcast()
        model.openShow(podcast)
        model.setTwoPane(false)
        XCTAssertEqual(model.pushedPodcast?.persistentModelID, podcast.persistentModelID)
    }

    func test_setTwoPane_true_whilePushed_movesShowToStage() {
        let model = StageModel()
        let podcast = makePodcast()
        model.openShow(podcast)
        model.setTwoPane(true)
        XCTAssertNil(model.pushedPodcast)
        XCTAssertEqual(model.shownPodcast?.persistentModelID, podcast.persistentModelID)
    }

    func test_setTwoPane_true_dismissesPlayerSheet() {
        let model = StageModel()
        model.showNowPlaying()
        XCTAssertTrue(model.isPlayerSheetPresented)
        model.setTwoPane(true)
        XCTAssertFalse(model.isPlayerSheetPresented)
        guard case .nowPlaying = model.content(hasLoadedEpisode: true) else {
            return XCTFail("expected .nowPlaying")
        }
    }

    func test_setTwoPane_false_fromNowPlaying_doesNotPresentSheet() {
        let model = StageModel()
        model.setTwoPane(true)
        model.setTwoPane(false)
        XCTAssertFalse(model.isPlayerSheetPresented)
    }

    func test_showNowPlaying_twoPane_clearsShowAndPresentsNoSheet() {
        let model = StageModel()
        model.setTwoPane(true)
        model.openShow(makePodcast())
        model.showNowPlaying()
        XCTAssertNil(model.shownPodcast)
        XCTAssertFalse(model.isPlayerSheetPresented)
    }

    func test_pushedPodcastSetNil_twoPane_keepsShowOnStage() {
        let model = StageModel()
        let podcast = makePodcast()
        model.openShow(podcast)
        model.setTwoPane(true)
        model.pushedPodcast = nil
        XCTAssertEqual(model.shownPodcast?.persistentModelID, podcast.persistentModelID)
    }

    func test_podcastsDidChange_shownPodcastRemoved_fallsBackToNowPlaying() {
        let model = StageModel()
        model.setTwoPane(true)
        let podcast = makePodcast()
        model.openShow(podcast)
        model.podcastsDidChange(existing: [])
        XCTAssertNil(model.shownPodcast)
        guard case .nowPlaying = model.content(hasLoadedEpisode: true) else {
            return XCTFail("expected .nowPlaying")
        }
    }

    func test_podcastsDidChange_shownPodcastStillExists_keepsShow() {
        let model = StageModel()
        model.setTwoPane(true)
        let podcast = makePodcast()
        model.openShow(podcast)
        model.podcastsDidChange(existing: [podcast.persistentModelID])
        XCTAssertNotNil(model.shownPodcast)
    }

    func test_content_nothingLoaded_isEmpty() {
        let model = StageModel()
        model.setTwoPane(true)
        guard case .empty = model.content(hasLoadedEpisode: false) else {
            return XCTFail("expected .empty")
        }
    }

    func test_showsMiniPlayer_rules() {
        let model = StageModel()
        XCTAssertFalse(model.showsMiniPlayer(hasLoadedEpisode: false))
        XCTAssertTrue(model.showsMiniPlayer(hasLoadedEpisode: true))
        model.setTwoPane(true)
        XCTAssertFalse(model.showsMiniPlayer(hasLoadedEpisode: true))
        model.openShow(makePodcast())
        XCTAssertTrue(model.showsMiniPlayer(hasLoadedEpisode: true))
    }
}
