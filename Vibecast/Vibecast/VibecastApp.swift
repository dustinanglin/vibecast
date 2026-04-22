import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    private let container: ModelContainer
    @State private var playerManager: PlayerManager

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Podcast.self, Episode.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        container = c

        let manager: PlayerManager = MainActor.assumeIsolated {
            SampleData.seedIfNeeded(into: ModelContext(c))
            return PlayerManager(engine: AVPlayerAudioEngine(), modelContext: ModelContext(c))
        }
        _playerManager = State(initialValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            SubscriptionsListView()
                .environment(\.playerManager, playerManager)
        }
        .modelContainer(container)
    }
}
