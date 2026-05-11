import XCTest
import SwiftData
@testable import Vibecast

final class VibeMembershipTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, configurations: config)
        context = ModelContext(container)
    }

    func makePodcast(_ title: String) -> Podcast {
        let p = Podcast(title: title, author: "A", artworkURL: nil, feedURL: "https://example.com/\(title).xml")
        context.insert(p)
        return p
    }

    func makeVibe(_ name: String, _ key: VibeColorKey, _ pos: Int) -> Vibe {
        let v = Vibe(name: name, colorKey: key, sortPosition: pos, isSeeded: false)
        context.insert(v)
        return v
    }

    func test_singlePodcast_inThreeVibes() throws {
        let p = makePodcast("Hard Fork")
        let v1 = makeVibe("Morning", .morning, 0)
        let v2 = makeVibe("Around", .around, 1)
        let v3 = makeVibe("Workout", .workout, 2)
        for (i, v) in [v1, v2, v3].enumerated() {
            context.insert(VibeMembership(vibe: v, podcast: p, position: i))
        }
        try context.save()

        XCTAssertEqual(p.vibeMemberships.count, 3)
        XCTAssertEqual(Set(p.vibeMemberships.compactMap { $0.vibe?.name }), ["Morning", "Around", "Workout"])
    }

    func test_perVibeOrdering_isIndependent() throws {
        let p1 = makePodcast("Hard Fork")
        let p2 = makePodcast("99% Invisible")
        let morning = makeVibe("Morning", .morning, 0)
        let workout = makeVibe("Workout", .workout, 1)

        // p1 first in Morning, p2 second
        context.insert(VibeMembership(vibe: morning, podcast: p1, position: 0))
        context.insert(VibeMembership(vibe: morning, podcast: p2, position: 1))
        // Inverted in Workout
        context.insert(VibeMembership(vibe: workout, podcast: p2, position: 0))
        context.insert(VibeMembership(vibe: workout, podcast: p1, position: 1))
        try context.save()

        let morningOrder = morning.memberships.sorted(by: { $0.position < $1.position }).compactMap { $0.podcast?.title }
        let workoutOrder = workout.memberships.sorted(by: { $0.position < $1.position }).compactMap { $0.podcast?.title }
        XCTAssertEqual(morningOrder, ["Hard Fork", "99% Invisible"])
        XCTAssertEqual(workoutOrder, ["99% Invisible", "Hard Fork"])
    }

    func test_deleteVibe_cascadesMemberships_podcastSurvives() throws {
        let p = makePodcast("Hard Fork")
        let v = makeVibe("Morning", .morning, 0)
        let other = makeVibe("Around", .around, 1)
        context.insert(VibeMembership(vibe: v, podcast: p, position: 0))
        context.insert(VibeMembership(vibe: other, podcast: p, position: 0))
        try context.save()

        context.delete(v)
        try context.save()

        // Podcast survives, other vibe's membership survives, deleted vibe's membership is gone.
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Podcast>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VibeMembership>()), 1)
        XCTAssertEqual(p.vibeMemberships.count, 1)
        XCTAssertEqual(p.vibeMemberships.first?.vibe?.name, "Around")
    }

    func test_deletePodcast_cascadesMemberships_vibeSurvives() throws {
        let p = makePodcast("Hard Fork")
        let q = makePodcast("99% Invisible")
        let v = makeVibe("Morning", .morning, 0)
        context.insert(VibeMembership(vibe: v, podcast: p, position: 0))
        context.insert(VibeMembership(vibe: v, podcast: q, position: 1))
        try context.save()

        context.delete(p)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vibe>()), 1)
        XCTAssertEqual(v.memberships.count, 1)
        XCTAssertEqual(v.memberships.first?.podcast?.title, "99% Invisible")
    }

    func test_deleteMembership_leavesVibeAndPodcastIntact() throws {
        let p = makePodcast("Hard Fork")
        let v = makeVibe("Morning", .morning, 0)
        let membership = VibeMembership(vibe: v, podcast: p, position: 0)
        context.insert(membership)
        try context.save()

        context.delete(membership)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vibe>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Podcast>()), 1)
        XCTAssertEqual(v.memberships.count, 0)
        XCTAssertEqual(p.vibeMemberships.count, 0)
    }
}
