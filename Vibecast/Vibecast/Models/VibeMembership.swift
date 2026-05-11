import SwiftData
import Foundation

@Model
final class VibeMembership {
    // Endpoints are Optional because SwiftData requires it on the inverse side
    // of a relationship; the non-optional init guarantees both are non-nil at
    // creation, and cascades delete the membership rather than nulling endpoints.
    var vibe: Vibe?
    var podcast: Podcast?
    var position: Int
    var taggedAt: Date

    init(vibe: Vibe, podcast: Podcast, position: Int) {
        self.vibe = vibe
        self.podcast = podcast
        self.position = position
        self.taggedAt = .now
    }
}
