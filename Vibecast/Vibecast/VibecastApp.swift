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

        let players: PlayerManager
        let subs: SubscriptionManager
        (players, subs) = MainActor.assumeIsolated {
            SampleData.seedIfNeeded(into: ModelContext(c))
            let p = PlayerManager(engine: AVPlayerAudioEngine(), modelContext: ModelContext(c))
            let s = SubscriptionManager(
                searcher: iTunesSearchService(),
                fetcher: URLSessionFeedFetcher(),
                modelContext: ModelContext(c)
            )
            return (p, s)
        }
        _playerManager = State(initialValue: players)
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
