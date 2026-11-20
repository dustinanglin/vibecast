import UIKit

/// Minimal app delegate: receives the background-URLSession relaunch
/// callback and parks the completion handler on DownloadManager, and names
/// the scene delegate that tracks the iPhone Duo hinge. Everything else
/// stays in the SwiftUI App.
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

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
