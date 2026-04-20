import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class SubscriptionsViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)
        SampleData.insertSampleData(into: context)
    }

    func test_podcasts_sortedBySortPosition() throws {
        let vm = SubscriptionsViewModel(modelContext: context)
        let positions = vm.podcasts.map(\.sortPosition)
        XCTAssertEqual(positions, positions.sorted())
    }

    func test_remove_decreasesCount() throws {
        let vm = SubscriptionsViewModel(modelContext: context)
        let before = vm.podcasts.count
        vm.remove(vm.podcasts[0])
        XCTAssertEqual(vm.podcasts.count, before - 1)
    }

    func test_markPlayed_setsStatusToPlayed() throws {
        let vm = SubscriptionsViewModel(modelContext: context)
        let episode = vm.podcasts[0].episodes[0]
        vm.markPlayed(episode)
        XCTAssertEqual(episode.listenedStatus, .played)
        XCTAssertEqual(episode.playbackPosition, Double(episode.durationSeconds))
    }

    func test_move_reassignsSortPositionsSequentially() throws {
        let vm = SubscriptionsViewModel(modelContext: context)
        vm.move(from: IndexSet(integer: 0), to: 3)
        let positions = vm.podcasts.map(\.sortPosition)
        XCTAssertEqual(positions, Array(0..<vm.podcasts.count))
    }

    func test_move_changesOrder() throws {
        let vm = SubscriptionsViewModel(modelContext: context)
        let originalFirst = vm.podcasts[0].title
        vm.move(from: IndexSet(integer: 0), to: 3)
        XCTAssertNotEqual(vm.podcasts[0].title, originalFirst)
    }
}
