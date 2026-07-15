import UIKit

/// Minimal app delegate whose ONLY job is receiving the background-
/// URLSession relaunch callback and parking the completion handler on
/// DownloadManager. Everything else stays in the SwiftUI App.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set by VibecastApp.init once the manager exists.
    @MainActor static weak var downloadManager: DownloadManager?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == DownloadManager.sessionIdentifier else {
            completionHandler()
            return
        }
        MainActor.assumeIsolated {
            AppDelegate.downloadManager?.backgroundCompletionHandler = completionHandler
        }
    }
}
