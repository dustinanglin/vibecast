import XCTest
@testable import Vibecast

@MainActor
final class PodcastSearchServiceTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test_search_emptyQuery_returnsEmpty() async throws {
        let session = MockURLProtocol.session()
        let service = iTunesSearchService(session: session)
        let results = try await service.search("")
        XCTAssertEqual(results.count, 0)
    }

    func test_search_decodesITunesResponse() async throws {
        let url = URL(string: "https://itunes.apple.com/search?media=podcast&term=hardfork&limit=25")!
        let data = try fixture("itunes-search-hardfork", ext: "json")
        MockURLProtocol.register(url: url, data: data)

        let service = iTunesSearchService(session: MockURLProtocol.session())
        let results = try await service.search("hardfork")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].id, 1528594034)
        XCTAssertEqual(results[0].title, "Hard Fork")
        XCTAssertEqual(results[0].author, "The New York Times")
        XCTAssertEqual(results[0].artworkURL?.absoluteString, "https://example.com/hardfork600.jpg")
        XCTAssertEqual(results[0].feedURL.absoluteString, "https://feeds.simplecast.com/l2i9YnTd")
    }

    func test_search_urlEncodesQuery() async throws {
        let url = URL(string: "https://itunes.apple.com/search?media=podcast&term=hard%20fork&limit=25")!
        let data = try fixture("itunes-search-hardfork", ext: "json")
        MockURLProtocol.register(url: url, data: data)

        let service = iTunesSearchService(session: MockURLProtocol.session())
        let results = try await service.search("hard fork")

        XCTAssertEqual(results.count, 2)
    }

    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
        return try Data(contentsOf: url)
    }
}
