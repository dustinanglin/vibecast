import XCTest
import SwiftData
@testable import Vibecast

final class QueueStateTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, QueueState.self, configurations: config)
        context = ModelContext(container)
    }

    func test_singleton_lazyCreatesOnFirstFetch() throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QueueState>()), 0)
        let state = try QueueState.fetchOrCreate(in: context)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QueueState>()), 1)
        XCTAssertEqual(state.sourceVibe, nil)
        XCTAssertEqual(state.currentEpisode, nil)
    }

    func test_singleton_secondFetch_returnsSameRow() throws {
        let a = try QueueState.fetchOrCreate(in: context)
        try context.save()
        let b = try QueueState.fetchOrCreate(in: context)
        XCTAssertEqual(a.persistentModelID, b.persistentModelID)
    }

    func test_persistsSourceVibe_acrossContextReload() throws {
        let vibe = Vibe(name: "Workout", colorKey: .workout, sortPosition: 0, isSeeded: true)
        context.insert(vibe)
        let state = try QueueState.fetchOrCreate(in: context)
        state.sourceVibe = vibe
        state.lastUpdated = .now
        try context.save()

        let fresh = ModelContext(container)
        let restored = try QueueState.fetchOrCreate(in: fresh)
        XCTAssertEqual(restored.sourceVibe?.name, "Workout")
    }
}
