import Foundation

/// Methods `NowPlayingService` invokes in response to lock-screen / Control
/// Center / AirPods commands. `PlayerManager` conforms.
@MainActor
protocol PlaybackController: AnyObject {
    func togglePlayPause()
    func seek(to seconds: TimeInterval)
    func skipForward(_ seconds: TimeInterval)
    func skipBack(_ seconds: TimeInterval)
}
