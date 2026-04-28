import XCTest
@testable import Vibecast

@MainActor
final class FeedFetcherTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test_fetch_routesBytesToRSSParser() async throws {
        let url = URL(string: "https://feeds.example.com/hardfork")!
        let xml = try fixture("feed-hardfork", ext: "xml")
        MockURLProtocol.register(url: url, data: xml)

        let fetcher = URLSessionFeedFetcher(session: MockURLProtocol.session())
        let feed = try await fetcher.fetch(url)

        XCTAssertEqual(feed.podcastTitle, "Hard Fork")
        XCTAssertEqual(feed.episodes.count, 3)
    }

    func test_fetch_propagatesNetworkError() async {
        let fetcher = URLSessionFeedFetcher(session: MockURLProtocol.session())
        let url = URL(string: "https://feeds.example.com/missing")!

        do {
            _ = try await fetcher.fetch(url)
            XCTFail("expected error")
        } catch {
            // expected
        }
    }

    func test_fetch_throwsServerError_on503Response() async throws {
        let url = URL(string: "https://example.com/feed")!
        MockURLProtocol.register(url: url, data: Data(), statusCode: 503)
        let fetcher = URLSessionFeedFetcher(session: MockURLProtocol.session())

        do {
            _ = try await fetcher.fetch(url)
            XCTFail("expected error")
        } catch let error as FeedFetchError {
            XCTAssertEqual(error, .serverError(status: 503))
        } catch {
            XCTFail("expected FeedFetchError, got \(error)")
        }
    }

    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
        return try Data(contentsOf: url)
    }
}
