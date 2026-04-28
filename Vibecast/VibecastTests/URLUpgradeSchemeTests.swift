import XCTest
@testable import Vibecast

final class URLUpgradeSchemeTests: XCTestCase {
    func test_upgradedToHTTPS_replacesHttpScheme() {
        let url = URL(string: "http://example.com/feed.rss")!
        XCTAssertEqual(url.upgradedToHTTPS().absoluteString, "https://example.com/feed.rss")
    }

    func test_upgradedToHTTPS_preservesHttpsURL() {
        let url = URL(string: "https://example.com/feed.rss")!
        XCTAssertEqual(url.upgradedToHTTPS().absoluteString, "https://example.com/feed.rss")
    }

    func test_upgradedToHTTPS_isCaseInsensitive() {
        let url = URL(string: "HTTP://example.com/feed.rss")!
        XCTAssertEqual(url.upgradedToHTTPS().scheme, "https")
    }

    func test_upgradedToHTTPS_preservesQueryAndFragment() {
        let url = URL(string: "http://example.com/feed?x=1#a")!
        let upgraded = url.upgradedToHTTPS()
        XCTAssertEqual(upgraded.scheme, "https")
        XCTAssertEqual(upgraded.query, "x=1")
        XCTAssertEqual(upgraded.fragment, "a")
    }

    func test_upgradedToHTTPS_leavesNonHttpUnchanged() {
        let url = URL(string: "file:///tmp/foo")!
        XCTAssertEqual(url.upgradedToHTTPS().absoluteString, "file:///tmp/foo")
    }
}
