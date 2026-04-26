# Vibecast MVP — Plan 3: Search, Subscribe & Real Feed Content

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user search the iTunes podcast directory and subscribe to a podcast in one tap; on subscribe, fetch and parse the RSS feed in the background and populate the subscriptions list with up to 50 real episodes per podcast.

**Architecture:** Three small `@MainActor` services behind protocols — `PodcastSearchService` (iTunes Search API), `FeedFetcher` (RSS download + `RSSParser`), and an `@Observable` `SubscriptionManager` that orchestrates them and is the only piece that touches `ModelContext`. UI is a `.sheet`-presented `AddPodcastSheet` containing a debounced search field and a list of `SearchResultRow`s.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Foundation `URLSession`, `XMLParser`, `JSONDecoder`, XCTest, iOS 17+.

---

## Scope

This is **Plan 3 of 4** in the MVP roadmap (the design spec was originally written for 3 plans; we split Plan 3 in two during writing).

- **Plan 1 (done)** — Foundation + core UI (subscriptions list, podcast detail, swipe/reorder).
- **Plan 2 (done)** — Audio engine, mini-player, full-screen player, persistent storage.
- **Plan 3 (this plan)** — iTunes search + Add Podcast sheet's search flow + RSS fetch + 50-episode storage.
- **Plan 4 (next)** — OPML import, pull-to-refresh, refresh-on-detail-open, sample data deprecation, Plan 2 polish followups.

**Deferred to Plan 4:**
- The "Import from File" button in `AddPodcastSheet` (the OPML path)
- `SubscriptionManager.refreshAll()` and `refresh(_ podcast: Podcast)`
- Removing `SampleData.seedIfNeeded` from `VibecastApp.init`
- Empty state hint ("No podcasts yet — tap +")
- Plan 2 review followups (`Logger` introduction, `import SwiftUI` placement in `PlayerManager`, Swift 6 `nonisolated(unsafe)` on `PlayerManagerKey`, `FullScreenPlayerView` volume binding, shared `format(_:)` helper)

After this plan ships: tapping `+` opens the Add Podcast sheet, the user can search, tap a result's `+` button, the row appears in their subscriptions list immediately with a "Loading episodes…" placeholder, and within 1–2 seconds the row's latest-episode widget populates with real data. Sample data still seeds on first launch (Plan 4 removes it).

---

## File Map

```
Vibecast/Vibecast/
├── Models/
│   └── Podcast.swift                    — MODIFY: add lastFetchedAt, iTunesCollectionId
├── Discovery/                           — NEW folder
│   ├── PodcastSearchService.swift       — protocol + PodcastSearchResult + iTunesSearchService
│   ├── FeedFetcher.swift                — protocol + URLSessionFeedFetcher + ParsedFeed/ParsedEpisode
│   ├── RSSParser.swift                  — XMLParser SAX delegate
│   └── SubscriptionManager.swift        — @Observable orchestrator
├── Views/
│   ├── SearchResultRow.swift            — NEW
│   ├── AddPodcastSheet.swift            — NEW
│   └── SubscriptionsListView.swift      — MODIFY: present AddPodcastSheet on "+"
└── VibecastApp.swift                    — MODIFY: instantiate Discovery services + inject

Vibecast/VibecastTests/
├── Fixtures/                            — NEW bundle resources (target membership: VibecastTests)
│   ├── itunes-search-hardfork.json
│   └── feed-hardfork.xml
├── MockURLProtocol.swift                — shared URL stub
├── PodcastSearchServiceTests.swift
├── RSSParserTests.swift
├── FeedFetcherTests.swift
└── SubscriptionManagerTests.swift
```

**Notes:**
- The `Discovery/` folder mirrors `Audio/` (Plan 2). Same Xcode-synced-folder pattern: any `.swift` file dropped in is auto-included; no manual `.pbxproj` edits.
- `SubscriptionManager` is the only file that imports `SwiftData`. Everything else is pure I/O + parsing — testable without a `ModelContainer`.
- `RSSParser` is split out from `FeedFetcher` because the parser is a synchronous data-transform; the fetcher does network I/O. Same separation as Plan 2's `AudioEngine` protocol vs. `AVPlayerAudioEngine`.

---

## Task 1: Extend the `Podcast` Model

**Files:**
- Modify: `Vibecast/Vibecast/Models/Podcast.swift`

Add `lastFetchedAt: Date?` and `iTunesCollectionId: Int?` to support the upcoming refresh debounce (Plan 4) and de-duplication (Plan 3 + Plan 4). Both are optional so existing rows in the on-disk SwiftData store get `nil` and SwiftData performs lightweight migration automatically.

