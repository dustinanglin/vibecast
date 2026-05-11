import XCTest
import SwiftData
@testable import Vibecast

final class VibeSeederTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, QueueState.self, configurations: config)
        context = ModelContext(container)
        suiteName = "vibe-seeder-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_seedsFiveVibes_onFirstCall() throws {
        try VibeSeeder.seedIfNeeded(in: context, defaults: defaults)
        let fetched = try context.fetch(FetchDescriptor<Vibe>(sortBy: [SortDescriptor(\.sortPosition)]))
        XCTAssertEqual(fetched.count, 5)
        XCTAssertEqual(fetched.map { $0.colorKey }, [.morning, .around, .workout, .winddown, .deepwork])
        XCTAssertEqual(fetched.map { $0.sortPosition }, [0, 1, 2, 3, 4])
        XCTAssertTrue(fetched.allSatisfy { $0.isSeeded })
        XCTAssertTrue(defaults.bool(forKey: VibeSeeder.seededFlagKey),
                      "flag must be set after a successful seed so the next launch skips")
    }

    func test_idempotent_secondCallNoOp() throws {
        try VibeSeeder.seedIfNeeded(in: context, defaults: defaults)
        try VibeSeeder.seedIfNeeded(in: context, defaults: defaults)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vibe>()), 5)
    }

    func test_doesNotReseed_afterUserDeletesAll() throws {
        try VibeSeeder.seedIfNeeded(in: context, defaults: defaults)
        // User deletes everything.
        for vibe in try context.fetch(FetchDescriptor<Vibe>()) {
            context.delete(vibe)
        }
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vibe>()), 0)

        // Re-seed call respects the flag and does NOT recreate.
        try VibeSeeder.seedIfNeeded(in: context, defaults: defaults)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vibe>()), 0)
    }
}
