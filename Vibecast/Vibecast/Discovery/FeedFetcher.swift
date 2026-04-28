import Foundation

enum FeedFetchError: Error, Equatable {
    case invalidResponse
    case serverError(status: Int)
}

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
        let url = feedURL.upgradedToHTTPS()
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw FeedFetchError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw FeedFetchError.serverError(status: http.statusCode)
        }
        return try RSSParser().parse(data)
    }
}