- [ ] **Step 1: Replace the file's contents**

Replace `Vibecast/Vibecast/Models/Podcast.swift` with:

```swift
import SwiftData
import Foundation

@Model
final class Podcast {
    var title: String
    var author: String
    var artworkURL: String?
    var feedURL: String
    var sortPosition: Int
    var lastFetchedAt: Date?
    var iTunesCollectionId: Int?
    @Relationship(deleteRule: .cascade) var episodes: [Episode]

    init(
        title: String,
        author: String,
        artworkURL: String?,
        feedURL: String,
        sortPosition: Int = 0,
        lastFetchedAt: Date? = nil,
        iTunesCollectionId: Int? = nil
    ) {
        self.title = title
        self.author = author
        self.artworkURL = artworkURL
        self.feedURL = feedURL
        self.sortPosition = sortPosition
        self.lastFetchedAt = lastFetchedAt
        self.iTunesCollectionId = iTunesCollectionId
        self.episodes = []
    }
}
```

- [ ] **Step 2: Build to confirm no callers broke**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds. The new params have defaults, so all existing call sites (`SampleData.insertSampleData` and the model tests) continue to compile unchanged.

- [ ] **Step 3: Run the existing test suite**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 33 tests pass (Plan 1+2 baseline). No regressions.

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Models/Podcast.swift
git commit -m "feat: add lastFetchedAt and iTunesCollectionId to Podcast model"
```

---

## Task 2: `PodcastSearchService` + `iTunesSearchService` + `MockURLProtocol`

**Files:**
- Create: `Vibecast/Vibecast/Discovery/PodcastSearchService.swift`
- Create: `Vibecast/VibecastTests/MockURLProtocol.swift`
- Create: `Vibecast/VibecastTests/Fixtures/itunes-search-hardfork.json`
- Create: `Vibecast/VibecastTests/PodcastSearchServiceTests.swift`

`MockURLProtocol` is the shared URL-stub helper used by Tasks 2 and 4. Introduced here with its first consumer (the search service tests) so each piece earns its place via a passing test.

- [ ] **Step 1: Create the `Discovery` folder via Xcode**

In Xcode's file navigator, right-click the `Vibecast` group → New Group → name it `Discovery`. This creates `Vibecast/Vibecast/Discovery/` on disk as a synced folder.

- [ ] **Step 2: Create the JSON fixture**

Create `Vibecast/VibecastTests/Fixtures/itunes-search-hardfork.json` with this content (a trimmed real iTunes Search response):

```json
{
  "resultCount": 2,
  "results": [
    {
      "collectionId": 1528594034,
      "collectionName": "Hard Fork",
      "artistName": "The New York Times",
      "artworkUrl600": "https://example.com/hardfork600.jpg",
      "artworkUrl100": "https://example.com/hardfork100.jpg",
      "feedUrl": "https://feeds.simplecast.com/l2i9YnTd"
    },
    {
      "collectionId": 1184361729,
      "collectionName": "Acquired",
      "artistName": "Ben Gilbert and David Rosenthal",
      "artworkUrl600": "https://example.com/acquired600.jpg",
      "feedUrl": "https://feeds.transistor.fm/acquired"
    }
  ]
}
```

In Xcode: drag the `Fixtures` folder into the `VibecastTests` target (target membership: VibecastTests only). Confirm the JSON file's "Target Membership" panel shows `VibecastTests` checked.

- [ ] **Step 3: Create `MockURLProtocol`**

Create `Vibecast/VibecastTests/MockURLProtocol.swift`:

```swift
import Foundation

/// Stubs out network responses for tests. Register canned (Data, HTTPURLResponse) pairs by URL.
final class MockURLProtocol: URLProtocol {
    typealias Stub = (data: Data, response: HTTPURLResponse)
    nonisolated(unsafe) static var stubs: [URL: Stub] = [:]
    nonisolated(unsafe) static var error: Error?

    static func register(url: URL, data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        stubs[url] = (data, response)
    }

    static func reset() {
        stubs.removeAll()
        error = nil
    }

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = MockURLProtocol.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let url = request.url, let stub = MockURLProtocol.stubs[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
```

- [ ] **Step 4: Write the failing tests**

Create `Vibecast/VibecastTests/PodcastSearchServiceTests.swift`:

```swift
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
```

- [ ] **Step 5: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: compile error — `iTunesSearchService` and `PodcastSearchResult` not defined.

- [ ] **Step 6: Implement `PodcastSearchService.swift`**

Create `Vibecast/Vibecast/Discovery/PodcastSearchService.swift`:

```swift
import Foundation

@MainActor
protocol PodcastSearchService {
    func search(_ query: String) async throws -> [PodcastSearchResult]
}

struct PodcastSearchResult: Identifiable, Hashable, Sendable {
    let id: Int                // iTunes collectionId
    let title: String
    let author: String
    let artworkURL: URL?
    let feedURL: URL
}

@MainActor
final class iTunesSearchService: PodcastSearchService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(_ query: String) async throws -> [PodcastSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "limit", value: "25"),
        ]
        guard let url = components.url else { return [] }

