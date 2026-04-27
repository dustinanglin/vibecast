import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class SubscriptionsRemovalTests: XCTestCase {
    func test_middleRowDelete_leavesRemainingPodcastsIntact() throws {
        let schema = Schema([Podcast.self, Episode.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let titles = ["A", "B", "C", "D"]
        let podcasts = titles.enumerated().map { i, title in
            let p = Podcast(title: title, author: "x", artworkURL: nil, feedURL: "https://e.com/\(title)", sortPosition: i)
            context.insert(p)
            return p
        }
        try context.save()

        // Delete the middle row (index 2 — "C")
        let toDelete = podcasts[2]
        context.delete(toDelete)
        try context.save()

        let remaining = try context.fetch(
            FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
        )
        XCTAssertEqual(remaining.map(\.title), ["A", "B", "D"])
    }

    func test_repeatedMiddleDeletes_doNotCrash() throws {
        let schema = Schema([Podcast.self, Episode.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        for i in 0..<6 {
            let p = Podcast(title: "P\(i)", author: "a", artworkURL: nil, feedURL: "https://e.com/\(i)", sortPosition: i)
            context.insert(p)
            // Add an episode so cascade has something to do
            let ep = Episode(podcast: p, title: "ep\(i)", publishDate: .now, descriptionText: "", durationSeconds: 60, audioURL: "https://e.com/\(i).mp3")
            context.insert(ep)
        }
        try context.save()

        // Repeatedly delete the current middle index until 1 remains
        var current = try context.fetch(FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)]))
        while current.count > 1 {
            let middle = current[current.count / 2]
            context.delete(middle)
            try context.save()
            current = try context.fetch(FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)]))
        }
        XCTAssertEqual(current.count, 1)
    }
}
