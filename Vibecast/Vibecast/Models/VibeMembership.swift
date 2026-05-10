import SwiftData
import Foundation

@Model
final class VibeMembership {
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