        let (data, _) = try await session.data(from: url)
        let envelope = try JSONDecoder().decode(ITunesSearchEnvelope.self, from: data)
        return envelope.results.compactMap { raw in
            guard let feedURLString = raw.feedUrl,
                  let feedURL = URL(string: feedURLString) else { return nil }
            let artworkURL = (raw.artworkUrl600 ?? raw.artworkUrl100).flatMap(URL.init(string:))
            return PodcastSearchResult(
                id: raw.collectionId,
                title: raw.collectionName ?? "",
                author: raw.artistName ?? "",
                artworkURL: artworkURL,
                feedURL: feedURL
            )
        }
    }

    private struct ITunesSearchEnvelope: Decodable {
        let results: [RawResult]
    }

    private struct RawResult: Decodable {
        let collectionId: Int
        let collectionName: String?
        let artistName: String?
        let artworkUrl600: String?
        let artworkUrl100: String?
        let feedUrl: String?
    }
}
```

- [ ] **Step 7: Run tests — verify all 3 pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 36 tests pass (33 baseline + 3 new). No failures.

- [ ] **Step 8: Commit**

```bash
git add Vibecast/Vibecast/Discovery/PodcastSearchService.swift Vibecast/VibecastTests/MockURLProtocol.swift Vibecast/VibecastTests/Fixtures/itunes-search-hardfork.json Vibecast/VibecastTests/PodcastSearchServiceTests.swift
git commit -m "feat: add PodcastSearchService backed by iTunes Search API"
```

---

## Task 3: `RSSParser`

**Files:**
- Create: `Vibecast/Vibecast/Discovery/RSSParser.swift`
- Create: `Vibecast/VibecastTests/Fixtures/feed-hardfork.xml`
- Create: `Vibecast/VibecastTests/RSSParserTests.swift`

A SAX-style `XMLParserDelegate` that walks RSS 2.0 + iTunes namespace fields. Capped at 50 episodes via post-parse sort+truncate. Synchronous, thread-safe.

- [ ] **Step 1: Create the RSS fixture**

Create `Vibecast/VibecastTests/Fixtures/feed-hardfork.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Hard Fork</title>
    <itunes:author>The New York Times</itunes:author>
    <itunes:image href="https://example.com/hardfork-channel.jpg"/>
    <item>
      <title>The Future of AI Regulation</title>
      <pubDate>Wed, 22 Apr 2026 09:00:00 +0000</pubDate>
      <description><![CDATA[New rules could reshape how companies deploy LLMs across the EU.]]></description>
      <itunes:duration>1:02:30</itunes:duration>
      <itunes:explicit>no</itunes:explicit>
      <enclosure url="https://example.com/episode-3.mp3" length="123456" type="audio/mpeg"/>
    </item>
    <item>
      <title>Inside the Semiconductor Supply Chain</title>
      <pubDate>Wed, 15 Apr 2026 09:00:00 +0000</pubDate>
      <description>From Taiwan to Texas.</description>
      <itunes:duration>2700</itunes:duration>
      <itunes:explicit>yes</itunes:explicit>
      <enclosure url="https://example.com/episode-2.mp3" length="234567" type="audio/mpeg"/>
    </item>
    <item>
      <title>Episode With No Duration</title>
      <pubDate>Wed, 08 Apr 2026 09:00:00 +0000</pubDate>
      <description>Test fallback.</description>
      <enclosure url="https://example.com/episode-1.mp3" length="345678" type="audio/mpeg"/>
    </item>
  </channel>
</rss>
```

Add target membership: `VibecastTests`.

- [ ] **Step 2: Write the failing tests**

Create `Vibecast/VibecastTests/RSSParserTests.swift`:

```swift
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

    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
        return try Data(contentsOf: url)
    }
}
```

- [ ] **Step 3: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: compile error — `RSSParser` not defined.

- [ ] **Step 4: Implement `RSSParser.swift`**

Create `Vibecast/Vibecast/Discovery/RSSParser.swift`:

```swift
import Foundation

struct ParsedFeed {
    let podcastTitle: String?
    let podcastAuthor: String?
    let artworkURL: URL?
    let episodes: [ParsedEpisode]
}

