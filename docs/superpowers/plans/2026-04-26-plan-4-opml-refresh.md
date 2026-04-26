# Vibecast MVP — Plan 4: OPML Import, Refresh & Sample-Data Deprecation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out the MVP by adding OPML bulk-import, pull-to-refresh + detail-open refresh, removing the synthetic sample-data seed, and consolidating the four `ModelContext` instances from Plans 1–3 into a single shared `container.mainContext`.

**Architecture:** Extends Plan 3's `Discovery/` layer with a new `OPMLImporter` (small `XMLParser` SAX delegate, sibling of `RSSParser`) and three new `SubscriptionManager` methods (`subscribe(to: URL)`, `importOPML(from:)`, `refreshAll()`, `refresh(_:)`). UI integration is `.refreshable` on the subscriptions list, an "Import from File" button + `.fileImporter` in the Add Podcast sheet, and a refresh trigger in `PodcastDetailView.task`. SwiftData reads/writes consolidate to `container.mainContext`.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Foundation `URLSession` + `XMLParser`, XCTest, iOS 17+. No new third-party dependencies.

---

## Scope

This is **Plan 4 of 4** in the MVP roadmap.

- **Plan 1 (done)** — Foundation + core UI
- **Plan 2 (done)** — Audio engine, mini-player, full-screen player
- **Plan 3 (done)** — iTunes search + subscribe + real-feed-backed episodes
- **Plan 4 (this plan)** — OPML import, refresh, sample-data deprecation, multi-context consolidation
- **Plan 5 (next)** — cosmetic polish batch (14 followup items deferred from Plan 2 + 3 reviews; details in `docs/superpowers/specs/2026-04-26-plan-4-opml-refresh-design.md`)

**After this plan ships:** the user can pull to refresh, import OPML files, and first-launch users see a real empty state with a clear hint instead of seeded demo podcasts. Existing subscribed-via-search and audio-playback flows continue to work end-to-end.

**Deferred to Plan 5 (explicitly out of Plan 4 scope):**
- Mid-file `import SwiftUI` in `PlayerManager.swift` (Plan 4 fixes the analogous one in `SubscriptionManager.swift` opportunistically — see Task 3)
- Swift 6 `nonisolated(unsafe)` on `PlayerManagerKey` and `SubscriptionManagerKey`
- HTTP status validation in `iTunesSearchService` and `URLSessionFeedFetcher`
- 44pt tap targets + accessibility labels on `SearchResultRow` and `PlayControlView`
- `RSSParser` not reusable on second `parse()` call
- Replace `try? modelContext.save()` swallows with `Logger`
- `FullScreenPlayerView` volume slider — bind directly to `player.volume`
- Shared `format(_:)` time helper for `MiniPlayerBar` and `FullScreenPlayerView`
- `handlePlaybackEnd` duration mismatch
- Auto-clear Task race in `failedSubscribes`; `failedSubscribes` leak on `isSubscribed` early-return
- `AddPodcastSheet.runSearch` `Task.checkCancellation()` after the await
- `SearchResultRow` `#Preview` missing `isFailed: true` row

---

## File Map

```
Vibecast/Vibecast/
├── VibecastApp.swift                                  — MODIFY (Task 1): pass c.mainContext to both
│                                                                          managers; drop seedIfNeeded;
│                                                                          add importer arg in Task 6
├── Discovery/
│   ├── SubscriptionManager.swift                      — MODIFY (Tasks 5, 6, 7): subscribe(to: URL),
│   │                                                                              importOPML, refreshAll,
│   │                                                                              refresh(_:)
│   ├── SubscriptionManager+Environment.swift          — NEW (Task 3): split env-key out of main file
│   └── OPMLImporter.swift                             — NEW (Task 4): protocol + StandardOPMLImporter
└── Views/
    ├── SubscriptionsListView.swift                    — MODIFY (Task 2): empty-state ContentUnavailableView
    │                                                  — MODIFY (Task 9): .refreshable
    ├── PodcastDetailView.swift                        — MODIFY (Task 10): refresh on .task
    └── AddPodcastSheet.swift                          — MODIFY (Task 8): Import button + .fileImporter

Vibecast/Vibecast/ViewModels/
└── PodcastDetailViewModel.swift                       — MODIFY (Task 10): add refetch() method

Vibecast/VibecastTests/
├── Fixtures/
│   ├── opml-apple-podcasts.xml                        — NEW (Task 4)
│   └── opml-malformed.xml                             — NEW (Task 4)
├── OPMLImporterTests.swift                            — NEW (Task 4): 4 tests
└── SubscriptionManagerTests.swift                     — MODIFY (Tasks 5, 6, 7): +11 tests, +MockOPMLImporter
```

**Notes:**
- `OPMLImporter.swift` mirrors `RSSParser.swift`'s SAX-delegate pattern.
- Splitting the env-key extension out of `SubscriptionManager.swift` (Task 3) is the only piece of Plan 5 polish that lands now — and only because the file is already being modified extensively in Tasks 5–7.
- Xcode synced folders auto-pick up new `.swift` files and bundle resources. **No `.xcodeproj` edits required.**

---

## Task 1: Consolidate to `mainContext` + Drop Sample-Data Seed

**Files:**
- Modify: `Vibecast/Vibecast/VibecastApp.swift`

Pass `c.mainContext` to both managers (eliminates the cross-context staleness footgun from Plan 3). Drop the `SampleData.seedIfNeeded(into:)` call so first-launch users see the empty state Task 2 will add. Existing-tester behavior is unchanged: anyone with seeded data on disk keeps it until they manually delete it.

- [ ] **Step 1: Read the current `Vibecast/Vibecast/VibecastApp.swift`**

To confirm structure (existing `MainActor.assumeIsolated` block, both manager constructors).

- [ ] **Step 2: Replace the file's contents**

