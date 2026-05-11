import Foundation
import Observation

/// Holds the most recent payload received from the "Vibecast Import" Shortcuts
/// shortcut. The URL handler writes here on `.onOpenURL`; the wizard and
/// `SubscriptionsListView` observe.
///
/// `shouldPresentWizard` is a one-shot flag: the URL handler sets it true and
/// `SubscriptionsListView` immediately resets it on present, so re-opening the
/// wizard later requires a fresh shortcut run to trigger an auto-present.
///
/// Payloads are treated as stale after 5 minutes via `isFresh`. The wizard
/// shows a "run the shortcut again" message instead of offering the Import
/// button when stale, preventing an auto-import of a long-abandoned payload
/// after the user has changed their Apple Podcasts subscriptions in the
/// meantime.
@Observable
@MainActor
final class ApplePodcastsImportSession {
    static let shared = ApplePodcastsImportSession()

    var pendingFeedURLs: [URL]? = nil
    var receivedAt: Date? = nil
    var shouldPresentWizard: Bool = false

    /// 5-minute freshness window.
    private static let freshnessSeconds: TimeInterval = 300

    var isFresh: Bool {
        guard let receivedAt else { return false }
        return Date().timeIntervalSince(receivedAt) < Self.freshnessSeconds
    }

    init() {}

    func receive(_ urls: [URL]) {
        pendingFeedURLs = urls
        receivedAt = .now
        shouldPresentWizard = true
    }

    func clear() {
        pendingFeedURLs = nil
        receivedAt = nil
        shouldPresentWizard = false
    }
}