struct ParsedEpisode {
    let title: String
    let publishDate: Date
    let descriptionText: String
    let durationSeconds: Int
    let audioURL: String
    let isExplicit: Bool
}

enum RSSParseError: Error {
    case malformed
}

final class RSSParser: NSObject, XMLParserDelegate {
    private static let episodeCap = 50

    private var inItem = false
    private var currentElement = ""
    private var currentText = ""

    private var podcastTitle: String?
    private var podcastAuthor: String?
    private var artworkHref: String?
    private var sawChannelTitle = false

    private struct ItemBuffer {
        var title: String = ""
        var pubDateString: String = ""
        var description: String = ""
        var durationString: String = ""
        var audioURL: String = ""
        var explicit: Bool = false
    }
    private var item = ItemBuffer()
    private var items: [ParsedEpisode] = []

    private static let pubDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parse(_ data: Data) throws -> ParsedFeed {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        guard xmlParser.parse() else { throw RSSParseError.malformed }

        let sorted = items.sorted { $0.publishDate > $1.publishDate }
        let capped = Array(sorted.prefix(Self.episodeCap))
        return ParsedFeed(
            podcastTitle: podcastTitle,
            podcastAuthor: podcastAuthor,
            artworkURL: artworkHref.flatMap(URL.init(string:)),
            episodes: capped
        )
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "item" {
            inItem = true
            item = ItemBuffer()
        } else if elementName == "itunes:image", !inItem {
            artworkHref = attributeDict["href"]
        } else if elementName == "enclosure", inItem {
            item.audioURL = attributeDict["url"] ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            currentText += s
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if inItem {
            switch elementName {
            case "title": item.title = text
            case "pubDate": item.pubDateString = text
            case "description", "itunes:summary":
                if item.description.isEmpty { item.description = text }
            case "itunes:duration": item.durationString = text
            case "itunes:explicit":
                item.explicit = (text.lowercased() == "yes" || text.lowercased() == "true")
            case "item":
                inItem = false
                if let parsed = finalizeItem(item) { items.append(parsed) }
            default: break
            }
        } else {
            switch elementName {
            case "title":
                if !sawChannelTitle {
                    podcastTitle = text
                    sawChannelTitle = true
                }
            case "itunes:author":
                podcastAuthor = text
            case "author":
                if podcastAuthor == nil { podcastAuthor = text }
            default: break
            }
        }

        currentText = ""
        currentElement = ""
    }

    private func finalizeItem(_ buf: ItemBuffer) -> ParsedEpisode? {
        let date = Self.pubDateFormatter.date(from: buf.pubDateString) ?? .distantPast
        return ParsedEpisode(
            title: buf.title,
            publishDate: date,
            descriptionText: buf.description,
            durationSeconds: Self.parseDuration(buf.durationString),
            audioURL: buf.audioURL,
            isExplicit: buf.explicit
        )
    }

    static func parseDuration(_ raw: String) -> Int {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let parts = trimmed.split(separator: ":").map(String.init)
        if parts.count == 1 {
            return Int(parts[0]) ?? 0
        }
        let nums = parts.compactMap(Int.init)
        guard nums.count == parts.count else { return 0 }
        switch nums.count {
        case 2: return nums[0] * 60 + nums[1]
        case 3: return nums[0] * 3600 + nums[1] * 60 + nums[2]
        default: return 0
        }
    }
}
```

- [ ] **Step 5: Run tests — verify all 8 pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 44 tests pass (36 + 8 new). No failures.

- [ ] **Step 6: Commit**

```bash
git add Vibecast/Vibecast/Discovery/RSSParser.swift Vibecast/VibecastTests/Fixtures/feed-hardfork.xml Vibecast/VibecastTests/RSSParserTests.swift
git commit -m "feat: add RSSParser with iTunes-namespace support and 50-episode cap"
```

---

## Task 4: `FeedFetcher`

**Files:**
- Create: `Vibecast/Vibecast/Discovery/FeedFetcher.swift`
- Create: `Vibecast/VibecastTests/FeedFetcherTests.swift`

Thin wrapper that downloads RSS bytes and routes them through `RSSParser`. Reuses `MockURLProtocol` for tests.

- [ ] **Step 1: Write the failing tests**

Create `Vibecast/VibecastTests/FeedFetcherTests.swift`:

```swift
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

    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
        return try Data(contentsOf: url)
    }
}
```

- [ ] **Step 2: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: compile error — `URLSessionFeedFetcher` not defined.

- [ ] **Step 3: Implement `FeedFetcher.swift`**

Create `Vibecast/Vibecast/Discovery/FeedFetcher.swift`:

```swift
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
```

- [ ] **Step 4: Run tests — verify both pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 46 tests pass (44 + 2 new).

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Discovery/FeedFetcher.swift Vibecast/VibecastTests/FeedFetcherTests.swift
git commit -m "feat: add URLSessionFeedFetcher routing bytes to RSSParser"
```