Replace `Vibecast/Vibecast/VibecastApp.swift` with this exact content:

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

        // Both managers share the views' main context so writes are immediately
        // visible to any @Query / FetchDescriptor reads in the same context.
        // No more sample-data seed — first-launch users see the empty state
        // hint Task 2 adds. Existing testers keep their seeded podcasts.
        let player: PlayerManager
        let subs: SubscriptionManager
        (player, subs) = MainActor.assumeIsolated {
            let p = PlayerManager(engine: AVPlayerAudioEngine(), modelContext: c.mainContext)
            let s = SubscriptionManager(
                searcher: iTunesSearchService(),
                fetcher: URLSessionFeedFetcher(),
                modelContext: c.mainContext
            )
            return (p, s)
        }
        _playerManager = State(initialValue: player)
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

(The `importer:` parameter is added to `SubscriptionManager`'s init in Task 6 — for now the existing 3-argument signature stays.)

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 58 tests pass (Plan 3 baseline). The in-memory test `ModelContainer`s in test files use their own `mainContext` already, so the test suite is unaffected.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/VibecastApp.swift
git commit -m "feat: consolidate to mainContext and drop sample-data seed at launch"
```

---

## Task 2: Empty-State Hint on the Subscriptions List

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`

When `vm.podcasts.isEmpty`, replace the `List` with a `ContentUnavailableView` that nudges the user toward the `+` toolbar button.

- [ ] **Step 1: Read the current `SubscriptionsListView.swift`**

Confirm the `listContent(viewModel:)` function exists and the `Group` structure inside the `NavigationStack`.

- [ ] **Step 2: Modify `listContent(viewModel:)` to branch on emptiness**

Find the `private func listContent(viewModel vm: SubscriptionsViewModel) -> some View` block. Wrap its body in an `if/else`:

```swift
    @ViewBuilder
    private func listContent(viewModel vm: SubscriptionsViewModel) -> some View {
        if vm.podcasts.isEmpty {
            ContentUnavailableView(
                "No podcasts yet",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Tap + to search for podcasts or import an OPML file.")
            )
        } else {
            List {
                ForEach(vm.podcasts) { podcast in
                    // ... existing PodcastRowView block, unchanged ...
                }
                .onMove { source, destination in
                    vm.move(from: source, to: destination)
                }
            }
            .listStyle(.plain)
        }
    }
```

The exact body of the `else` branch is whatever is currently inside `listContent`'s body — preserve it verbatim, just nest under the new `else`.

The `@ViewBuilder` annotation is required so the `if/else` compiles as a single returned view.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 58 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Views/SubscriptionsListView.swift
git commit -m "feat: empty-state hint on subscriptions list"
```

---

## Task 3: Split `SubscriptionManager` Environment Key Into Its Own File

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`
- Create: `Vibecast/Vibecast/Discovery/SubscriptionManager+Environment.swift`

Plan 3 left `import SwiftUI` and the `EnvironmentKey` extension at the bottom of `SubscriptionManager.swift` (mirroring the same anti-pattern from `PlayerManager.swift`). Tasks 5–7 will edit the manager file extensively, so we may as well clean this up first. The analogous `PlayerManager.swift` cleanup is deferred to Plan 5 since Plan 4 doesn't touch that file.

- [ ] **Step 1: Read the bottom of `SubscriptionManager.swift`**

Confirm the env-key extension's exact contents (the `import SwiftUI`, `private struct SubscriptionManagerKey: EnvironmentKey`, and the `extension EnvironmentValues`).

- [ ] **Step 2: Create the new file**

Create `Vibecast/Vibecast/Discovery/SubscriptionManager+Environment.swift` with this exact content:

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

- [ ] **Step 3: Remove the env-key block from `SubscriptionManager.swift`**

In `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`, delete the trailing block that begins with `import SwiftUI` and ends with the closing `}` of the `extension EnvironmentValues`. The file should now end with the closing `}` of the `SubscriptionManager` class. No `import SwiftUI` remains in this file.

- [ ] **Step 4: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully — the `subscriptionManager` env value still resolves because the new sibling file is part of the same module.

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 58 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift Vibecast/Vibecast/Discovery/SubscriptionManager+Environment.swift
git commit -m "refactor: split SubscriptionManager environment key to its own file"
```

---

## Task 4: `OPMLImporter` + Tests + Fixtures

**Files:**
- Create: `Vibecast/Vibecast/Discovery/OPMLImporter.swift`
- Create: `Vibecast/VibecastTests/Fixtures/opml-apple-podcasts.xml`
- Create: `Vibecast/VibecastTests/Fixtures/opml-malformed.xml`
- Create: `Vibecast/VibecastTests/OPMLImporterTests.swift`

A SAX-style `XMLParserDelegate` that walks `<outline>` elements recursively (Apple Podcasts groups subscriptions inside category outlines). Captures leaf `xmlUrl` attributes as URLs, dedupes within-file, silently skips invalid URL strings, throws `OPMLImportError.malformed` on invalid XML.

- [ ] **Step 1: Create `opml-apple-podcasts.xml` fixture**

Create `Vibecast/VibecastTests/Fixtures/opml-apple-podcasts.xml` with this exact content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>Apple Podcasts Subscriptions</title>
  </head>
  <body>
    <outline text="Technology">
      <outline type="rss" text="Hard Fork" xmlUrl="https://feeds.simplecast.com/6HKOhNgS"/>
      <outline type="rss" text="Acquired" xmlUrl="https://feeds.transistor.fm/acquired"/>
      <outline type="rss" text="The Vergecast" xmlUrl="https://feeds.megaphone.fm/vergecast"/>
    </outline>
    <outline text="News">
      <outline type="rss" text="The Daily" xmlUrl="https://feeds.simplecast.com/54nAGcIl"/>
      <outline type="rss" text="Hard Fork" xmlUrl="https://feeds.simplecast.com/6HKOhNgS"/>
    </outline>
    <outline type="rss" text="Top-level entry" xmlUrl="https://example.com/toplevel.xml"/>
    <outline text="Garbage entries">
      <outline type="rss" text="Empty URL" xmlUrl=""/>
      <outline type="rss" text="No URL attribute"/>
    </outline>
  </body>
</opml>
```

This exercises:
- Multiple categories with leaf entries
- Within-file duplicate (`Hard Fork` appears under both Technology and News)
- A leaf at body root (`Top-level entry`) without a category wrapper
- Empty `xmlUrl=""` and missing-attribute leaves (must be silently skipped)

Add target membership: `VibecastTests`.

- [ ] **Step 2: Create `opml-malformed.xml` fixture**

Create `Vibecast/VibecastTests/Fixtures/opml-malformed.xml` with this exact content (truncated mid-tag):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>Malformed</title>
  <body>
    <outline xmlUrl="https://example.com/feed.xml"
```

Add target membership: `VibecastTests`.

- [ ] **Step 3: Write the failing tests**

Create `Vibecast/VibecastTests/OPMLImporterTests.swift` with this exact content:

```swift
import XCTest
@testable import Vibecast

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
            XCTAssertEqual(opmlError, .malformed)
        }
    }

    private func fixture(_ name: String, ext: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: ext)!
        return try Data(contentsOf: url)
    }
}
```

- [ ] **Step 4: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: compile error — `StandardOPMLImporter` and `OPMLImportError` not defined.

- [ ] **Step 5: Implement `OPMLImporter.swift`**

Create `Vibecast/Vibecast/Discovery/OPMLImporter.swift` with this exact content:

```swift
import Foundation

