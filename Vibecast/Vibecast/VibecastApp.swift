import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    private let container: ModelContainer

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Podcast.self, Episode.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        container = c
        MainActor.assumeIsolated {
            SampleData.seedIfNeeded(into: ModelContext(c))
        }
    }

    var body: some Scene {
        WindowGroup {
            SubscriptionsListView()
        }
        .modelContainer(container)
    }
}