---

## Task 5: `SubscriptionManager` (subscribe-only)

**Files:**
- Create: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`
- Create: `Vibecast/VibecastTests/SubscriptionManagerTests.swift`

The orchestrator. Owns the `ModelContext`, takes a `PodcastSearchResult`, inserts a `Podcast` row immediately, kicks off a background `Task` to fetch and parse RSS, and inserts `Episode` rows when the fetch completes. Tracks in-flight subscribe operations so the UI can show spinners.

`importOPML`, `refreshAll`, and `refresh` are deferred to Plan 4 — only `subscribe(to: PodcastSearchResult)` and `isSubscribed(feedURL:)` ship now.

- [ ] **Step 1: Write the failing tests**

Create `Vibecast/VibecastTests/SubscriptionManagerTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class SubscriptionManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var searcher: MockSearchService!
    var fetcher: MockFeedFetcher!
    var manager: SubscriptionManager!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)
        searcher = MockSearchService()
        fetcher = MockFeedFetcher()
        manager = SubscriptionManager(searcher: searcher, fetcher: fetcher, modelContext: context)
    }

    private func makeResult() -> PodcastSearchResult {
        PodcastSearchResult(
            id: 42,
            title: "Hard Fork",
            author: "NYT",
            artworkURL: URL(string: "https://x/a.jpg"),
            feedURL: URL(string: "https://feeds.example.com/hardfork")!
        )
    }

    private func sampleFeed() -> ParsedFeed {
        ParsedFeed(
            podcastTitle: "Hard Fork",
            podcastAuthor: "NYT",
            artworkURL: nil,
            episodes: [
                ParsedEpisode(title: "E1", publishDate: .now, descriptionText: "d1", durationSeconds: 1800, audioURL: "https://x/1.mp3", isExplicit: false),
                ParsedEpisode(title: "E2", publishDate: .now.addingTimeInterval(-86400), descriptionText: "d2", durationSeconds: 1500, audioURL: "https://x/2.mp3", isExplicit: false),
            ]
        )
    }

    func test_subscribe_insertsPodcastRowImmediately() async {
        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)
        XCTAssertEqual(podcasts[0].title, "Hard Fork")
        XCTAssertEqual(podcasts[0].iTunesCollectionId, 42)
    }

    func test_subscribe_populatesEpisodesAfterFetch() async {
        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts[0].episodes.count, 2)
        XCTAssertNotNil(podcasts[0].lastFetchedAt)
    }

    func test_subscribe_appendsAtBottomOfSortOrder() async {
        let existing = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: "https://a/", sortPosition: 0)
        context.insert(existing)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)]))
        XCTAssertEqual(podcasts.count, 2)
        XCTAssertEqual(podcasts[1].title, "Hard Fork")
        XCTAssertEqual(podcasts[1].sortPosition, 1)
    }

    func test_subscribe_dedupesByFeedURL() async {
        let existing = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: "https://feeds.example.com/hardfork")
        context.insert(existing)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1) // no duplicate
        XCTAssertEqual(podcasts[0].title, "A") // existing record left alone
    }

    func test_isSubscribed_truthyWhenFeedURLMatches() async {
        let existing = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: "https://feeds.example.com/hardfork")
        context.insert(existing)
        try! context.save()

        XCTAssertTrue(manager.isSubscribed(feedURL: URL(string: "https://feeds.example.com/hardfork")!))
        XCTAssertFalse(manager.isSubscribed(feedURL: URL(string: "https://feeds.example.com/other")!))
    }

    func test_subscribe_clearsInFlightOnSuccess() async {
        fetcher.feed = sampleFeed()
        await manager.subscribe(to: makeResult())
        XCTAssertTrue(manager.inFlightSubscriptions.isEmpty)
    }

    func test_subscribe_clearsInFlightOnFetchFailure() async {
        fetcher.error = URLError(.notConnectedToInternet)
        await manager.subscribe(to: makeResult())

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)            // row still inserted
        XCTAssertTrue(podcasts[0].episodes.isEmpty)  // no episodes
        XCTAssertNil(podcasts[0].lastFetchedAt)      // no successful fetch timestamp
        XCTAssertTrue(manager.inFlightSubscriptions.isEmpty)
    }
}