@MainActor
protocol OPMLImporter {
    func extractFeedURLs(from data: Data) throws -> [URL]
}

enum OPMLImportError: Error, Equatable {
    case malformed
}

@MainActor
final class StandardOPMLImporter: NSObject, OPMLImporter, XMLParserDelegate {
    private var collected: [URL] = []
    private var seen: Set<String> = []

    func extractFeedURLs(from data: Data) throws -> [URL] {
        collected = []
        seen = []

        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { throw OPMLImportError.malformed }

        return collected
    }

    // MARK: - XMLParserDelegate

    nonisolated func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "outline" else { return }
        guard let xmlUrl = attributeDict["xmlUrl"], !xmlUrl.isEmpty else { return }
        guard let url = URL(string: xmlUrl) else { return }

        // Cross-actor mutation: SAX delegate callbacks fire from the parser's
        // queue. We're @MainActor; the parser is invoked synchronously from
        // extractFeedURLs(from:) which IS on the main actor, so these
        // callbacks fire synchronously on main too. The nonisolated annotation
        // on the delegate methods is only required because XMLParserDelegate's
        // declaration doesn't carry actor isolation.
        MainActor.assumeIsolated {
            let key = url.absoluteString
            guard !seen.contains(key) else { return }
            seen.insert(key)
            collected.append(url)
        }
    }
}
```

- [ ] **Step 6: Run tests — verify all 4 pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 62 tests pass (58 baseline + 4 new). No failures.

- [ ] **Step 7: Commit**

```bash
git add Vibecast/Vibecast/Discovery/OPMLImporter.swift Vibecast/VibecastTests/Fixtures/opml-apple-podcasts.xml Vibecast/VibecastTests/Fixtures/opml-malformed.xml Vibecast/VibecastTests/OPMLImporterTests.swift
git commit -m "feat: add OPMLImporter with category-flattening and within-file dedup"
```

---

## Task 5: `SubscriptionManager.subscribe(to: URL)` Overload

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`
- Modify: `Vibecast/VibecastTests/SubscriptionManagerTests.swift`

The OPML-flow entry point. Mirrors `subscribe(to: PodcastSearchResult)`'s fail-first contract: fetch RSS first, only insert the `Podcast` row on success. Title/author/artwork come from the parsed RSS (no iTunes metadata available). Same dedup-by-feedURL.

- [ ] **Step 1: Write the failing tests**

In `Vibecast/VibecastTests/SubscriptionManagerTests.swift`, append the following 3 tests above the closing `}` of the `SubscriptionManagerTests` class (i.e., before the `// MARK: - Test Doubles` divider):

```swift
    func test_subscribeFeedURL_insertsRowOnSuccess() async {
        let url = URL(string: "https://feeds.example.com/podcastA")!
        fetcher.feed = ParsedFeed(
            podcastTitle: "Parsed Title",
            podcastAuthor: "Parsed Author",
            artworkURL: URL(string: "https://example.com/art.jpg"),
            episodes: [
                ParsedEpisode(title: "E1", publishDate: .now, descriptionText: "d", durationSeconds: 1800, audioURL: "https://x/1.mp3", isExplicit: false),
            ]
        )
        await manager.subscribe(to: url)

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)
        XCTAssertEqual(podcasts[0].title, "Parsed Title")
        XCTAssertEqual(podcasts[0].author, "Parsed Author")
        XCTAssertEqual(podcasts[0].artworkURL, "https://example.com/art.jpg")
        XCTAssertEqual(podcasts[0].feedURL, url.absoluteString)
        XCTAssertNil(podcasts[0].iTunesCollectionId)  // no iTunes metadata for OPML path
        XCTAssertEqual(podcasts[0].episodes.count, 1)
    }

    func test_subscribeFeedURL_skipsRowOnFetchFailure() async {
        fetcher.error = URLError(.notConnectedToInternet)
        await manager.subscribe(to: URL(string: "https://feeds.example.com/podcastA")!)

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 0)
    }

    func test_subscribeFeedURL_dedupesByFeedURL() async {
        let url = URL(string: "https://feeds.example.com/podcastA")!
        let existing = Podcast(title: "Already", author: "Subscribed", artworkURL: nil, feedURL: url.absoluteString)
        context.insert(existing)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.subscribe(to: url)

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.count, 1)
        XCTAssertEqual(podcasts[0].title, "Already")  // existing record left alone
    }
```

