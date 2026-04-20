import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
final class SubscriptionsViewModel {
    private(set) var podcasts: [Podcast] = []
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetch()
    }

    func fetch() {
        let descriptor = FetchDescriptor<Podcast>(
            sortBy: [SortDescriptor(\.sortPosition)]
        )
        podcasts = (try? modelContext.fetch(descriptor)) ?? []
    }

    func remove(_ podcast: Podcast) {
        modelContext.delete(podcast)
        save()
        fetch()
    }

    func markPlayed(_ episode: Episode) {
        episode.listenedStatus = .played
        episode.playbackPosition = Double(episode.durationSeconds)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        podcasts.move(fromOffsets: source, toOffset: destination)
        for (index, podcast) in podcasts.enumerated() {
            podcast.sortPosition = index
        }
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
