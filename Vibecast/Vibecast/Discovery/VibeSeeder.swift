import Foundation
import SwiftData

enum VibeSeeder {
    /// `UserDefaults` key gating seeding. Presence (true) means we've already
    /// run; absence/false means we should run if no vibes exist yet.
    static let seededFlagKey = "vibesSeeded.v1"

    /// Seed the 5 starter vibes (Morning, Around, Workout, Wind down, Deep work)
    /// the first time the app runs after Plan 7 ships. Idempotent: a second call
    /// with the flag set is a no-op. Setting the flag on every call (whether or
    /// not we inserted) prevents re-seeding after the user deletes all vibes.
    static func seedIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) throws {
        if defaults.bool(forKey: seededFlagKey) { return }

        let existingCount = try context.fetchCount(FetchDescriptor<Vibe>())
        if existingCount == 0 {
            for (index, key) in VibeColorKey.allCases.enumerated() {
                let vibe = Vibe(
                    name: key.defaultName,
                    colorKey: key,
                    sortPosition: index,
                    isSeeded: true
                )
                context.insert(vibe)
            }
            try context.save()
        }
        defaults.set(true, forKey: seededFlagKey)
    }
}