- [ ] **Step 2: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: compile error — `manager.subscribe(to: URL)` overload not defined.

- [ ] **Step 3: Implement `subscribe(to: URL)`**

Open `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`. Find the existing `subscribe(to result: PodcastSearchResult) async` method. Add this new overload immediately AFTER it (before the next method or `private` helper):

```swift
    /// OPML path: subscribe by feed URL alone, with no iTunes metadata.
    /// Title/author/artwork come from the parsed RSS. Same fail-first contract
    /// as subscribe(to: PodcastSearchResult): if the RSS fetch fails, no
    /// Podcast row is inserted.
    func subscribe(to feedURL: URL) async {
        guard !isSubscribed(feedURL: feedURL) else { return }

        inFlightSubscriptions.insert(feedURL)
        defer { inFlightSubscriptions.remove(feedURL) }

        let feed: ParsedFeed
        do {
            feed = try await fetcher.fetch(feedURL)
        } catch {
            return
        }

        let nextSortPosition = nextAvailableSortPosition()
        let podcast = Podcast(
            title: feed.podcastTitle ?? feedURL.host ?? feedURL.absoluteString,
            author: feed.podcastAuthor ?? "",
            artworkURL: feed.artworkURL?.absoluteString,
            feedURL: feedURL.absoluteString,
            sortPosition: nextSortPosition
        )
        modelContext.insert(podcast)

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
    }
```

- [ ] **Step 4: Run tests — verify all 3 pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 65 tests pass (62 + 3 new).

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift Vibecast/VibecastTests/SubscriptionManagerTests.swift
git commit -m "feat: add SubscriptionManager.subscribe(to: URL) for OPML path"
```

---

## Task 6: `SubscriptionManager.importOPML` + Importer Dependency

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift` (add importer dependency, importOPML method, ImportSummary, isImportingOPML)
- Modify: `Vibecast/Vibecast/VibecastApp.swift` (pass `StandardOPMLImporter()` to manager)
- Modify: `Vibecast/VibecastTests/SubscriptionManagerTests.swift` (update setUp, add MockOPMLImporter, 4 new tests)

Add the `OPMLImporter` dependency to `SubscriptionManager.init`, expose `importOPML(from:) async throws`, and ship the `ImportSummary` value type. `isImportingOPML` becomes an `@Observable` flag the sheet UI watches in Task 8.

- [ ] **Step 1: Update existing test `setUp` to pass an importer**

In `Vibecast/VibecastTests/SubscriptionManagerTests.swift`, find the `override func setUp() async throws` block. Update it to construct and pass a `MockOPMLImporter`:

```swift
    var container: ModelContainer!
    var context: ModelContext!
    var searcher: MockSearchService!
    var fetcher: MockFeedFetcher!
    var importer: MockOPMLImporter!
    var manager: SubscriptionManager!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)
        searcher = MockSearchService()
        fetcher = MockFeedFetcher()
        importer = MockOPMLImporter()
        manager = SubscriptionManager(
            searcher: searcher,
            fetcher: fetcher,
            importer: importer,
            modelContext: context
        )
    }
```

(Add `var importer: MockOPMLImporter!` to the property list, `importer = MockOPMLImporter()` to setUp body, and the `importer:` argument to the `SubscriptionManager.init` call.)

- [ ] **Step 2: Add `MockOPMLImporter` test double**

In the same file, in the `// MARK: - Test Doubles` section at the bottom, append:

```swift
@MainActor
final class MockOPMLImporter: OPMLImporter {
    var urls: [URL] = []
    var error: Error?

    func extractFeedURLs(from data: Data) throws -> [URL] {
        if let error { throw error }
        return urls
    }
}
```

- [ ] **Step 3: Write the failing tests**

In `SubscriptionManagerTests.swift`, append the following 4 tests above the closing `}` of the `SubscriptionManagerTests` class (i.e., before the `// MARK: - Test Doubles` divider):

```swift
    func test_importOPML_addsSucceeded_skipsAlreadySubscribed() async throws {
        // Pre-subscribe one feed (so it counts in alreadySubscribed)
        let preexistingURL = URL(string: "https://feeds.example.com/preexisting")!
        let existing = Podcast(title: "Pre", author: "P", artworkURL: nil, feedURL: preexistingURL.absoluteString)
        context.insert(existing)
        try! context.save()

        importer.urls = [
            preexistingURL,                                      // already subscribed
            URL(string: "https://feeds.example.com/new1")!,      // succeeds
            URL(string: "https://feeds.example.com/new2")!,      // succeeds
        ]
        fetcher.feed = sampleFeed()

        try await manager.importOPML(from: Data())

        XCTAssertEqual(manager.lastImportSummary?.attempted, 3)
        XCTAssertEqual(manager.lastImportSummary?.succeeded, 2)
        XCTAssertEqual(manager.lastImportSummary?.alreadySubscribed, 1)
        XCTAssertEqual(manager.lastImportSummary?.failed, 0)
    }

    func test_importOPML_tallisFailedSubscribes() async throws {
        importer.urls = [
            URL(string: "https://feeds.example.com/good")!,
            URL(string: "https://feeds.example.com/bad")!,
        ]
        // Fetcher fails on every call — both attempts fail. Use this to verify
        // failed counts; mid-loop selectivity is not necessary for this contract.
        fetcher.error = URLError(.notConnectedToInternet)

        try await manager.importOPML(from: Data())

        XCTAssertEqual(manager.lastImportSummary?.attempted, 2)
        XCTAssertEqual(manager.lastImportSummary?.succeeded, 0)
        XCTAssertEqual(manager.lastImportSummary?.failed, 2)
    }

    func test_importOPML_setsLastImportSummary() async throws {
        XCTAssertNil(manager.lastImportSummary)

        importer.urls = [URL(string: "https://feeds.example.com/x")!]
        fetcher.feed = sampleFeed()
        try await manager.importOPML(from: Data())

        XCTAssertNotNil(manager.lastImportSummary)
    }

    func test_importOPML_throwsOnMalformedFile() async {
        importer.error = OPMLImportError.malformed

        do {
            try await manager.importOPML(from: Data())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? OPMLImportError, .malformed)
        }
    }
```