// MARK: - Test Doubles

@MainActor
final class MockSearchService: PodcastSearchService {
    var results: [PodcastSearchResult] = []
    var error: Error?

    func search(_ query: String) async throws -> [PodcastSearchResult] {
        if let error { throw error }
        return results
    }
}

@MainActor
final class MockFeedFetcher: FeedFetcher {
    var feed: ParsedFeed?
    var error: Error?

    func fetch(_ feedURL: URL) async throws -> ParsedFeed {
        if let error { throw error }
        return feed ?? ParsedFeed(podcastTitle: nil, podcastAuthor: nil, artworkURL: nil, episodes: [])
    }
}
```

- [ ] **Step 2: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: compile error — `SubscriptionManager` not defined.

- [ ] **Step 3: Implement `SubscriptionManager.swift`**

Create `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class SubscriptionManager {
    private(set) var inFlightSubscriptions: Set<URL> = []

    @ObservationIgnored private let searcher: PodcastSearchService
    @ObservationIgnored private let fetcher: FeedFetcher
    @ObservationIgnored private let modelContext: ModelContext

    init(searcher: PodcastSearchService, fetcher: FeedFetcher, modelContext: ModelContext) {
        self.searcher = searcher
        self.fetcher = fetcher
        self.modelContext = modelContext
    }

    func search(_ query: String) async throws -> [PodcastSearchResult] {
        try await searcher.search(query)
    }

    func isSubscribed(feedURL: URL) -> Bool {
        let target = feedURL.absoluteString
        let descriptor = FetchDescriptor<Podcast>(predicate: #Predicate { $0.feedURL == target })
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        return count > 0
    }

    func subscribe(to result: PodcastSearchResult) async {
        guard !isSubscribed(feedURL: result.feedURL) else { return }

        inFlightSubscriptions.insert(result.feedURL)
        defer { inFlightSubscriptions.remove(result.feedURL) }

        let nextSortPosition = nextAvailableSortPosition()
        let podcast = Podcast(
            title: result.title,
            author: result.author,
            artworkURL: result.artworkURL?.absoluteString,
            feedURL: result.feedURL.absoluteString,
            sortPosition: nextSortPosition,
            iTunesCollectionId: result.id
        )
        modelContext.insert(podcast)
        try? modelContext.save()

        do {
            let feed = try await fetcher.fetch(result.feedURL)
            for parsed in feed.episodes {
                let episode = Episode(
                    podcast: podcast,
                    title: parsed.title,
                    publishDate: parsed.publishDate,
                    descriptionText: parsed.descriptionText,
                    durationSeconds: parsed.durationSeconds,
                    audioURL: parsed.audioURL
                )
                episode.isExplicit = parsed.isExplicit
                modelContext.insert(episode)
                podcast.episodes.append(episode)
            }
            podcast.lastFetchedAt = .now
            try? modelContext.save()
        } catch {
            // Leave podcast row in place with no episodes; user can pull-to-refresh in Plan 4.
        }
    }

    private func nextAvailableSortPosition() -> Int {
        let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition, order: .reverse)])
        let last = (try? modelContext.fetch(descriptor))?.first
        return (last?.sortPosition ?? -1) + 1
    }
}
```

- [ ] **Step 4: Run tests — verify all 7 pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 53 tests pass (46 + 7 new).

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift Vibecast/VibecastTests/SubscriptionManagerTests.swift
git commit -m "feat: add SubscriptionManager with subscribe(to:) for search results"
```

---

## Task 6: `SearchResultRow` View

**Files:**
- Create: `Vibecast/Vibecast/Views/SearchResultRow.swift`

A self-contained row showing artwork, title, author, and a state-aware subscribe button. The button has three states: idle (`+`), in-flight (`ProgressView`), already-subscribed (muted ✓, non-tappable).

- [ ] **Step 1: Create `SearchResultRow.swift`**

Create `Vibecast/Vibecast/Views/SearchResultRow.swift`:

```swift
import SwiftUI

struct SearchResultRow: View {
    let result: PodcastSearchResult
    let isSubscribed: Bool
    let isInFlight: Bool
    let onTapSubscribe: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                Text(result.author)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            subscribeButton
        }
        .padding(.vertical, 4)
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 52, height: 52)
            .overlay {
                if let url = result.artworkURL {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "mic.fill").foregroundStyle(.tertiary)
                }
            }
    }

    @ViewBuilder
    private var subscribeButton: some View {
        if isSubscribed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
                .frame(width: 36, height: 36)
        } else if isInFlight {
            ProgressView()
                .frame(width: 36, height: 36)
        } else {
            Button(action: onTapSubscribe) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.accent)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    let example = PodcastSearchResult(
        id: 1,
        title: "Hard Fork",
        author: "The New York Times",
        artworkURL: nil,
        feedURL: URL(string: "https://x/")!
    )
    return List {
        SearchResultRow(result: example, isSubscribed: false, isInFlight: false, onTapSubscribe: {})
        SearchResultRow(result: example, isSubscribed: false, isInFlight: true, onTapSubscribe: {})
        SearchResultRow(result: example, isSubscribed: true, isInFlight: false, onTapSubscribe: {})
    }
}
```

