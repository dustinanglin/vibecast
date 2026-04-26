# Vibecast MVP — Plan 3: Discovery & Real Feed Content

**One-sentence pitch:** Replace the seeded sample data with real podcasts: an Add Podcast sheet that searches iTunes, an OPML importer for bulk migration from Apple Podcasts, and a background RSS fetcher that populates each podcast with up to 50 recent episodes.

**Plan position:** 3 of 3 in the MVP roadmap. Plan 1 shipped foundation + core UI; Plan 2 shipped the audio engine + player UI. Plan 3 closes the loop by giving the user a way to add their own subscriptions and replacing the demo content with real data. The overarching MVP design is at `docs/superpowers/specs/2026-04-19-vibecast-mvp-design.md`.

---

## Goals

- A user can search for a podcast by title, author, or topic and subscribe in one tap.
- A user can bulk-import their existing subscriptions via an OPML file (the Apple Podcasts export format).
- Subscribed podcasts populate with real episodes (title, duration, audio URL, etc.) without the user having to wait on a blocking spinner.
- Pull-to-refresh on the subscriptions list re-fetches every podcast's RSS feed.
- The synthetic `SampleData` seed is removed from app launch; first-launch UI is an empty state inviting the user to add a podcast.

## Non-goals

- Cloud sync (out of scope for MVP per the original spec)
- Offline downloads (Future Milestone)
- Notifications when new episodes drop (Future Milestone)
- Importing playback state from Apple Podcasts (the spec's OPML import explicitly excludes listen history)
- A separate "podcast detail before subscribing" view — the search row provides enough context (decision in original spec)
- Background refresh while the app is closed — pull-to-refresh and detail-open-refresh only
- Dynamic refresh of iTunes metadata after subscribe (artwork, title, etc. are captured at subscribe time)

---

## Architecture

Plan 3 mirrors Plan 2's small-service pattern: each `@MainActor` service owns one responsibility behind a protocol so it can be mocked in tests. `SubscriptionManager` is the only piece that touches `ModelContext`; the others are pure I/O + parsing.

```
SubscriptionsListView ──taps "+"──► AddPodcastSheet
                                      │
                                      ├─ TextField (debounced 300ms) ──► PodcastSearchService.search
                                      │                                      │
                                      │                                      └─► [PodcastSearchResult]
                                      │                                          │
                                      │  user taps "+" on a result ──────► SubscriptionManager.subscribe(to: result)
                                      │                                          │
                                      │                                          ├─► ModelContext.insert(Podcast) (immediate)
                                      │                                          │
                                      │                                          └─► Task: FeedFetcher.fetch(feedURL)
                                      │                                                            │
                                      │                                                            └─► RSSParser → ParsedFeed → ModelContext.insert(Episode×N)
                                      │
                                      └─ "Import from File" ──────────────► OPMLImporter.extractFeedURLs(data)
                                                                                  │
                                                                                  └─► SubscriptionManager.importOPML(data)
                                                                                          │
                                                                                          └─► iterates: subscribe(to: feedURL)
```

### Files

```
Vibecast/
├── Models/
│   └── Podcast.swift                    — MODIFY: add lastFetchedAt: Date?, iTunesCollectionId: Int?
├── Discovery/                           — NEW
│   ├── PodcastSearchService.swift       — protocol + iTunesSearchService
│   ├── FeedFetcher.swift                — protocol + URLSessionFeedFetcher
│   ├── RSSParser.swift                  — XMLParser-based SAX delegate
│   ├── OPMLImporter.swift               — XMLParser-based, extracts <outline xmlUrl="…">
│   └── SubscriptionManager.swift        — orchestrator; @Observable @MainActor
├── Views/
│   ├── AddPodcastSheet.swift            — search field + results + OPML button
│   ├── SearchResultRow.swift            — artwork + title/author + subscribe button
│   └── SubscriptionsListView.swift      — MODIFY: present AddPodcastSheet on "+"; add .refreshable
├── VibecastApp.swift                    — MODIFY: instantiate services, inject; remove SampleData.seedIfNeeded
└── Preview Content/
    └── SampleData.swift                 — KEEP (in-memory container for previews + tests)

VibecastTests/
├── Fixtures/                            — NEW bundle resources
│   ├── itunes-search-hardfork.json
│   ├── feed-hardfork.xml
│   ├── feed-malformed.xml
│   ├── feed-no-episodes.xml
│   ├── opml-apple-podcasts-export.xml
│   └── opml-malformed.xml
├── RSSParserTests.swift                 — NEW
├── OPMLImporterTests.swift              — NEW
├── PodcastSearchServiceTests.swift      — NEW
├── FeedFetcherTests.swift               — NEW
├── SubscriptionManagerTests.swift       — NEW
└── MockURLProtocol.swift                — NEW shared test helper
```

---

## Data Model Changes

```swift
@Model
final class Podcast {
    var title: String
    var author: String
    var artworkURL: String?
    var feedURL: String
    var sortPosition: Int
    var lastFetchedAt: Date?            // NEW: nil until first successful fetch; powers refresh debounce
    var iTunesCollectionId: Int?        // NEW: optional, populated when subscribed via search; absent for OPML imports
    @Relationship(deleteRule: .cascade) var episodes: [Episode]
    // init updated to take the two new fields with default nil
}
```

`Episode` is unchanged from Plan 1.

---

## Service Contracts

### `PodcastSearchService`

```swift
@MainActor
protocol PodcastSearchService {
    func search(_ query: String) async throws -> [PodcastSearchResult]
}

struct PodcastSearchResult: Identifiable, Hashable {
    let id: Int                // iTunes collectionId
    let title: String
    let author: String
    let artworkURL: URL?
    let feedURL: URL
}
```

Implementation `iTunesSearchService` issues `GET https://itunes.apple.com/search?media=podcast&term=<urlEncodedQuery>&limit=25` and decodes the wrapper's `results` array. Empty `query` short-circuits to `[]` without a network call. The artwork URL prefers the 600px variant (`artworkUrl600`) over `artworkUrl100`.

### `FeedFetcher` & `RSSParser`

```swift
@MainActor
protocol FeedFetcher {
    func fetch(_ feedURL: URL) async throws -> ParsedFeed
}

struct ParsedFeed {
    let podcastTitle: String?
    let podcastAuthor: String?
    let artworkURL: URL?
    let episodes: [ParsedEpisode]   // capped to 50 most recent by publishDate desc
}

struct ParsedEpisode {
    let title: String
    let publishDate: Date
    let descriptionText: String
    let durationSeconds: Int
    let audioURL: String
    let isExplicit: Bool
}
```

`URLSessionFeedFetcher.fetch(url:)`:
1. `URLSession.shared.data(from: url)` → `Data`
2. Hand `Data` to `RSSParser.parse(_:)` (synchronous, but offloaded via `await Task.detached`)
3. Return `ParsedFeed`; `RSSParser` is responsible for the 50-cap.

`RSSParser` is an `XMLParser` SAX delegate that walks `<channel>` and `<item>` elements, capturing:
- channel-level: `<title>`, `<itunes:author>` (fallback `<author>` or empty), `<itunes:image href>`
- item-level: `<title>`, `<pubDate>` (RFC 822 date), `<description>` or `<itunes:summary>`, `<itunes:duration>` (parses `H:MM:SS`, `MM:SS`, or raw seconds), `<enclosure url>`, `<itunes:explicit>` (yes/true → true)

Items are accumulated then sorted by `publishDate` descending and trimmed to 50.

### `OPMLImporter`

```swift
@MainActor
protocol OPMLImporter {
    func extractFeedURLs(from data: Data) throws -> [URL]
}
```

`StandardOPMLImporter` walks `<outline>` elements recursively (Apple Podcasts groups subscriptions by category in nested `<outline>` containers). For each leaf with an `xmlUrl` attribute, parse it as a `URL` and add to the result. Duplicates within the file are de-duplicated. Invalid `xmlUrl` strings are silently skipped.

### `SubscriptionManager`

```swift
@MainActor
@Observable
final class SubscriptionManager {
    private(set) var inFlightSubscriptions: Set<URL> = []
    private(set) var lastImportSummary: ImportSummary?     // populated after OPML import; nil otherwise

    init(searcher: PodcastSearchService, fetcher: FeedFetcher, importer: OPMLImporter, modelContext: ModelContext)

    func isSubscribed(feedURL: URL) -> Bool
    func subscribe(to result: PodcastSearchResult) async
    func subscribe(to feedURL: URL) async
    func importOPML(from data: Data) async
    func refreshAll() async
    func refresh(_ podcast: Podcast) async
}

struct ImportSummary {
    let attempted: Int
    let succeeded: Int
    let alreadySubscribed: Int
    let failed: Int
}
```

**Key behaviors:**

- `subscribe(to: result)`: synchronously inserts a `Podcast` row using iTunes-supplied metadata, marks `inFlightSubscriptions.insert(feedURL)`, then `Task { ... }` to fetch+parse RSS and insert `Episode` rows. On completion (success or failure) removes from `inFlightSubscriptions`. On success sets `podcast.lastFetchedAt`. Episodes are inserted in batch followed by a single `modelContext.save()`.
- `subscribe(to: feedURL)` (OPML path): no iTunes metadata available, so the `Podcast` row is created with placeholder title (the feed URL's host) until the RSS fetch returns. After fetch, `Podcast.title`, `.author`, `.artworkURL` are overwritten with the parsed values. Same `inFlightSubscriptions` lifecycle.
- `isSubscribed(feedURL:)`: SwiftData `FetchDescriptor` filtered by `feedURL == url.absoluteString`.
- `importOPML(from:)`: parse → iterate URLs → for each, skip if already subscribed (count in `alreadySubscribed`), otherwise call `subscribe(to: feedURL)`. Tally `succeeded` and `failed`. Set `lastImportSummary` at the end. The sheet observes this and shows the alert.
- `refreshAll()`: iterates all subscribed podcasts, calls `fetch` for each (sequentially to avoid bursty network), merges parsed episodes (existing episodes are matched by `audioURL`; new ones inserted, matching ones updated). Updates `lastFetchedAt`.
- `refresh(_ podcast:)`: same as one iteration of `refreshAll`, but a no-op if `lastFetchedAt` is within the last 60 seconds (debounce against in-out detail navigation).

---

## UI Flow

### `AddPodcastSheet`

Presented as a `.sheet` from `SubscriptionsListView` when the user taps the existing `+` toolbar button.

**Layout:**
```
┌────────────────────────────────────────┐
│ Cancel                                 │
├────────────────────────────────────────┤
│  🔍  Search podcasts                   │
├────────────────────────────────────────┤
│  Import from File                      │
├────────────────────────────────────────┤
│  ─── results scroll view ───           │
│  [art] Hard Fork                       │
│        The New York Times          [+] │
│  [art] Acquired                        │
│        Ben & David                  ✓  │
│  ...                                   │
└────────────────────────────────────────┘
```

**States:**
- *Empty query:* muted prompt: "Search by title, author, or topic — or import an OPML file."
- *In-flight search:* `ProgressView` centered.
- *Empty results:* "No podcasts found for '<query>'."
- *Search failure:* inline error: "Couldn't reach iTunes. Pull down to retry."
- *Subscribe button per row:* `+` (idle) → `ProgressView` (in-flight, while feedURL is in `inFlightSubscriptions`) → ✓ muted (already subscribed; non-tappable).
- *OPML in progress:* secondary button replaced by `ProgressView` + "Importing N podcasts…"
- *OPML done:* alert with `ImportSummary` text, then sheet auto-dismisses.

**Search field:** `TextField` with a 300ms debounce implemented via a `.task(id: query)` modifier or a `Timer.publish` Combine subscription. Pressing return submits immediately (cancels the pending debounce).

### `SubscriptionsListView` modifications

- The existing `+` toolbar button now presents `AddPodcastSheet` instead of being a no-op stub.
- Add `.refreshable { await subscriptionManager?.refreshAll() }` to the list.
- When `selectedPodcast` is set (user opens detail), call `subscriptionManager?.refresh(podcast)` from `PodcastDetailView.task`.
- Empty state: when `vm.podcasts.isEmpty`, show a centered placeholder: "No podcasts yet — tap + to add."

### Sample data deprecation

`VibecastApp.init()` no longer calls `SampleData.seedIfNeeded`. The `seededDefaultsKey` `UserDefaults` flag is left intact so existing testers don't get a re-seed on update. `SampleData.container` and `insertSampleData(into:)` remain for SwiftUI previews and unit tests.

---

## Refresh Strategy (recap)

| Trigger | Effect |
|---|---|
| User pulls to refresh on the subscriptions list | `refreshAll()` — re-fetches every subscription, merges episodes |
| User opens podcast detail | `refresh(podcast)` — single fetch, debounced if `lastFetchedAt` is < 60s old |
| User taps "+" on a search result | `subscribe(to: result)` — initial fetch only, sets `lastFetchedAt` |
| User imports OPML | `subscribe(to: feedURL)` per imported URL |

No automatic background refresh. No on-launch refresh.

---

## Error Handling

| Failure | UX | Recovery |
|---|---|---|
| iTunes Search non-200 / network error | Inline error in sheet | Re-issue search on next keystroke or pull |
| Search returns 0 results | "No podcasts found for '<query>'." | User refines query |
| RSS fetch HTTP failure | Inline row in podcast detail; row's latest-episode widget falls back to "No episodes" | Pull-to-refresh |
| RSS parse failure (malformed XML) | Treated identically to fetch failure | Pull-to-refresh; manual re-add as workaround |
| OPML file invalid | Alert: "Couldn't parse OPML file. Make sure it's a valid OPML export." | User retries with another file |
| OPML partial failure | Alert: "Imported 12 of 15 podcasts. 3 feeds were unreachable." | User searches the missing ones manually |
| Already subscribed during OPML | Skipped silently; counted in summary | n/a |
| Invalid `feedURL` from iTunes (`URL(string:)` returns nil) | Skip that result row | n/a |

**Logging:** introduce one `Logger(subsystem: "com.dustinanglin.Vibecast", category: "discovery")`; replace any `print` with `logger.error(...)` / `.debug(...)`. While we're here, also retroactively log `try? modelContext.save()` failures from Plan 2 — the `Logger` becomes the project-wide save-failure observer. Pull the bundle identifier from `Bundle.main.bundleIdentifier` if it ever changes; the literal above mirrors the project's current ID.

**Crash boundaries:** no `fatalError`, no force-unwraps in production code paths. Tests can `try!` against bundled fixtures because they're known-good.

---

## Testing Strategy

**Fixture-driven:** capture real iTunes Search and RSS responses once, commit them under `VibecastTests/Fixtures/`. All unit tests are deterministic.

**Mock pattern for URL-based services:** a single shared `MockURLProtocol` (subclass of `URLProtocol`) intercepts requests by URL and returns canned `(Data, URLResponse)` pairs. Inject a `URLSession(configuration:)` whose `protocolClasses` includes `MockURLProtocol` — used by both `iTunesSearchService` and `URLSessionFeedFetcher` in their respective tests.

| Component | New tests | Notes |
|---|---|---|
| `RSSParser` | 8 | 50-cap, missing optional fields default sensibly, multiple `itunes:duration` formats, `itunes:explicit` parsing, malformed XML throws |
| `OPMLImporter` | 4 | Apple Podcasts export → list of feed URLs, nested outline groups flatten, duplicates de-duped, malformed OPML throws |
| `iTunesSearchService` | 3 | Query is URL-encoded, results decode from canned JSON, 0-result case |
| `URLSessionFeedFetcher` | 2 | Routes bytes to `RSSParser` correctly; surfaces network errors |
| `SubscriptionManager` | 10 | Subscribe creates Podcast row immediately + episodes after fetch, dedup by feedURL, refreshAll iterates, refresh debounces, OPML skips already-subscribed, partial-failure summary correct |

**Total:** ~27 new tests. Combined with existing tests after Plan 2, project lands at ~60.

**Manual verification (covered in the implementation plan, not the spec):** simulator script — search for "Hard Fork", subscribe, watch episodes appear; import a small OPML file; pull-to-refresh; restart the app and confirm subscriptions persist and Plan 2's audio engine still plays an episode.

---

## Followup items pulled from Plan 2 reviews to address opportunistically

These can land alongside Plan 3's services where they touch the same files:

- Replace `try? modelContext.save()` silent-swallow with `logger.error` calls (Plan 2 review item)
- Move `import SwiftUI` in `PlayerManager.swift` to the top of file or split env-key into its own file
- Fix Swift 6 conformance-isolation warning on `PlayerManagerKey` via `nonisolated(unsafe) static let defaultValue = nil`
- Bind `FullScreenPlayerView` volume slider directly to `player.volume` rather than the local `@State` mirror
- Extract the duplicated `format(_: TimeInterval)` helper between `MiniPlayerBar` and `FullScreenPlayerView` into a single helper

These are explicitly *bonus*, not Plan 3's mainline goals; the implementation plan should treat them as "if time permits" rather than committed tasks.

---

## Success criteria

- [x] User can search for a podcast and subscribe via the `+` button on a search result row
- [x] Subscribed podcasts populate with up to 50 most-recent episodes from the live RSS feed without blocking UI
- [x] Pull-to-refresh on the subscriptions list refreshes every subscribed podcast's episode list
- [x] OPML import bulk-adds subscriptions from an Apple Podcasts export file; partial failures are surfaced
- [x] First launch after this plan ships shows an empty subscriptions list (no synthetic sample data)
- [x] Plan 1 and Plan 2 features (reorder, swipe, audio playback, mini-player, full-screen player) continue to work against real feed data
- [x] All new code is covered by unit tests using bundled fixtures; no live network calls in test runs