- [ ] **Step 4: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15
```

Expected: compile errors — `SubscriptionManager.init` doesn't accept `importer:`, `lastImportSummary` and `importOPML` undefined.

- [ ] **Step 5: Add `importer` dependency, `ImportSummary` type, and `importOPML` to `SubscriptionManager.swift`**

In `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`:

(a) **Add the `importer` property and update init.** Find the existing `@ObservationIgnored private let fetcher: FeedFetcher` line. Add this immediately below it:

```swift
    @ObservationIgnored private let importer: OPMLImporter
```

Update the `init` signature to:

```swift
    init(
        searcher: PodcastSearchService,
        fetcher: FeedFetcher,
        importer: OPMLImporter,
        modelContext: ModelContext
    ) {
        self.searcher = searcher
        self.fetcher = fetcher
        self.importer = importer
        self.modelContext = modelContext
    }
```

(b) **Add observable state.** Find the existing `private(set) var failedSubscribes: Set<URL> = []` line. Add these immediately below it:

```swift
    private(set) var lastImportSummary: ImportSummary?
    private(set) var isImportingOPML: Bool = false
```

(c) **Add `ImportSummary` type and `importOPML` method.** Append the following at the bottom of the file (BEFORE the closing `}` of the `SubscriptionManager` class):

```swift
    /// Parses OPML data, deduplicates within-file, iterates subscribe(to: URL)
    /// sequentially, and tallies an ImportSummary. Sets isImportingOPML true
    /// for the duration. Throws if the OPML data itself is malformed; per-feed
    /// failures are counted into the summary, not thrown.
    func importOPML(from data: Data) async throws {
        isImportingOPML = true
        defer { isImportingOPML = false }

        let urls = try importer.extractFeedURLs(from: data)
        var succeeded = 0
        var alreadySubscribed = 0
        var failed = 0

        for url in urls {
            if isSubscribed(feedURL: url) {
                alreadySubscribed += 1
                continue
            }
            let beforeCount = (try? modelContext.fetchCount(FetchDescriptor<Podcast>())) ?? 0
            await subscribe(to: url)
            let afterCount = (try? modelContext.fetchCount(FetchDescriptor<Podcast>())) ?? 0
            if afterCount > beforeCount {
                succeeded += 1
            } else {
                failed += 1
            }
        }

        lastImportSummary = ImportSummary(
            attempted: urls.count,
            succeeded: succeeded,
            alreadySubscribed: alreadySubscribed,
            failed: failed
        )
    }
}

struct ImportSummary: Equatable {
    let attempted: Int
    let succeeded: Int
    let alreadySubscribed: Int
    let failed: Int
}
```

Note the closing `}` placement — `importOPML` is the last method inside the class, then the class closes, then `ImportSummary` is declared at file-scope outside the class.

- [ ] **Step 6: Update `VibecastApp.swift` to pass the importer**

In `Vibecast/Vibecast/VibecastApp.swift`, find the `SubscriptionManager(...)` constructor call. Add the `importer:` argument:

```swift
            let s = SubscriptionManager(
                searcher: iTunesSearchService(),
                fetcher: URLSessionFeedFetcher(),
                importer: StandardOPMLImporter(),
                modelContext: c.mainContext
            )
```

- [ ] **Step 7: Run tests — verify all 4 pass + existing 11 still pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 69 tests pass (65 + 4 new). All pre-existing `SubscriptionManagerTests` continue to pass (they now just have the importer mock injected via setUp).

- [ ] **Step 8: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift Vibecast/Vibecast/VibecastApp.swift Vibecast/VibecastTests/SubscriptionManagerTests.swift
git commit -m "feat: add importOPML and ImportSummary to SubscriptionManager"
```

---

## Task 7: `refreshAll()` + `refresh(_ podcast:)` with 60s Debounce

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`
- Modify: `Vibecast/VibecastTests/SubscriptionManagerTests.swift`

Iterate every subscribed podcast and merge new episodes by `audioURL` (preserving `playbackPosition` and `listenedStatus` on existing episodes). The single-podcast variant is a no-op when `lastFetchedAt` is < 60 seconds old.

- [ ] **Step 1: Write the failing tests**

In `SubscriptionManagerTests.swift`, append these 4 tests above the `// MARK: - Test Doubles` divider:

