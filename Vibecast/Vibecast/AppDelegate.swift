import UIKit

/// Minimal app delegate: receives the background-URLSession relaunch
/// callback and parks the completion handler on DownloadManager, and
/// answers which orientations the app supports for the current iPhone Duo
/// pose. Everything else stays in the SwiftUI App.
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

    /// Info.plist is portrait-only; this widens it to landscape while an
    /// iPhone Duo is open. Every other iPhone keeps getting `.portrait`.
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { DuoPoseMonitor.shared.pose.supportedOrientations }
    }
}
