import XCTest
import SwiftData
@testable import Vibecast

final class VibeModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, configurations: config)
        context = ModelContext(container)
    }

    func test_createVibe_persistsAndFetches() throws {
        let vibe = Vibe(name: "Morning", colorKey: .morning, sortPosition: 0, isSeeded: true)
        context.insert(vibe)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Vibe>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Morning")
        XCTAssertEqual(fetched.first?.colorKey, .morning)
        XCTAssertEqual(fetched.first?.isSeeded, true)
    }

    func test_vibeId_isStableAcrossSaves() throws {
        let vibe = Vibe(name: "Workout", colorKey: .workout, sortPosition: 0, isSeeded: false)
        context.insert(vibe)
        try context.save()
        let id1 = vibe.id
        try context.save()
        XCTAssertEqual(vibe.id, id1)
    }
}