```swift
    func test_refreshAll_iteratesAllSubscribedPodcasts() async {
        let urlA = "https://feeds.example.com/a"
        let urlB = "https://feeds.example.com/b"
        context.insert(Podcast(title: "A", author: "A", artworkURL: nil, feedURL: urlA))
        context.insert(Podcast(title: "B", author: "B", artworkURL: nil, feedURL: urlB))
        try! context.save()

        var fetchedURLs: [URL] = []
        fetcher.feed = sampleFeed()
        fetcher.beforeFetch = { url in fetchedURLs.append(url) }

        await manager.refreshAll()

        XCTAssertEqual(Set(fetchedURLs.map(\.absoluteString)), [urlA, urlB])
    }

    func test_refreshAll_mergesEpisodesByAudioURL_preservingUserState() async {
        let url = URL(string: "https://feeds.example.com/a")!
        let podcast = Podcast(title: "A", author: "A", artworkURL: nil, feedURL: url.absoluteString)
        context.insert(podcast)

        // Pre-existing episode with user state
        let existing = Episode(
            podcast: podcast,
            title: "OLD title",
            publishDate: .now.addingTimeInterval(-86400),
            descriptionText: "old desc",
            durationSeconds: 1000,
            audioURL: "https://x/1.mp3"
        )
        existing.playbackPosition = 250
        existing.listenedStatus = .inProgress
        context.insert(existing)
        podcast.episodes.append(existing)
        try! context.save()

        // Fetch returns: 1 update for the same audioURL, 1 net-new episode
        fetcher.feed = ParsedFeed(
            podcastTitle: nil, podcastAuthor: nil, artworkURL: nil,
            episodes: [
                ParsedEpisode(title: "NEW title", publishDate: .now, descriptionText: "new desc", durationSeconds: 1500, audioURL: "https://x/1.mp3", isExplicit: false),
                ParsedEpisode(title: "Brand new", publishDate: .now, descriptionText: "n", durationSeconds: 600, audioURL: "https://x/2.mp3", isExplicit: false),
            ]
        )

        await manager.refreshAll()

        let podcasts = try! context.fetch(FetchDescriptor<Podcast>())
        XCTAssertEqual(podcasts.first?.episodes.count, 2)
        let updated = podcasts.first?.episodes.first { $0.audioURL == "https://x/1.mp3" }
        XCTAssertEqual(updated?.title, "NEW title")          // metadata refreshed
        XCTAssertEqual(updated?.descriptionText, "new desc") // metadata refreshed
        XCTAssertEqual(updated?.durationSeconds, 1500)       // metadata refreshed
        XCTAssertEqual(updated?.playbackPosition, 250)       // user state preserved
        XCTAssertEqual(updated?.listenedStatus, .inProgress) // user state preserved
    }

    func test_refresh_skipsWhenLastFetchedAtIsRecent() async {
        let podcast = Podcast(
            title: "A", author: "A", artworkURL: nil,
            feedURL: "https://feeds.example.com/a",
            lastFetchedAt: .now  // just-fetched
        )
        context.insert(podcast)
        try! context.save()

        var fetchCount = 0
        fetcher.feed = sampleFeed()
        fetcher.beforeFetch = { _ in fetchCount += 1 }

        await manager.refresh(podcast)

        XCTAssertEqual(fetchCount, 0)
    }

    func test_refresh_updatesLastFetchedAtOnSuccess() async {
        let podcast = Podcast(
            title: "A", author: "A", artworkURL: nil,
            feedURL: "https://feeds.example.com/a",
            lastFetchedAt: .now.addingTimeInterval(-3600)  // an hour ago
        )
        context.insert(podcast)
        try! context.save()

        fetcher.feed = sampleFeed()
        await manager.refresh(podcast)

        XCTAssertNotNil(podcast.lastFetchedAt)
        XCTAssertGreaterThan(podcast.lastFetchedAt!, .now.addingTimeInterval(-5))
    }
```

(Note `MockFeedFetcher` needs a new `beforeFetch: ((URL) -> Void)?` hook — the next sub-step adds it.)

- [ ] **Step 2: Add `beforeFetch` hook to `MockFeedFetcher`**

In `SubscriptionManagerTests.swift`'s `// MARK: - Test Doubles` section, find the `MockFeedFetcher` class. Replace its body with:

```swift
@MainActor
final class MockFeedFetcher: FeedFetcher {
    var feed: ParsedFeed?
    var error: Error?
    var beforeFetch: ((URL) -> Void)?

    func fetch(_ feedURL: URL) async throws -> ParsedFeed {
        beforeFetch?(feedURL)
        if let error { throw error }
        return feed ?? ParsedFeed(podcastTitle: nil, podcastAuthor: nil, artworkURL: nil, episodes: [])
    }
}
```