- [ ] **Step 2: Build to confirm**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds. Stale SourceKit canvas errors should be ignored.

- [ ] **Step 3: Commit**

```bash
git add Vibecast/Vibecast/Views/SearchResultRow.swift
git commit -m "feat: add SearchResultRow with idle/in-flight/subscribed states"
```

---

## Task 7: `AddPodcastSheet` View

**Files:**
- Create: `Vibecast/Vibecast/Views/AddPodcastSheet.swift`

The sheet itself: a debounced search field, results list, and the various states from the spec (empty / loading / error / results / no-results). Takes a `SubscriptionManager` via parameter; OPML "Import from File" is deferred to Plan 4.

- [ ] **Step 1: Create `AddPodcastSheet.swift`**

Create `Vibecast/Vibecast/Views/AddPodcastSheet.swift`:

```swift
import SwiftUI

struct AddPodcastSheet: View {
    let manager: SubscriptionManager

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var phase: Phase = .idle
    @State private var lastSubmittedQuery = ""

    enum Phase { case idle, searching, results, empty, error }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add Podcast")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search podcasts")
                .task(id: query) {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    await runSearch()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            ContentUnavailableView(
                "Search the iTunes podcast directory",
                systemImage: "magnifyingglass",
                description: Text("Search by title, author, or topic.")
            )
        case .searching:
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView.search(text: lastSubmittedQuery)
        case .error:
            ContentUnavailableView(
                "Couldn't reach iTunes",
                systemImage: "wifi.exclamationmark",
                description: Text("Check your connection and try again.")
            )
        case .results:
            List(results) { result in
                SearchResultRow(
                    result: result,
                    isSubscribed: manager.isSubscribed(feedURL: result.feedURL),
                    isInFlight: manager.inFlightSubscriptions.contains(result.feedURL),
                    onTapSubscribe: {
                        Task { await manager.subscribe(to: result) }
                    }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
            }
            .listStyle(.plain)
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phase = .idle
            results = []
            return
        }

        phase = .searching
        lastSubmittedQuery = trimmed
        do {
            let fetched = try await manager.search(trimmed)
            results = fetched
            phase = fetched.isEmpty ? .empty : .results
        } catch {
            phase = .error
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Vibecast/Vibecast/Views/AddPodcastSheet.swift
git commit -m "feat: add AddPodcastSheet with debounced search and result states"
```

---

## Task 8: Wire Up — App + SubscriptionsListView

**Files:**
- Modify: `Vibecast/Vibecast/VibecastApp.swift`
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`

Construct `SubscriptionManager` at app startup, inject via the same `EnvironmentKey` pattern Plan 2 used for `PlayerManager`, and wire the existing `+` toolbar button to present `AddPodcastSheet`.

- [ ] **Step 1: Add an environment key for `SubscriptionManager`**

Append the following to the end of `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`:

```swift

import SwiftUI

private struct SubscriptionManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: SubscriptionManager? = nil
}

