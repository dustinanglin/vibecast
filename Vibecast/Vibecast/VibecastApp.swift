import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var playerManager: PlayerManager
    @State private var subscriptionManager: SubscriptionManager
    @State private var downloadManager: DownloadManager
    /// Cold-launch gate for the animated splash. `@State` on the root
    /// scene view persists for the lifetime of the app process, so
    /// foregrounding from background reads `true` and skips the splash.
    /// On cold relaunch (iOS evicted the process), this resets to false
    /// and the splash plays again.
    @State private var hasShownSplash: Bool = false
    @State private var splashMode: SplashMode = VibecastApp.splashMode()

    static let hasCompletedFirstLaunchKey = "hasCompletedFirstLaunch"

    static func splashMode(defaults: UserDefaults = .standard) -> SplashMode {
        defaults.bool(forKey: hasCompletedFirstLaunchKey) ? .brief : .full
    }

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, QueueState.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        container = c

        // Both managers share the views' main context so writes are immediately
        // visible to any @Query / FetchDescriptor reads in the same context.
        // No more sample-data seed — first-launch users see the empty state
        // hint Task 2 adds. Existing testers keep their seeded podcasts.
        let player: PlayerManager
        let subs: SubscriptionManager
        let downloads: DownloadManager
        (player, subs, downloads) = MainActor.assumeIsolated {
            let nowPlaying = NowPlayingService()
            let p = PlayerManager(engine: AVPlayerAudioEngine(), modelContext: c.mainContext, nowPlaying: nowPlaying)
            nowPlaying.controller = p
            let s = SubscriptionManager(
                searcher: iTunesSearchService(),
                fetcher: URLSessionFeedFetcher(),
                importer: StandardOPMLImporter(),
                modelContext: c.mainContext
            )
            let d = DownloadManager(modelContext: c.mainContext)
            s.onNewEpisodes = { [weak d] episodes in
                d?.autoDownload(newEpisodes: episodes)
            }
            AppDelegate.downloadManager = d
            p.downloadManager = d
            try? VibeSeeder.seedIfNeeded(in: c.mainContext)
            return (p, s, d)
        }
        _playerManager = State(initialValue: player)
        _subscriptionManager = State(initialValue: subs)
        _downloadManager = State(initialValue: downloads)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                SubscriptionsListView()
                    .environment(\.playerManager, playerManager)
                    .environment(\.subscriptionManager, subscriptionManager)
                    .environment(\.downloadManager, downloadManager)
                    .environment(\.duoPose, DuoPoseMonitor.shared.pose)
                    .preferredColorScheme(.light)
                    .onOpenURL { url in
                        VibecastURLHandler.handle(url, session: .shared)
                    }

                if !hasShownSplash {
                    SplashView(mode: splashMode) {
                        UserDefaults.standard.set(true, forKey: VibecastApp.hasCompletedFirstLaunchKey)
                        withAnimation(.easeInOut(duration: 0.45)) {
                            hasShownSplash = true
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                playerManager.saveCurrentState()
            }
        }
    }
}