- [ ] **Step 3: Verify the tests fail to compile**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -10
```

Expected: compile errors — `manager.refreshAll()` and `manager.refresh(_:)` not defined.

- [ ] **Step 4: Implement `refreshAll()` + `refresh(_:)` + episode merge helper**

In `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`, append the following methods inside the `SubscriptionManager` class (before its closing `}`):

```swift
    /// Pull-to-refresh on the subscriptions list. Iterates every subscribed
    /// podcast sequentially. Per-podcast errors are swallowed (refresh is
    /// best-effort; the user pulls again to retry). Episodes are merged by
    /// audioURL — existing episodes get metadata updates, new episodes are
    /// inserted, none are deleted, and user state (playbackPosition,
    /// listenedStatus) on existing episodes is preserved.
    func refreshAll() async {
        let descriptor = FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
        let podcasts = (try? modelContext.fetch(descriptor)) ?? []
        for podcast in podcasts {
            await fetchAndMerge(podcast)
        }
    }

    /// Detail-open refresh. No-op if the podcast was fetched within the last
    /// `refreshDebounceSeconds` seconds — prevents in/out navigation from
    /// spamming the network.
    func refresh(_ podcast: Podcast) async {
        if let last = podcast.lastFetchedAt,
           Date().timeIntervalSince(last) < Self.refreshDebounceSeconds {
            return
        }
        await fetchAndMerge(podcast)
    }

    @ObservationIgnored private static let refreshDebounceSeconds: TimeInterval = 60

    private func fetchAndMerge(_ podcast: Podcast) async {
        guard let url = URL(string: podcast.feedURL) else { return }

        let feed: ParsedFeed
        do {
            feed = try await fetcher.fetch(url)
        } catch {
            return
        }

        let existingByAudioURL = Dictionary(
            uniqueKeysWithValues: podcast.episodes.map { ($0.audioURL, $0) }
        )

        for parsed in feed.episodes {
            if let existing = existingByAudioURL[parsed.audioURL] {
                existing.title = parsed.title
                existing.publishDate = parsed.publishDate
                existing.descriptionText = parsed.descriptionText
                existing.durationSeconds = parsed.durationSeconds
                existing.isExplicit = parsed.isExplicit
                // playbackPosition + listenedStatus deliberately untouched.
            } else {
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
        }
        podcast.lastFetchedAt = .now
        try? modelContext.save()
    }
```

- [ ] **Step 5: Run tests — verify all 4 pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 73 tests pass (69 + 4 new).

- [ ] **Step 6: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift Vibecast/VibecastTests/SubscriptionManagerTests.swift
git commit -m "feat: add refreshAll and refresh with 60s debounce + episode merge"
```

---

## Task 8: AddPodcastSheet "Import from File" Button

**Files:**
- Modify: `Vibecast/Vibecast/Views/AddPodcastSheet.swift`

Add the OPML import button below the search drawer, the `.fileImporter`, and the success/failure alerts. While `manager.isImportingOPML == true`, the results area shows a centered progress view.

- [ ] **Step 1: Read the current `AddPodcastSheet.swift`**

Confirm the existing structure: `let manager: SubscriptionManager`, the search-driven `Phase` enum, the `@ViewBuilder content`, the `runSearch()` private method.

- [ ] **Step 2: Add new state, the .fileImporter, and the Import button**

Replace the contents of `Vibecast/Vibecast/Views/AddPodcastSheet.swift` with this exact content:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct AddPodcastSheet: View {
    let manager: SubscriptionManager

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [PodcastSearchResult] = []
    @State private var phase: Phase = .idle
    @State private var lastSubmittedQuery = ""

    @State private var showFileImporter = false
    @State private var showImportSummaryAlert = false
    @State private var showImportFailureAlert = false

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
                .safeAreaInset(edge: .top) {
                    importButton
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .task(id: query) {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    await runSearch()
                }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [
                        UTType(filenameExtension: "opml") ?? .xml,
                        .xml,
                    ],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImport(result)
                }
                .alert("Import Result", isPresented: $showImportSummaryAlert, presenting: manager.lastImportSummary) { _ in
                    Button("OK") { dismiss() }
                } message: { summary in
                    Text(importSummaryMessage(summary))
                }
                .alert("Couldn't Import", isPresented: $showImportFailureAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Couldn't parse OPML file. Make sure it's a valid OPML export.")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if manager.isImportingOPML {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Importing podcasts…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
                        isFailed: manager.failedSubscribes.contains(result.feedURL),
                        onTapSubscribe: {
                            Task { await manager.subscribe(to: result) }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                }
                .listStyle(.plain)
            }
        }
    }

    private var importButton: some View {
        Button {
            showFileImporter = true
        } label: {
            Label("Import from File", systemImage: "square.and.arrow.down")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(manager.isImportingOPML)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        Task {
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                showImportFailureAlert = true
                return
            }
            do {
                try await manager.importOPML(from: data)
                showImportSummaryAlert = true
            } catch {
                showImportFailureAlert = true
            }
        }
    }

    private func importSummaryMessage(_ summary: ImportSummary) -> String {
        var parts: [String] = []
        parts.append("Imported \(summary.succeeded) of \(summary.attempted) podcasts.")
        if summary.alreadySubscribed > 0 {
            parts.append("\(summary.alreadySubscribed) already subscribed.")
        }
        if summary.failed > 0 {
            parts.append("\(summary.failed) couldn't be reached.")
        }
        return parts.joined(separator: " ")
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

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 73 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Views/AddPodcastSheet.swift
git commit -m "feat: add Import from File button with .fileImporter and result alerts"
```

---

## Task 9: Pull-to-Refresh on the Subscriptions List

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`

Add `.refreshable` to the `List`. Inside, await `subscriptionManager?.refreshAll()` then call `viewModel?.fetch()` so the cached `vm.podcasts` array picks up any newly inserted episodes (existing `Podcast` row identity doesn't change, but the row's "latest episode" widget reads from `podcast.episodes` which is now populated).

- [ ] **Step 1: Read the current `SubscriptionsListView.swift`**

Confirm the `listContent(viewModel:)` structure (now wrapped in if/else from Task 2). The `.refreshable` modifier goes on the `List` inside the `else` branch.

- [ ] **Step 2: Add `.refreshable`**

In `listContent(viewModel:)`'s `else` branch, find the `List { ... }.listStyle(.plain)` block. Append a `.refreshable` modifier:

```swift
            List {
                ForEach(vm.podcasts) { podcast in
                    // ... existing PodcastRowView block, unchanged ...
                }
                .onMove { source, destination in
                    vm.move(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await subscriptionManager?.refreshAll()
                vm.fetch()
            }
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 73 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Views/SubscriptionsListView.swift
git commit -m "feat: pull-to-refresh on subscriptions list"
```

---

## Task 10: PodcastDetailView Refresh on `.task`

**Files:**
- Modify: `Vibecast/Vibecast/ViewModels/PodcastDetailViewModel.swift` (add `refetch()` method)
- Modify: `Vibecast/Vibecast/Views/PodcastDetailView.swift`

When the detail sheet appears, refresh the podcast's RSS feed. The `refresh(_:)` debounce keeps rapid in/out navigation cheap.

- [ ] **Step 1: Read the current `PodcastDetailViewModel.swift`**

Confirm the existing structure (likely `@Observable` with cached `displayedEpisodes`, pagination, etc.).

- [ ] **Step 2: Add `refetch()` method to `PodcastDetailViewModel`**

In `Vibecast/Vibecast/ViewModels/PodcastDetailViewModel.swift`, find the existing fetch logic. Add a public method that re-runs whatever `init` did to populate `displayedEpisodes`. The exact implementation depends on the file's current shape. The simplest approach is to add a method that calls the same private fetch path used at init — name it `refetch()`:

```swift
    /// Re-run the initial fetch logic. Called after SubscriptionManager.refresh
    /// inserts new Episode rows so the cached displayedEpisodes picks them up.
    func refetch() {
        // Replace the body with whatever the existing init/fetch path does.
        // If init does `displayedEpisodes = pageOne()`, refetch does the same.
        // If there is already a private `fetch()` or `loadFirstPage()`, call it.
    }
```

(The implementer will need to read the file first. The simplest case: there's already a `private func fetchInitial()` or similar — `refetch()` just calls it. If the init body does the fetch inline, extract that into a private `fetchInitial()` method and call it from both `init` and `refetch()`.)

- [ ] **Step 3: Read the current `PodcastDetailView.swift`**

Confirm the existing `.task` block structure (sets up `viewModel` if nil).

- [ ] **Step 4: Modify `PodcastDetailView`'s `.task` to call refresh + refetch**

Find the `.task { if viewModel == nil { viewModel = PodcastDetailViewModel(podcast: podcast) } }` block. Replace it with:

```swift
        .task {
            if viewModel == nil {
                viewModel = PodcastDetailViewModel(podcast: podcast)
            }
            await subscriptionManager?.refresh(podcast)
            viewModel?.refetch()
        }
```

Add `@Environment(\.subscriptionManager) private var subscriptionManager` near the top of the struct if it isn't already there. (Plan 3's wiring may have added it; verify.)

- [ ] **Step 5: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

- [ ] **Step 6: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 73 tests pass.

- [ ] **Step 7: Commit**

```bash
git add Vibecast/Vibecast/ViewModels/PodcastDetailViewModel.swift Vibecast/Vibecast/Views/PodcastDetailView.swift
git commit -m "feat: refresh podcast on detail view appear"
```

---

## Task 11: End-to-End Manual Verification + Push

**Files:**
- None modified (manual verification + final commits if issues found).

Confirm Plan 4 flows end-to-end against real iTunes Search responses, real RSS feeds, and a real OPML file. The user runs this on their simulator and reports back; the implementer's job here is just to confirm the build cleanly launches and to push the branch once verification passes.

- [ ] **Step 1: Build + launch on simulator**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Then ⌘R in Xcode.

- [ ] **Step 2: Manual simulator verification (executed by user)**

The user runs through these steps and reports each pass/fail:

| Step | Action | Expected |
|---|---|---|
| 1 | Cold launch on a clean simulator (delete the app first if needed) | Empty subscriptions list with "No podcasts yet — Tap + to search for podcasts or import an OPML file." hint |
| 2 | Tap `+`, search and subscribe to a podcast (e.g. Hard Fork) | Row appears at bottom, episodes populate (Plan 3 baseline behavior) |
| 3 | Pull down on the subscriptions list | Spinner appears; completes in 1–3s; list still shows the same podcasts (no duplicates, episodes preserved) |
| 4 | Open the just-subscribed podcast's detail | Detail sheet opens; existing `lastFetchedAt` is < 60s old, so the debounce skips the network call. (Optional: temporarily print log to confirm.) |
| 5 | Back out, wait 65s, re-open same detail | This time the debounce passes; `fetch` fires; any new episodes appear |
| 6 | Tap `+`, then "Import from File" | System file picker opens, `.opml` and `.xml` files selectable |
| 7 | Pick a sample OPML file (Apple Podcasts → Settings → Subscriptions → Export, or hand-craft a small file) | Sheet shows "Importing podcasts…" progress. On completion, alert shows "Imported X of Y podcasts." Sheet auto-dismisses on tap. New podcasts appear in the list with episodes populated |
| 8 | Same import a second time | All entries already-subscribed; alert says "Imported 0 of Y podcasts. Y already subscribed." |
| 9 | Quit + relaunch | All subscriptions persist with episodes |

**Sample OPML file for step 7** — if the user doesn't have one, this is a minimal known-good one to drop into Files.app:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head><title>Test</title></head>
  <body>
    <outline text="Tech">
      <outline type="rss" text="Hard Fork" xmlUrl="https://feeds.simplecast.com/6HKOhNgS"/>
      <outline type="rss" text="Acquired" xmlUrl="https://feeds.transistor.fm/acquired"/>
    </outline>
  </body>
</opml>
```

- [ ] **Step 3: If any step fails, fix and commit**

Investigate, patch, commit with descriptive `fix:` message. Same pattern as Plan 3's manual-verification fixes.

- [ ] **Step 4: Final all-tests run**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 73 tests pass.

- [ ] **Step 5: Push the branch**

```bash
git push -u origin feature/plan-4-opml-refresh
```

Then merge to main per the convention used at the end of Plan 2 and Plan 3.

---

## Self-review checklist (filled in by plan author, not the implementer)

- **Spec coverage:**
  - OPML import: Tasks 4 (importer) + 5 (subscribe-by-feedURL) + 6 (importOPML) + 8 (UI) ✓
  - Pull-to-refresh: Tasks 7 (refreshAll) + 9 (UI) ✓
  - Refresh-on-detail-open: Tasks 7 (refresh + debounce) + 10 (UI) ✓
  - Sample-data deprecation: Task 1 (drop seed) + Task 2 (empty state) ✓
  - Multi-context consolidation: Task 1 ✓
  - Mid-file `import SwiftUI` cleanup (opportunistic): Task 3 ✓
- **Type consistency:** `OPMLImporter` (protocol) / `StandardOPMLImporter` (impl) / `MockOPMLImporter` (test double) consistently named across Tasks 4, 5, 6. `ImportSummary` defined in Task 6, used in Task 8. `subscribe(to: URL)` signature consistent in Tasks 5 and 6 (the latter calls the former). `refreshDebounceSeconds` constant defined in Task 7.
- **No placeholders:** Task 10 step 2 has the closest thing to a placeholder ("Replace the body with whatever the existing init/fetch path does") — this is intentional because the implementer needs to read the existing `PodcastDetailViewModel` to know the exact shape. The instruction is concrete enough: extract or call the existing init-fetch path. Acceptable.
- **Test count progression:** 58 (Plan 3 baseline) → 62 (Task 4: +4) → 65 (Task 5: +3) → 69 (Task 6: +4) → 73 (Task 7: +4). Tasks 1, 2, 3, 8, 9, 10 don't add unit tests (they're either no-test config changes or UI integration). Final = 73.
- **Plan size estimate:** 11 tasks, ~13–17 commits including any Task-11 fixes. In line with Plan 3's shipped scope.
