import XCTest
import MediaPlayer
@testable import Vibecast

@MainActor
final class NowPlayingServiceTests: XCTestCase {
    func test_update_populatesNowPlayingInfo_withRequiredKeys() {
        let service = NowPlayingService()
        let state = PlaybackState(
            episodeTitle: "Hard Fork: AI Bubbles",
            podcastTitle: "Hard Fork",
            author: "The New York Times",
            duration: 3600,
            elapsed: 120,
            isPlaying: true,
            artworkURL: nil
        )

        service.update(state: state)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "Hard Fork: AI Bubbles")
        XCTAssertEqual(info[MPMediaItemPropertyAlbumTitle] as? String, "Hard Fork")
        XCTAssertEqual(info[MPMediaItemPropertyArtist] as? String, "The New York Times")
        XCTAssertEqual(info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval, 3600)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval, 120)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
    }

    func test_update_paused_setsRateZero() {
        let service = NowPlayingService()
        let state = PlaybackState(
            episodeTitle: "x", podcastTitle: "x", author: "x",
            duration: 100, elapsed: 50, isPlaying: false, artworkURL: nil
        )
        service.update(state: state)
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0.0)
    }

    func test_clear_emptiesNowPlayingInfo() {
        let service = NowPlayingService()
        service.update(state: PlaybackState(
            episodeTitle: "x", podcastTitle: "x", author: "x",
            duration: 100, elapsed: 0, isPlaying: false, artworkURL: nil
        ))
        service.clear()
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }
}
