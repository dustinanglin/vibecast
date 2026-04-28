import XCTest
@testable import Vibecast

@MainActor
final class OPMLImporterTests: XCTestCase {

    func test_extractFeedURLs_flattensCategoryOutlines() throws {
        let data = try fixture("opml-apple-podcasts", ext: "xml")
        let urls = try StandardOPMLImporter().extractFeedURLs(from: data)

        XCTAssertEqual(Set(urls.map(\.absoluteString)), [
            "https://feeds.simplecast.com/6HKOhNgS",
            "https://feeds.transistor.fm/acquired",
            "https://feeds.megaphone.fm/vergecast",
            "https://feeds.simplecast.com/54nAGcIl",
            "https://example.com/toplevel.xml",
        ])
    }

    func test_extractFeedURLs_dedupesWithinFile() throws {
        let data = try fixture("opml-apple-podcasts", ext: "xml")
        let urls = try StandardOPMLImporter().extractFeedURLs(from: data)

        // Hard Fork appears in both Technology and News categories
        let hardForkCount = urls.filter { $0.absoluteString == "https://feeds.simplecast.com/6HKOhNgS" }.count
        XCTAssertEqual(hardForkCount, 1)
    }

    func test_extractFeedURLs_skipsInvalidURLs() throws {
        let data = try fixture("opml-apple-podcasts", ext: "xml")
        let urls = try StandardOPMLImporter().extractFeedURLs(from: data)

        // Empty xmlUrl="" and missing-attribute outlines must NOT appear
        XCTAssertFalse(urls.map(\.absoluteString).contains(""))
        XCTAssertEqual(urls.count, 5) // 6 leaf entries minus 1 dupe minus 2 invalid = 5
    }

    func test_extractFeedURLs_throwsOnMalformedXML() throws {
        let data = try fixture("opml-malformed", ext: "xml")
        XCTAssertThrowsError(try StandardOPMLImporter().extractFeedURLs(from: data)) { error in
            guard let opmlError = error as? OPMLImportError else {
                XCTFail("expected OPMLImportError, got \(error)")
                return
            }
            if case .malformed = opmlError { /* pass */ } else {
                XCTFail("expected .malformed, got \(opmlError)")
            }
        }
    }

    func test_importer_sanitizesUnescapedAmpersand_andSucceeds() throws {
        let data = try fixture("opml-unescaped-ampersand", ext: "opml")

        let importer = StandardOPMLImporter()
        let urls = try importer.extractFeedURLs(from: data)

        XCTAssertEqual(urls.count, 2)
        XCTAssertTrue(urls.contains(URL(string: "https://example.com/g-and-d.rss")!))
        XCTAssertTrue(urls.contains(URL(string: "https://example.com/hard-fork.rss")!))
    }

    func test_importer_throwsMalformedWithLineColumn_onUnrecoverableInput() throws {
        let data = try fixture("opml-unrecoverable", ext: "opml")

        let importer = StandardOPMLImporter()
        do {
            _ = try importer.extractFeedURLs(from: data)
            XCTFail("expected error")
        } catch let error as OPMLImportError {
            if case .malformed(let line, let column) = error {
                XCTAssertGreaterThan(line, 0)
                XCTAssertGreaterThan(column, 0)
            } else {
                XCTFail("expected .malformed(line:column:), got \(error)")
            }
        }
    }

    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
        return try Data(contentsOf: url)
    }
}