extension EnvironmentValues {
    var subscriptionManager: SubscriptionManager? {
        get { self[SubscriptionManagerKey.self] }
        set { self[SubscriptionManagerKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Replace `Vibecast/Vibecast/VibecastApp.swift` body**

Replace the entire file with:

```swift
import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer
    @State private var playerManager: PlayerManager
    @State private var subscriptionManager: SubscriptionManager

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Podcast.self, Episode.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        container = c

        let players: PlayerManager
        let subs: SubscriptionManager
        (players, subs) = MainActor.assumeIsolated {
            SampleData.seedIfNeeded(into: ModelContext(c))
            let p = PlayerManager(engine: AVPlayerAudioEngine(), modelContext: ModelContext(c))
            let s = SubscriptionManager(
                searcher: iTunesSearchService(),
                fetcher: URLSessionFeedFetcher(),
                modelContext: ModelContext(c)
            )
            return (p, s)
        }
        _playerManager = State(initialValue: players)
        _subscriptionManager = State(initialValue: subs)
    }

    var body: some Scene {
        WindowGroup {
            SubscriptionsListView()
                .environment(\.playerManager, playerManager)
                .environment(\.subscriptionManager, subscriptionManager)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                playerManager.saveCurrentState()
            }
        }
    }
}
```

- [ ] **Step 3: Update `SubscriptionsListView` to present the sheet**

In `Vibecast/Vibecast/Views/SubscriptionsListView.swift`, find the existing `@State private var showAddPodcast = false` declaration (it already exists). Add an `@Environment` near the top of the struct:

```swift
    @Environment(\.subscriptionManager) private var subscriptionManager
```

Then attach a `.sheet(isPresented:)` modifier inside the `NavigationStack`, immediately above the `.safeAreaInset(edge: .bottom)` modifier:

```swift
            .sheet(isPresented: $showAddPodcast) {
                if let subscriptionManager {
                    AddPodcastSheet(manager: subscriptionManager)
                }
            }
```

(The `+` toolbar button already toggles `showAddPodcast` from Plan 1; no changes there.)

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds.

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 53 tests pass. No regressions in Plan 1+2 tests.

- [ ] **Step 6: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift Vibecast/Vibecast/VibecastApp.swift Vibecast/Vibecast/Views/SubscriptionsListView.swift
git commit -m "feat: inject SubscriptionManager and wire AddPodcastSheet to + button"
```

---

## Task 9: End-to-End Verification

**Files:**
- None modified (manual verification + final commit if issues found).

Confirm Plan 3 flows end-to-end against a real iTunes Search response and a real RSS feed.

- [ ] **Step 1: Build + launch on simulator**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Then ⌘R in Xcode (iPhone 17 Pro simulator).

- [ ] **Step 2: Manual simulator verification**

| Step | Action | Expected |
|---|---|---|
| 1 | Open the app | Five sample podcasts visible (sample data still seeds in Plan 3) |
| 2 | Tap the `+` toolbar button | `AddPodcastSheet` slides up with search bar, idle empty state |
| 3 | Type "hard fork" | After ~300ms, search runs; results list shows Hard Fork and similar matches with `+` buttons |
| 4 | Tap `+` on Hard Fork | Button changes to spinner; row appears at the bottom of the subscriptions list immediately (sheet still open) |
| 5 | Wait 1–3s | Spinner clears; row's latest-episode widget populates with real episode title and date |
| 6 | Dismiss sheet | Subscriptions list now shows the new podcast at the bottom |
| 7 | Tap the new Hard Fork row's body | Detail sheet opens; real episode list with up to 50 entries |
| 8 | Tap `+` again, search "hard fork" | The Hard Fork row in results now shows muted ✓ instead of `+` (already-subscribed indicator) |
| 9 | Search a query that returns nothing ("zxcvbnm12345") | "No results found" empty state |
| 10 | Disable simulator network (Settings → Wi-Fi off, or Network Link Conditioner) and search | Inline error state appears |
| 11 | Re-enable network, retry | Results return |
| 12 | Quit + relaunch | New podcast persists; episodes persist |

- [ ] **Step 3: If any step fails, fix and recommit**

Investigate and patch in-place. Use the `superpowers:systematic-debugging` skill if a bug is non-trivial. Commits should follow the same pattern as Plan 2 fixes (`fix: ...` with a descriptive body).

- [ ] **Step 4: Final all-tests run**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 53 tests pass.

- [ ] **Step 5: Push and merge**

```bash
git push -u origin feature/plan-3-discovery
```

Open a PR or fast-forward merge to main per the convention used at the end of Plan 2.

---

## Self-review checklist (filled in by plan-author, not the implementer)

- **Spec coverage:** Search ✓, Subscribe ✓, RSS fetch + 50-cap ✓. OPML, refresh, sample data deprecation, polish are explicitly deferred to Plan 4.
- **Type consistency:** `PodcastSearchResult` defined in Task 2, used in Tasks 5, 6, 7, 8. `ParsedFeed`/`ParsedEpisode` defined in Task 3, used in Tasks 4, 5. `SubscriptionManager` defined in Task 5, used in Tasks 7, 8. `MockURLProtocol` defined in Task 2, reused in Task 4. All consistent.
- **No placeholders:** every step has either runnable shell, exact code, or an exact action. No "add error handling", "TBD", or "similar to Task N".
- **Test count progression:** 33 → 36 (Task 2) → 44 (Task 3) → 46 (Task 4) → 53 (Task 5). Tasks 6–9 don't add unit tests (UI + integration). Final = 53.
- **Plan size estimate:** ~10–14 commits including any Task-9 fixes. In line with Plan 2's ~19-commit shipped scope.
