import XCTest
@testable import Vibecast

final class RSSParserTests: XCTestCase {

    func test_parse_extractsChannelMetadata() throws {
        let data = try fixture("feed-hardfork", ext: "xml")
        let feed = try RSSParser().parse(data)

        XCTAssertEqual(feed.podcastTitle, "Hard Fork")
        XCTAssertEqual(feed.podcastAuthor, "The New York Times")
        XCTAssertEqual(feed.artworkURL?.absoluteString, "https://example.com/hardfork-channel.jpg")
    }

    func test_parse_extractsEpisodes_sortedByDateDescending() throws {
        let data = try fixture("feed-hardfork", ext: "xml")
        let feed = try RSSParser().parse(data)

        XCTAssertEqual(feed.episodes.count, 3)
        XCTAssertEqual(feed.episodes[0].title, "The Future of AI Regulation")
        XCTAssertEqual(feed.episodes[1].title, "Inside the Semiconductor Supply Chain")
        XCTAssertEqual(feed.episodes[2].title, "Episode With No Duration")
    }

    func test_parse_handlesHMSDuration() throws {
        let data = try fixture("feed-hardfork", ext: "xml")
        let feed = try RSSParser().parse(data)

        // 1:02:30 → 3750
        XCTAssertEqual(feed.episodes[0].durationSeconds, 3750)
    }

    func test_parse_handlesRawSecondsDuration() throws {
        let data = try fixture("feed-hardfork", ext: "xml")
        let feed = try RSSParser().parse(data)

        XCTAssertEqual(feed.episodes[1].durationSeconds, 2700)
    }

    func test_parse_missingDurationDefaultsToZero() throws {
        let data = try fixture("feed-hardfork", ext: "xml")
        let feed = try RSSParser().parse(data)

        XCTAssertEqual(feed.episodes[2].durationSeconds, 0)
    }

    func test_parse_explicitFlagParsed() throws {
        let data = try fixture("feed-hardfork", ext: "xml")
        let feed = try RSSParser().parse(data)

        XCTAssertFalse(feed.episodes[0].isExplicit)
        XCTAssertTrue(feed.episodes[1].isExplicit)
        XCTAssertFalse(feed.episodes[2].isExplicit)  // default when absent
    }

    func test_parse_audioURLFromEnclosure() throws {
        let data = try fixture("feed-hardfork", ext: "xml")
        let feed = try RSSParser().parse(data)

        XCTAssertEqual(feed.episodes[0].audioURL, "https://example.com/episode-3.mp3")
    }

    func test_parse_capsAtFiftyEpisodes() throws {
        var xml = "<?xml version=\"1.0\"?><rss version=\"2.0\"><channel><title>T</title>"
        for i in 0..<60 {
            let date = String(format: "Wed, %02d Apr 2026 09:00:00 +0000", (i % 28) + 1)
            xml += """
            <item><title>E\(i)</title><pubDate>\(date)</pubDate>\
            <enclosure url="https://x/\(i).mp3" length="0" type="audio/mpeg"/></item>
            """
        }
        xml += "</channel></rss>"

        let feed = try RSSParser().parse(Data(xml.utf8))
        XCTAssertEqual(feed.episodes.count, 50)
    }

    func test_sanitizeDescription_stripsHTMLTags() {
        let raw = "<p>Hello <strong>world</strong></p><ul><li>One</li><li>Two</li></ul>"
        XCTAssertEqual(RSSParser.sanitizeDescription(raw), "Hello world One Two")
    }

    func test_sanitizeDescription_decodesCommonEntities() {
        let raw = "Tom &amp; Jerry &lt;3 &nbsp;&quot;hello&quot;"
        XCTAssertEqual(RSSParser.sanitizeDescription(raw), "Tom & Jerry <3 \"hello\"")
    }

    func test_sanitizeDescription_collapsesWhitespace() {
        let raw = "<p>Line 1</p>\n\n<p>Line   2</p>"
        XCTAssertEqual(RSSParser.sanitizeDescription(raw), "Line 1 Line 2")
    }

    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
        return try Data(contentsOf: url)
    }
}
