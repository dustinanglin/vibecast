import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer
    @State private var playerManager: PlayerManager
    @State private var subscriptionManager: SubscriptionManager

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Podcast.self, Episode.self)
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
        (player, subs) = MainActor.assumeIsolated {
            let p = PlayerManager(engine: AVPlayerAudioEngine(), modelContext: c.mainContext)
            let s = SubscriptionManager(
                searcher: iTunesSearchService(),
                fetcher: URLSessionFeedFetcher(),
                importer: StandardOPMLImporter(),
                modelContext: c.mainContext
            )
            return (p, s)
        }
        _playerManager = State(initialValue: player)
        _subscriptionManager = State(initialValue: subs)
    }

    var body: some Scene {
        WindowGroup {
            SubscriptionsListView()
                .environment(\.playerManager, playerManager)
                .environment(\.subscriptionManager, subscriptionManager)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                playerManager.saveCurrentState()
            }
        }
    }
}
