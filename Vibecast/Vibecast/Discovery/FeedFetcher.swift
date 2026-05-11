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
        // RSSParser walks the XML stream synchronously, which on real feeds
        // (many tens of episodes, kilobytes of HTML in descriptions) is a
        // CPU-bound multi-tens-of-ms job. Hop off the main actor so the
        // parse doesn't hitch scroll animations during refresh.
        return try await parseRSSOffMain(data: data)
    }
}

/// Parses RSS XML on a global-concurrent queue and bridges back to the
/// caller via a continuation. Free function (not a method) so there's no
/// enclosing actor context to confuse Swift's strict-concurrency analysis
/// of `Task.detached` — using `Task.detached` from within an `@MainActor`
/// class trips a "expression is async but not marked with await" warning
/// on the synchronous parse call inside the closure, even when the
/// closure is explicitly nonisolated.
private func parseRSSOffMain(data: Data) async throws -> ParsedFeed {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let feed = try RSSParser().parse(data)
                continuation.resume(returning: feed)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
