import SwiftData
import Foundation

@Model
final class Podcast {
    var title: String
    var author: String
    var artworkURL: String?
    var feedURL: String
    var sortPosition: Int
    @Relationship(deleteRule: .cascade) var episodes: [Episode]

    init(title: String, author: String, artworkURL: String?, feedURL: String, sortPosition: Int = 0) {
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.feedURL = feedURL
        self.sortPosition = sortPosition
        self.episodes = []
    }
}
