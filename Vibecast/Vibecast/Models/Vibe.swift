import SwiftData
import Foundation

@Model
final class Vibe {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorKey: VibeColorKey
    var sortPosition: Int
    var isSeeded: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \VibeMembership.vibe)
    var memberships: [VibeMembership] = []

    init(name: String, colorKey: VibeColorKey, sortPosition: Int, isSeeded: Bool) {
        self.id = UUID()
        self.name = name
        self.colorKey = colorKey
        self.sortPosition = sortPosition
        self.isSeeded = isSeeded
        self.createdAt = .now
    }
}
