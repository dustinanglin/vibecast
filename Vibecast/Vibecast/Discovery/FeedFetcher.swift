import Foundation

@MainActor
protocol FeedFetcher {
    func fetch(_ feedURL: URL) async throws -> ParsedFeed
}

@MainActor
final class URLSessionFeedFetcher: FeedFetcher {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(_ feedURL: URL) async throws -> ParsedFeed {
        let (data, _) = try await session.data(from: feedURL)
        return try RSSParser().parse(data)
    }
}
