# Apple Podcasts Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-tap Apple Podcasts → Vibecast bulk import bridge per `docs/superpowers/specs/2026-05-10-apple-podcasts-import-design.md`. User taps a row in `AddPodcastSheet`, walks through a 3-step wizard (install shortcut → run shortcut → import N podcasts), and lands with their full Apple Podcasts library subscribed in Vibecast.

**Architecture:** A hosted Shortcuts shortcut bridges Apple Podcasts' library (which iOS doesn't expose to third-party apps) into a list of RSS feed URLs delivered to Vibecast via a `vibecast://import-feeds?urls=…` custom URL scheme. The URL handler writes the payload into a small `@Observable` session singleton; the wizard observes it for step state and dispatches to a new `SubscriptionManager.importFeeds(_:)` method that mirrors the existing OPML import path (per-feed `subscribe(to: URL)` + `ImportSummary` tally).

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, `@Observable` (Observation framework, iOS 17+), `@AppStorage`, `UIApplication.shared.open`, `.onOpenURL`. No new third-party dependencies. Reuses Plan 4's `SubscriptionManager.subscribe(to: URL)` for the per-feed subscribe path.

---

## File map

### Created

- `Vibecast/Vibecast/Discovery/ApplePodcastsImportSession.swift` — `@Observable @MainActor final class`, singleton, holds `pendingFeedURLs: [URL]?`, `receivedAt: Date?`, `shouldPresentWizard: Bool`, plus `isFresh: Bool` computed and `clear()` / `receive(_:)` methods.
- `Vibecast/Vibecast/Discovery/VibecastURLHandler.swift` — enum with two static methods: `parseImportFeedsURL(_:)` (pure, testable) and `handle(_:session:)` (dispatches to session).
- `Vibecast/Vibecast/Views/ApplePodcastsImportWizard.swift` — wizard sub-sheet view with three step rows.
- `Vibecast/VibecastTests/VibecastURLHandlerTests.swift` — URL parse + dispatch tests.
- `Vibecast/VibecastTests/ApplePodcastsImportSessionTests.swift` — session state-machine tests.

### Modified

- `Vibecast/Vibecast/Info.plist` — register `CFBundleURLTypes` with the `vibecast` scheme.
- `Vibecast/Vibecast/VibecastApp.swift` — attach `.onOpenURL` at the app root; inject `ApplePodcastsImportSession.shared` into the environment.
- `Vibecast/Vibecast/Discovery/SubscriptionManager.swift` — add `func importFeeds(_ urls: [URL]) async` mirroring `importOPML`'s tally pattern; add `isImportingFeeds: Bool` flag.
- `Vibecast/Vibecast/Views/AddPodcastSheet.swift` — add "Import from Apple Podcasts" row that presents the wizard. Add the `iCloudShortcutInstallURL` constant.
- `Vibecast/Vibecast/Views/SubscriptionsListView.swift` — observe `ApplePodcastsImportSession.shared.shouldPresentWizard` and auto-present `AddPodcastSheet` when true.
- `Vibecast/VibecastTests/SubscriptionManagerTests.swift` — add `importFeeds` tests.

**Notes:**

- Xcode synced folders auto-pick up new `.swift` files. **No `.xcodeproj` edits required** for new files.
- `Info.plist` does require an edit (Task 5) — this is a real file at `Vibecast/Vibecast/Info.plist`, not auto-generated (`GENERATE_INFOPLIST_FILE = NO` in the Debug/Release configs).

---

## Task 1: Build the Shortcut + capture iCloud share URL

**Files:** none in this repo (manual build inside the iOS Shortcuts app).

This task produces two artifacts the rest of the plan depends on:

1. A working shortcut named **"Vibecast Import"** installed in the implementer's Shortcuts library.
2. An iCloud share URL (`https://www.icloud.com/shortcuts/<hash>`) captured into a temporary note for use in Task 8.

The shortcut runs entirely in the Shortcuts app. Vibecast doesn't need to bundle the `.shortcut` file — distribution happens via the iCloud share link.

- [ ] **Step 1: Open Shortcuts.app and verify `Get Podcasts from Library` is available**

On the iPhone running iOS 17+:
1. Open the Shortcuts app.
2. Tap the `+` button (top right) to start a new shortcut.
3. Tap "Add Action."
4. Search for "Get Podcasts from Library." It should appear under the Podcasts app's actions.

If the action isn't found, the user's iOS may not include it. Stop and check the iOS version — bail out of this plan and revisit the macOS-helper-script approach if the action genuinely doesn't exist.

- [ ] **Step 2: Build the shortcut**

Configure the following actions in order:

1. **Get Podcasts from Library** — output: Podcasts list.
2. **Repeat with Each** (over the Podcasts list).
3. Inside the loop:
   - **Get Details of Podcast** → property: `Feed URL`. (If the property is named differently — e.g. `RSS Feed` or `URL` — pick whichever returns the public RSS URL.)
   - **If** "Feed URL" "has any value":
     - **Text** action containing: the Feed URL variable followed by a newline. Append it to a magic "Combined URLs" variable using **Set Variable** / **Add to Variable**.
   - **End If**
4. **End Repeat**.
5. **URL Encode** the Combined URLs variable.
6. **Text** action producing: `vibecast://import-feeds?urls=` followed by the URL-encoded variable.
7. **Open URLs** action consuming the text from step 6.

Name the shortcut **exactly** "Vibecast Import" (capital V, capital I, single space). The Step 2 deep link in the app depends on this exact name.

- [ ] **Step 3: Run the shortcut once to verify**

Tap the shortcut to run it. It should open Vibecast with a `vibecast://import-feeds?urls=...` URL. At this point Vibecast will fail to handle the URL (the scheme isn't registered yet) — that's expected. The success signal here is that **Shortcuts.app produces and opens a URL of the right shape**. You can verify by:

1. Replace the final **Open URLs** action with **Show Result** action (temporarily) — it shows the constructed URL.
2. Verify the URL starts with `vibecast://import-feeds?urls=` and contains URL-encoded feed URLs separated by `%0A` (encoded newline).
3. Switch back to **Open URLs** for production.

- [ ] **Step 4: Share to iCloud and capture the share URL**

1. In Shortcuts.app, long-press the "Vibecast Import" shortcut → "Share" → "iCloud Link."
2. Shortcuts uploads it and presents a share sheet with a URL like `https://www.icloud.com/shortcuts/abc123def456…`.
3. Copy the URL.
4. Save it temporarily in a scratch file or sticky note — it will be pasted into `AddPodcastSheet.swift` during Task 8.

- [ ] **Step 5: Smoke-test the install link**

Open the captured URL in Safari on a *different* device (or on the same device after deleting the shortcut from your library). Verify it shows the "Get Shortcut" install dialog and that tapping it adds "Vibecast Import" to your library with the correct name.

- [ ] **Step 6: Commit a scratch note** (optional)

If you want the share URL tracked in git history before Task 8, commit a stub note:

```bash
echo "Vibecast Import shortcut iCloud share URL: <PASTE HERE>" > docs/superpowers/scratch-shortcut-url.txt
git add docs/superpowers/scratch-shortcut-url.txt
git commit -m "scratch: capture iCloud share URL for Vibecast Import shortcut"
```

You'll delete this file at the end of Task 8 once the URL is in `AddPodcastSheet.swift`.

---

## Task 2: `ApplePodcastsImportSession` (observable singleton)

**Files:**
- Create: `Vibecast/Vibecast/Discovery/ApplePodcastsImportSession.swift`
- Create: `Vibecast/VibecastTests/ApplePodcastsImportSessionTests.swift`

A tiny `@Observable @MainActor final class` that holds the most recent shortcut payload, a freshness timestamp, and a one-shot "please present the wizard" flag. The URL handler writes; the wizard and `SubscriptionsListView` observe.

- [ ] **Step 1: Write the failing tests**

Create `Vibecast/VibecastTests/ApplePodcastsImportSessionTests.swift`:

```swift
import XCTest
@testable import Vibecast

@MainActor
final class ApplePodcastsImportSessionTests: XCTestCase {
    func test_initial_state_isEmpty() {
        let s = ApplePodcastsImportSession()
        XCTAssertNil(s.pendingFeedURLs)
        XCTAssertNil(s.receivedAt)
        XCTAssertFalse(s.shouldPresentWizard)
        XCTAssertFalse(s.isFresh)
    }

    func test_receive_setsAllFields() {
        let s = ApplePodcastsImportSession()
        let urls = [URL(string: "https://a.example/feed.xml")!,
                    URL(string: "https://b.example/feed.xml")!]
        s.receive(urls)
        XCTAssertEqual(s.pendingFeedURLs, urls)
        XCTAssertNotNil(s.receivedAt)
        XCTAssertTrue(s.shouldPresentWizard)
        XCTAssertTrue(s.isFresh)
    }

    func test_isFresh_falseAfterFiveMinutes() {
        let s = ApplePodcastsImportSession()
        s.receive([URL(string: "https://a.example/feed.xml")!])
        // Simulate clock advance: directly stomp receivedAt back in time.
        s.receivedAt = Date().addingTimeInterval(-301)
        XCTAssertFalse(s.isFresh)
    }

    func test_clear_resetsAllFields() {
        let s = ApplePodcastsImportSession()
        s.receive([URL(string: "https://a.example/feed.xml")!])
        s.clear()
        XCTAssertNil(s.pendingFeedURLs)
        XCTAssertNil(s.receivedAt)
        XCTAssertFalse(s.shouldPresentWizard)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test 2>&1 | grep -E '(TEST FAILED|error:)' | head -5
```

Expected: compile errors referencing `ApplePodcastsImportSession` not found.

- [ ] **Step 3: Implement the session**

Create `Vibecast/Vibecast/Discovery/ApplePodcastsImportSession.swift`:

```swift
import Foundation
import Observation

/// Holds the most recent payload received from the "Vibecast Import" Shortcuts
/// shortcut. The URL handler writes here on `.onOpenURL`; the wizard and
/// `SubscriptionsListView` observe.
///
/// `shouldPresentWizard` is a one-shot flag: the URL handler sets it true and
/// `SubscriptionsListView` immediately resets it on present, so re-opening the
/// wizard later requires a fresh shortcut run to trigger an auto-present.
///
/// Payloads are treated as stale after 5 minutes via `isFresh`. The wizard
/// shows a "run the shortcut again" message instead of offering the Import
/// button when stale, preventing an auto-import of a long-abandoned payload
/// after the user has changed their Apple Podcasts subscriptions in the
/// meantime.
@Observable
@MainActor
final class ApplePodcastsImportSession {
    static let shared = ApplePodcastsImportSession()

    var pendingFeedURLs: [URL]? = nil
    var receivedAt: Date? = nil
    var shouldPresentWizard: Bool = false

    /// 5-minute freshness window.
    private static let freshnessSeconds: TimeInterval = 300

    var isFresh: Bool {
        guard let receivedAt else { return false }
        return Date().timeIntervalSince(receivedAt) < Self.freshnessSeconds
    }

    init() {}

    func receive(_ urls: [URL]) {
        pendingFeedURLs = urls
        receivedAt = .now
        shouldPresentWizard = true
    }

    func clear() {
        pendingFeedURLs = nil
        receivedAt = nil
        shouldPresentWizard = false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test 2>&1 | grep -E '(TEST SUCCEEDED|TEST FAILED|tests? failed)' | head -3
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Discovery/ApplePodcastsImportSession.swift \
        Vibecast/VibecastTests/ApplePodcastsImportSessionTests.swift
git commit -m "feat(import): ApplePodcastsImportSession observable singleton"
```

---

## Task 3: `VibecastURLHandler` (URL scheme parser)

**Files:**
- Create: `Vibecast/Vibecast/Discovery/VibecastURLHandler.swift`
- Create: `Vibecast/VibecastTests/VibecastURLHandlerTests.swift`

A pure enum namespace with two static methods. `parseImportFeedsURL(_:)` is testable in isolation; `handle(_:session:)` dispatches the parsed list into the session.

- [ ] **Step 1: Write the failing tests**

Create `Vibecast/VibecastTests/VibecastURLHandlerTests.swift`:

```swift
import XCTest
@testable import Vibecast

@MainActor
final class VibecastURLHandlerTests: XCTestCase {

    // MARK: - parseImportFeedsURL

    func test_parse_singleFeed() {
        let url = URL(string: "vibecast://import-feeds?urls=https%3A%2F%2Fa.example%2Ffeed.xml")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://a.example/feed.xml")!])
    }

    func test_parse_multipleFeeds_newlineSeparated() {
        // Newline-joined: %0A is URL-encoded \n
        let encoded = [
            "https%3A%2F%2Fa.example%2Ffeed.xml",
            "https%3A%2F%2Fb.example%2Ffeed.xml",
            "https%3A%2F%2Fc.example%2Ffeed.xml",
        ].joined(separator: "%0A")
        let url = URL(string: "vibecast://import-feeds?urls=\(encoded)")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [
            URL(string: "https://a.example/feed.xml")!,
            URL(string: "https://b.example/feed.xml")!,
            URL(string: "https://c.example/feed.xml")!,
        ])
    }

    func test_parse_trailingNewline_ignored() {
        let url = URL(string: "vibecast://import-feeds?urls=https%3A%2F%2Fa.example%2Ffeed.xml%0A")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://a.example/feed.xml")!])
    }

    func test_parse_dedupes_duplicateURLs() {
        let encoded = "https%3A%2F%2Fa.example%2Ffeed.xml%0Ahttps%3A%2F%2Fa.example%2Ffeed.xml"
        let url = URL(string: "vibecast://import-feeds?urls=\(encoded)")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://a.example/feed.xml")!])
    }

    func test_parse_filtersOutMalformedURLs() {
        // Mix of valid + obviously-bogus
        let encoded = "https%3A%2F%2Fvalid.example%2Ffeed.xml%0Anot%20a%20url"
        let url = URL(string: "vibecast://import-feeds?urls=\(encoded)")!
        let out = VibecastURLHandler.parseImportFeedsURL(url)
        XCTAssertEqual(out, [URL(string: "https://valid.example/feed.xml")!])
    }

    func test_parse_emptyUrlsParam_returnsEmpty() {
        let url = URL(string: "vibecast://import-feeds?urls=")!
        XCTAssertEqual(VibecastURLHandler.parseImportFeedsURL(url), [])
    }

    func test_parse_missingUrlsParam_returnsEmpty() {
        let url = URL(string: "vibecast://import-feeds")!
        XCTAssertEqual(VibecastURLHandler.parseImportFeedsURL(url), [])
    }

    // MARK: - handle

    func test_handle_validImportFeedsURL_writesToSession() {
        let session = ApplePodcastsImportSession()
        let url = URL(string: "vibecast://import-feeds?urls=https%3A%2F%2Fa.example%2Ffeed.xml")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertTrue(handled)
        XCTAssertEqual(session.pendingFeedURLs, [URL(string: "https://a.example/feed.xml")!])
        XCTAssertTrue(session.shouldPresentWizard)
    }

    func test_handle_emptyList_stillWritesEmptyArray() {
        // The wizard needs to distinguish "no shortcut run yet" (nil) from
        // "shortcut ran but returned 0 feeds" (empty array). The handler
        // writes [] for an empty payload so the wizard can show the
        // "all Apple Originals" message.
        let session = ApplePodcastsImportSession()
        let url = URL(string: "vibecast://import-feeds?urls=")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertTrue(handled)
        XCTAssertEqual(session.pendingFeedURLs, [])
        XCTAssertTrue(session.shouldPresentWizard)
    }

    func test_handle_unknownHost_returnsFalse() {
        let session = ApplePodcastsImportSession()
        let url = URL(string: "vibecast://unknown-action?x=y")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertFalse(handled)
        XCTAssertNil(session.pendingFeedURLs)
    }

    func test_handle_wrongScheme_returnsFalse() {
        let session = ApplePodcastsImportSession()
        let url = URL(string: "https://import-feeds?urls=...")!
        let handled = VibecastURLHandler.handle(url, session: session)
        XCTAssertFalse(handled)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test 2>&1 | grep -E '(TEST FAILED|error:)' | head -5
```

Expected: `VibecastURLHandler` not found in scope.

- [ ] **Step 3: Implement the handler**

Create `Vibecast/Vibecast/Discovery/VibecastURLHandler.swift`:

```swift
import Foundation

/// Static namespace for parsing `vibecast://` URL-scheme payloads.
///
/// Current actions:
/// - `vibecast://import-feeds?urls=<urlencoded-newline-separated-list>`
///   — receives a list of RSS feed URLs from the "Vibecast Import" Shortcuts
///   shortcut and writes them into `ApplePodcastsImportSession`.
///
/// Unknown hosts return `false` from `handle` so the caller (typically the
/// app root's `.onOpenURL`) knows to ignore the URL rather than swallowing it.
enum VibecastURLHandler {
    /// Top-level entry point. Dispatches a `vibecast://...` URL to the right
    /// receiver. Returns `true` if the URL was recognized and handled,
    /// `false` otherwise.
    @MainActor
    @discardableResult
    static func handle(_ url: URL, session: ApplePodcastsImportSession) -> Bool {
        guard url.scheme == "vibecast" else { return false }
        switch url.host {
        case "import-feeds":
            let urls = parseImportFeedsURL(url)
            session.receive(urls)
            return true
        default:
            return false
        }
    }

    /// Parses a `vibecast://import-feeds?urls=<encoded-list>` URL into a
    /// validated, deduplicated list of feed URLs. Returns `[]` if the URL
    /// has no `urls` parameter or if it's empty — empty is distinct from
    /// nil at the session layer (see `handle`'s comment).
    static func parseImportFeedsURL(_ url: URL) -> [URL] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }
        let raw = components.queryItems?.first(where: { $0.name == "urls" })?.value ?? ""

        var seen = Set<String>()
        var result: [URL] = []
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let parsed = URL(string: trimmed),
                  parsed.scheme == "http" || parsed.scheme == "https"
            else { continue }
            if seen.insert(parsed.absoluteString).inserted {
                result.append(parsed)
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test 2>&1 | grep -E '(TEST SUCCEEDED|TEST FAILED)' | head -3
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Discovery/VibecastURLHandler.swift \
        Vibecast/VibecastTests/VibecastURLHandlerTests.swift
git commit -m "feat(import): VibecastURLHandler parses vibecast://import-feeds"
```

---

## Task 4: `SubscriptionManager.importFeeds` + tests

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`
- Modify: `Vibecast/VibecastTests/SubscriptionManagerTests.swift`

Mirrors `importOPML`'s tally pattern but takes a `[URL]` directly instead of OPML data. New `isImportingFeeds: Bool` flag drives the wizard's progress row.

- [ ] **Step 1: Write the failing test**

Append to `Vibecast/VibecastTests/SubscriptionManagerTests.swift`:

```swift
// MARK: - importFeeds

@MainActor
func test_importFeeds_emptyList_summaryAttemptedZero() async {
    let manager = makeManager()
    await manager.importFeeds([])
    XCTAssertEqual(manager.lastImportSummary?.attempted, 0)
    XCTAssertEqual(manager.lastImportSummary?.succeeded, 0)
    XCTAssertEqual(manager.lastImportSummary?.alreadySubscribed, 0)
    XCTAssertEqual(manager.lastImportSummary?.failed, 0)
}

@MainActor
func test_importFeeds_allNew_subscribesEach() async {
    let manager = makeManager()
    let urls = [
        URL(string: "https://a.example/feed.xml")!,
        URL(string: "https://b.example/feed.xml")!,
    ]
    await manager.importFeeds(urls)
    XCTAssertEqual(manager.lastImportSummary?.attempted, 2)
    XCTAssertEqual(manager.lastImportSummary?.succeeded, 2)
    XCTAssertEqual(manager.lastImportSummary?.alreadySubscribed, 0)
}

@MainActor
func test_importFeeds_alreadySubscribed_skipped() async {
    let manager = makeManager()
    let url = URL(string: "https://a.example/feed.xml")!
    await manager.importFeeds([url])
    await manager.importFeeds([url])  // second run, same URL

    // Second summary reflects "already subscribed" path
    XCTAssertEqual(manager.lastImportSummary?.attempted, 1)
    XCTAssertEqual(manager.lastImportSummary?.succeeded, 0)
    XCTAssertEqual(manager.lastImportSummary?.alreadySubscribed, 1)
}

@MainActor
func test_importFeeds_isImportingFeedsFlag_flipsTrueThenFalse() async {
    let manager = makeManager()
    XCTAssertFalse(manager.isImportingFeeds)
    async let _ = manager.importFeeds([URL(string: "https://a.example/feed.xml")!])
    // We can't synchronously assert true mid-flight without a hook; settle for
    // asserting it returns false post-completion.
    await Task.yield()
    _ = await manager.lastImportSummary
    XCTAssertFalse(manager.isImportingFeeds)
}
```

If `makeManager()` doesn't exist in the existing test file, locate the existing pattern for constructing a `SubscriptionManager` with mock fetcher/importer and replicate it. The Plan 4 tests use a `MockFeedFetcher` that returns canned `ParsedFeed` values. Use the same helper.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test 2>&1 | grep -E "(TEST FAILED|error:|importFeeds)" | head -5
```

Expected: errors about `importFeeds` and `isImportingFeeds` not being members of `SubscriptionManager`.

- [ ] **Step 3: Add `isImportingFeeds` property**

In `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`, alongside the existing `private(set) var isImportingOPML: Bool = false`, add:

```swift
private(set) var isImportingFeeds: Bool = false
```

- [ ] **Step 4: Add the `importFeeds` method**

In `SubscriptionManager.swift`, immediately after `importOPML`:

```swift
/// Subscribes to a list of feed URLs sequentially, tallying results into an
/// `ImportSummary`. Mirrors `importOPML`'s contract except that the input is
/// a pre-parsed list rather than OPML XML — this is the path the Apple
/// Podcasts import shortcut feeds into via the `vibecast://import-feeds`
/// URL scheme.
///
/// Per-feed failures are counted into the summary, not thrown. The summary
/// publishes through the same `lastImportSummary` channel the OPML path
/// uses, so existing summary-toast UI surfaces feed-import results too.
func importFeeds(_ urls: [URL]) async {
    isImportingFeeds = true
    defer { isImportingFeeds = false }

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
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test 2>&1 | grep -E '(TEST SUCCEEDED|TEST FAILED)' | head -3
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift \
        Vibecast/VibecastTests/SubscriptionManagerTests.swift
git commit -m "feat(import): SubscriptionManager.importFeeds + isImportingFeeds flag"
```

---

## Task 5: Register `vibecast://` URL scheme in Info.plist

**Files:**
- Modify: `Vibecast/Vibecast/Info.plist`

The custom scheme is what tells iOS to launch Vibecast when a `vibecast://…` URL is opened. Without this, the Shortcut's `Open URLs` action produces "No app installed to open this URL."

- [ ] **Step 1: Read the current Info.plist**

```bash
cat Vibecast/Vibecast/Info.plist
```

Confirm it has the existing keys (`CFBundleDevelopmentRegion`, `UIBackgroundModes`, etc.) and is a real `<dict>` plist.

- [ ] **Step 2: Add the `CFBundleURLTypes` array**

Edit `Vibecast/Vibecast/Info.plist`. Inside the top-level `<dict>`, alongside the existing keys, add this block (location-agnostic — plist key order doesn't matter, but conventionally place it near other bundle-identity keys):

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>app.vibecast.scheme</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>vibecast</string>
			</array>
		</dict>
	</array>
```

`CFBundleURLName` is a reverse-DNS identifier for the scheme registration; pick `app.vibecast.scheme` to keep it distinct from `CFBundleIdentifier`.

- [ ] **Step 2b: Allow `canOpenURL` to check for Shortcuts.app**

Still in `Vibecast/Vibecast/Info.plist`, add the `LSApplicationQueriesSchemes` array so the wizard's Step 2 can detect whether Shortcuts.app is installed. Without this, `UIApplication.shared.canOpenURL(URL(string: "shortcuts://")!)` returns `false` even on devices that have Shortcuts installed.

```xml
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>shortcuts</string>
	</array>
```

- [ ] **Step 3: Build to verify the plist is well-formed**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`. If the plist is malformed, the build fails with a plutil error before compiling Swift code.

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Info.plist
git commit -m "feat(import): register vibecast:// URL scheme in Info.plist"
```

---

## Task 6: Wire `.onOpenURL` in `VibecastApp`

**Files:**
- Modify: `Vibecast/Vibecast/VibecastApp.swift`

Attach `.onOpenURL` at the scene root so any `vibecast://…` URL gets routed through `VibecastURLHandler` regardless of which view is currently visible.

- [ ] **Step 1: Read `Vibecast/Vibecast/VibecastApp.swift`**

Confirm the existing scene structure — typically:

```swift
WindowGroup {
    SubscriptionsListView()
        .modelContainer(container)
        .environment(\.playerManager, playerManager)
        // …
}
```

- [ ] **Step 2: Add `.onOpenURL` modifier**

Add the modifier to whatever root view is inside `WindowGroup { … }`. Example:

```swift
WindowGroup {
    SubscriptionsListView()
        .modelContainer(container)
        .environment(\.playerManager, playerManager)
        .environment(\.subscriptionManager, subscriptionManager)
        .onOpenURL { url in
            VibecastURLHandler.handle(url, session: .shared)
        }
}
```

Use `.shared` directly — the session is a `@MainActor` singleton so this is safe from the app root.

- [ ] **Step 3: Build to confirm it compiles**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/VibecastApp.swift
git commit -m "feat(import): route .onOpenURL through VibecastURLHandler"
```

---

## Task 7: `ApplePodcastsImportWizard` view

**Files:**
- Create: `Vibecast/Vibecast/Views/ApplePodcastsImportWizard.swift`

The three-step wizard sub-sheet. Reads state from `ApplePodcastsImportSession.shared` + the `@AppStorage` install-acknowledged flag. Writes via `SubscriptionManager.importFeeds`.

- [ ] **Step 1: Create the wizard view**

Create `Vibecast/Vibecast/Views/ApplePodcastsImportWizard.swift`:

```swift
import SwiftUI
import UIKit

/// The three-step Apple Podcasts import wizard, presented as a sub-sheet
/// from `AddPodcastSheet`'s "Import from Apple Podcasts" row.
///
/// State sources:
/// - `@AppStorage` flag `hasOpenedApplePodcastsImportShortcutInstall` — Step 1 ✓
/// - `ApplePodcastsImportSession.shared.pendingFeedURLs + isFresh` — Step 2 ✓
/// - `SubscriptionManager.isImportingFeeds + lastImportSummary` — Step 3 progress/summary
struct ApplePodcastsImportWizard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionManager) private var manager
    @Bindable private var session = ApplePodcastsImportSession.shared

    @AppStorage("hasOpenedApplePodcastsImportShortcutInstall")
    private var hasOpenedInstall: Bool = false

    /// True once an import has completed in this wizard session — drives the
    /// summary row vs. the import-button row.
    @State private var didImport: Bool = false

    /// Replace this with the real iCloud share URL produced at the end of
    /// Task 1. Until then, the install button does nothing useful — but the
    /// rest of the wizard is fully testable in the simulator with a
    /// hand-constructed `vibecast://import-feeds?urls=…` URL pasted via the
    /// simulator's URL-open menu (Device → Open URL).
    private static let iCloudShortcutInstallURL =
        URL(string: "https://www.icloud.com/shortcuts/PLACEHOLDER")!

    private static let runShortcutURL =
        URL(string: "shortcuts://run-shortcut?name=Vibecast%20Import")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    intro
                    stepOne
                    stepTwo
                    stepThree
                }
                .padding(.horizontal, Brand.Layout.rowPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Brand.Color.bg)
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Import from Apple Podcasts")
                        .font(Brand.Font.serifSubtitle())
                        .foregroundStyle(Brand.Color.ink)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(Brand.Font.uiButton())
                        .foregroundStyle(Brand.Color.ink)
                }
            }
            .toolbarBackground(Brand.Color.bg, for: .navigationBar)
        }
    }

    // MARK: - Sections

    private var intro: some View {
        Text("Bring your Apple Podcasts subscriptions into Vibecast in three steps. The first time you do this, you'll install a small Shortcuts shortcut — after that, just run it to sync.")
            .font(Brand.Font.uiBody())
            .foregroundStyle(Brand.Color.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var stepOne: some View {
        stepRow(
            number: 1,
            isChecked: hasOpenedInstall,
            title: "Install Shortcut",
            description: "Add the Vibecast Import shortcut to your Shortcuts app. This only needs to happen once.",
            buttonTitle: "Install Shortcut",
            buttonEnabled: true,
            action: {
                hasOpenedInstall = true
                UIApplication.shared.open(Self.iCloudShortcutInstallURL)
            }
        )
    }

    private var stepTwo: some View {
        let shortcutsInstalled = UIApplication.shared.canOpenURL(URL(string: "shortcuts://")!)
        return stepRow(
            number: 2,
            isChecked: session.pendingFeedURLs != nil && session.isFresh,
            title: shortcutsInstalled ? "Run Shortcut" : "Install Shortcuts.app",
            description: stepTwoDescription(shortcutsInstalled: shortcutsInstalled),
            buttonTitle: shortcutsInstalled ? "Run Shortcut" : "Get Shortcuts on App Store",
            buttonEnabled: hasOpenedInstall,
            action: {
                if shortcutsInstalled {
                    UIApplication.shared.open(Self.runShortcutURL)
                } else {
                    UIApplication.shared.open(Self.shortcutsAppStoreURL)
                }
            }
        )
    }

    private func stepTwoDescription(shortcutsInstalled: Bool) -> String {
        if !shortcutsInstalled {
            return "The Shortcuts app isn't installed on this device. Install it from the App Store to continue."
        }
        if session.pendingFeedURLs != nil && !session.isFresh {
            return "The last run is too old. Open the shortcut and run it again."
        }
        return "Open the shortcut and run it. It reads your Apple Podcasts subscriptions and sends them here."
    }

    private static let shortcutsAppStoreURL =
        URL(string: "https://apps.apple.com/app/shortcuts/id915249334")!

    @ViewBuilder
    private var stepThree: some View {
        let urls = session.pendingFeedURLs
        let isReady = (urls != nil) && session.isFresh
        let importingFeeds = manager?.isImportingFeeds ?? false
        let summary = manager?.lastImportSummary

        if didImport, let summary {
            stepThreeSummary(summary)
        } else if importingFeeds {
            stepThreeProgress(count: urls?.count ?? 0)
        } else {
            stepRow(
                number: 3,
                isChecked: false,
                title: "Import",
                description: stepThreeDescription(urls: urls),
                buttonTitle: stepThreeButtonTitle(urls: urls),
                buttonEnabled: isReady && (urls?.isEmpty == false),
                action: { Task { await runImport() } }
            )
        }
    }

    private func stepThreeDescription(urls: [URL]?) -> String {
        guard let urls else { return "Run the shortcut to see what's ready to import." }
        if urls.isEmpty {
            return "No subscribable podcasts found in your Apple Podcasts library. Your shows may all be Apple Originals, which don't have public RSS feeds."
        }
        return "Found \(urls.count) podcast\(urls.count == 1 ? "" : "s") ready to import."
    }

    private func stepThreeButtonTitle(urls: [URL]?) -> String {
        guard let urls, !urls.isEmpty else { return "Import" }
        return "Import \(urls.count) Podcast\(urls.count == 1 ? "" : "s")"
    }

    private func stepThreeProgress(count: Int) -> some View {
        stepCard {
            stepHeader(number: 3, isChecked: false, title: "Importing")
            ProgressView()
                .controlSize(.regular)
                .padding(.top, 4)
            Text("Subscribing to \(count) podcast\(count == 1 ? "" : "s")…")
                .font(Brand.Font.uiBody())
                .foregroundStyle(Brand.Color.inkSecondary)
        }
    }

    private func stepThreeSummary(_ summary: ImportSummary) -> some View {
        stepCard {
            stepHeader(number: 3, isChecked: true, title: "Imported")
            Text(summaryMessage(summary))
                .font(Brand.Font.uiBody())
                .foregroundStyle(Brand.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done") {
                session.clear()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.Color.ink)
            .padding(.top, 4)
        }
    }

    private func summaryMessage(_ summary: ImportSummary) -> String {
        var pieces: [String] = []
        if summary.succeeded > 0 { pieces.append("Imported \(summary.succeeded)") }
        if summary.alreadySubscribed > 0 { pieces.append("Already subscribed \(summary.alreadySubscribed)") }
        if summary.failed > 0 { pieces.append("Failed \(summary.failed)") }
        if pieces.isEmpty { return "Nothing to import." }
        return pieces.joined(separator: " · ")
    }

    private func runImport() async {
        guard let urls = session.pendingFeedURLs, !urls.isEmpty else { return }
        await manager?.importFeeds(urls)
        didImport = true
    }

    // MARK: - Step row primitives

    private func stepRow(
        number: Int,
        isChecked: Bool,
        title: String,
        description: String,
        buttonTitle: String,
        buttonEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        stepCard {
            stepHeader(number: number, isChecked: isChecked, title: title)
            Text(description)
                .font(Brand.Font.uiBody())
                .foregroundStyle(Brand.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text(buttonTitle)
                    .font(Brand.Font.uiButton())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(buttonEnabled ? Brand.Color.ink : Brand.Color.inkHairline)
                    .foregroundStyle(Brand.Color.paper)
                    .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.inline))
            }
            .buttonStyle(.plain)
            .disabled(!buttonEnabled)
            .padding(.top, 4)
        }
    }

    private func stepHeader(number: Int, isChecked: Bool, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                    .background(Circle().fill(isChecked ? Brand.Color.accent : Brand.Color.paper))
                    .frame(width: 28, height: 28)
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.Color.paper)
                } else {
                    Text("\(number)")
                        .font(Brand.Font.monoEyebrow())
                        .foregroundStyle(Brand.Color.inkSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("STEP \(number)")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkMuted)
                Text(title)
                    .font(Brand.Font.uiTitle())
                    .foregroundStyle(Brand.Color.ink)
            }
            Spacer()
        }
    }

    private func stepCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .background(Brand.Color.paper)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.card)
                .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
        )
    }
}
```

> **Note on `Brand.Font.uiTitle()` and `Brand.Layout.rowPadding` / `Brand.Radius.card` / `Brand.Radius.inline`:** these are referenced consistently across Plan 6 + Plan 7 views. Verify they exist; if a specific helper doesn't, fall back to the closest existing analog (e.g. `Brand.Font.serifSubtitle()` for a step title) — this is the only fuzzy spot in this task and an explicit allowance for "match the codebase's existing patterns."

- [ ] **Step 2: Build to verify the view compiles**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD)' | tail -10
```

Expected: `** BUILD SUCCEEDED **`. Resolve any missing `Brand.*` references by substituting the nearest existing helper (e.g. `Brand.Font.uiTitle()` → `Brand.Font.serifSubtitle()`).

- [ ] **Step 3: Commit**

```bash
git add Vibecast/Vibecast/Views/ApplePodcastsImportWizard.swift
git commit -m "feat(import): ApplePodcastsImportWizard three-step sub-sheet"
```

---

## Task 8: Integrate wizard into `AddPodcastSheet`

**Files:**
- Modify: `Vibecast/Vibecast/Views/AddPodcastSheet.swift`

Adds an "Import from Apple Podcasts" row in the same `safeAreaInset(edge: .top)` region as "Import from File." Tap presents the wizard. Also: bake in the real iCloud share URL captured in Task 1.

- [ ] **Step 1: Read the current `AddPodcastSheet.swift`**

```bash
grep -n "importButton\|safeAreaInset" Vibecast/Vibecast/Views/AddPodcastSheet.swift
```

Find the existing `importButton` definition (~line 168) and the `.safeAreaInset(edge: .top)` block (~line 74) so the new row goes alongside.

- [ ] **Step 2: Add a `@State` flag for wizard presentation**

In `AddPodcastSheet`'s state block (alongside `@State private var showFileImporter: Bool = false`), add:

```swift
@State private var showApplePodcastsWizard: Bool = false
```

- [ ] **Step 3: Add the row and a `.sheet` modifier**

Modify the `safeAreaInset(edge: .top)` block to stack both import buttons. Replace:

```swift
.safeAreaInset(edge: .top) {
    importButton
        .padding(.horizontal, Brand.Layout.rowPadding)
        .padding(.bottom, 8)
        .background(Brand.Color.bg)
}
```

with:

```swift
.safeAreaInset(edge: .top) {
    VStack(spacing: 8) {
        applePodcastsImportButton
        importButton
    }
    .padding(.horizontal, Brand.Layout.rowPadding)
    .padding(.bottom, 8)
    .background(Brand.Color.bg)
}
.sheet(isPresented: $showApplePodcastsWizard) {
    ApplePodcastsImportWizard()
}
```

- [ ] **Step 4: Define `applePodcastsImportButton`**

Add as a sibling of the existing `importButton` computed property:

```swift
private var applePodcastsImportButton: some View {
    Button {
        showApplePodcastsWizard = true
    } label: {
        Label("Import from Apple Podcasts", systemImage: "applelogo")
            .font(Brand.Font.uiButton())
            .foregroundStyle(Brand.Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Brand.Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.inline))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.inline)
                    .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
            )
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 5: Bake the real iCloud share URL**

Open `Vibecast/Vibecast/Views/ApplePodcastsImportWizard.swift`. Find the `iCloudShortcutInstallURL` constant:

```swift
private static let iCloudShortcutInstallURL =
    URL(string: "https://www.icloud.com/shortcuts/PLACEHOLDER")!
```

Replace `PLACEHOLDER` with the actual hash captured in Task 1, Step 4. Save.

If you committed `docs/superpowers/scratch-shortcut-url.txt` in Task 1, delete it now:

```bash
git rm docs/superpowers/scratch-shortcut-url.txt
```

- [ ] **Step 6: Build to verify it compiles**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Vibecast/Vibecast/Views/AddPodcastSheet.swift \
        Vibecast/Vibecast/Views/ApplePodcastsImportWizard.swift
# If the scratch note existed:
# git add docs/superpowers/scratch-shortcut-url.txt
git commit -m "feat(import): wire Apple Podcasts wizard into AddPodcastSheet"
```

---

## Task 9: Auto-present wizard from `SubscriptionsListView`

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`

If the shortcut runs while Vibecast isn't already showing the wizard (e.g. user launches the shortcut from Shortcuts.app directly), `ApplePodcastsImportSession.shared.shouldPresentWizard` flips true on URL receipt. `SubscriptionsListView` observes that and auto-presents `AddPodcastSheet` (which itself auto-opens the wizard).

We achieve the auto-deep-link to the wizard by: when the session's `shouldPresentWizard` is true, present `AddPodcastSheet` AND set its internal `showApplePodcastsWizard` to true via a small `init`-time prop or an `@AppStorage` shim. The simplest path: have `AddPodcastSheet` itself check `ApplePodcastsImportSession.shared.shouldPresentWizard` on appear and auto-present its wizard sheet.

- [ ] **Step 1: Auto-open the wizard inside `AddPodcastSheet`**

Edit `Vibecast/Vibecast/Views/AddPodcastSheet.swift`. Inside the main `NavigationStack`'s `.navigationBarTitleDisplayMode(...)` modifier chain (or anywhere on the root view), add:

```swift
.onAppear {
    if ApplePodcastsImportSession.shared.shouldPresentWizard {
        showApplePodcastsWizard = true
        ApplePodcastsImportSession.shared.shouldPresentWizard = false
    }
}
```

This handles the case where `AddPodcastSheet` opens *because* a URL arrived (Step 2 below) — the wizard auto-pops once the sheet renders.

- [ ] **Step 2: Auto-present `AddPodcastSheet` on URL receipt**

In `Vibecast/Vibecast/Views/SubscriptionsListView.swift`, find the existing `.sheet(isPresented: $showAddSheet) { AddPodcastSheet() }` modifier. Add a sibling `.onReceive`/`.onChange` to drive `showAddSheet = true` when the session's flag flips:

```swift
@Bindable private var applePodcastsSession = ApplePodcastsImportSession.shared
```

(add alongside other `@State` / `@Bindable` declarations at the top of `SubscriptionsListView`)

Then add this modifier to the body (anywhere on the root `NavigationStack` is fine):

```swift
.onChange(of: applePodcastsSession.shouldPresentWizard) { _, newValue in
    if newValue { showAddSheet = true }
}
```

Note: `AddPodcastSheet.onAppear` (Step 1) resets the flag to false once it picks it up, so the toggle is one-shot.

- [ ] **Step 3: Build**

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E '(error:|BUILD)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Views/SubscriptionsListView.swift \
        Vibecast/Vibecast/Views/AddPodcastSheet.swift
git commit -m "feat(import): auto-present Apple Podcasts wizard on URL receipt"
```

---

## Task 10: End-to-end manual verification

**Files:** none.

The Shortcuts → URL → app → import wiring cannot be unit-tested. This task walks through the user-visible flow on a real device (or the simulator with hand-typed URLs).

- [ ] **Step 1: Install the app on a device with Apple Podcasts subscriptions**

Build to a physical iPhone running iOS 17+ (Xcode → Run on device, or wait for TestFlight after a push). The simulator works for everything except `Get Podcasts from Library` — that action returns an empty list inside the simulator.

- [ ] **Step 2: Verify Step 1 (Install)**

1. Open Vibecast → tap `+` (Add Podcast) → "Import from Apple Podcasts."
2. Wizard opens. Step 1 unchecked.
3. Tap "Install Shortcut." Vibecast hands off to Safari → iCloud Shortcuts page → "Get Shortcut."
4. Tap "Add Shortcut" in the install dialog.
5. Return to Vibecast. Re-open the wizard.
6. **Verify:** Step 1 now shows ✓. Step 2's "Run Shortcut" button is enabled.

- [ ] **Step 3: Verify Step 2 (Run)**

1. With wizard open, tap "Run Shortcut."
2. iOS opens Shortcuts.app, runs "Vibecast Import," then re-foregrounds Vibecast.
3. **Verify:** Vibecast re-foregrounds with the wizard still visible. Step 2 shows ✓. Step 3 shows "Found N podcasts ready to import" where N matches your Apple Podcasts subscription count (excluding Apple Originals).

- [ ] **Step 4: Verify Step 3 (Import)**

1. Tap "Import N Podcasts."
2. **Verify:** progress row shows "Subscribing to N podcasts…" with a spinner.
3. After ~N seconds (one network round-trip per feed), summary appears: "Imported X · Already subscribed Y · Failed Z."
4. Tap "Done." Sheet dismisses.
5. **Verify:** subscriptions list now shows all the imported podcasts.

- [ ] **Step 5: Verify auto-present**

1. Close the wizard. Return to Vibecast's home screen.
2. Switch to Shortcuts.app. Run "Vibecast Import" directly from there.
3. **Verify:** Vibecast foregrounds. `AddPodcastSheet` auto-presents. The wizard auto-pops on top of it with Step 3 ready to import (Step 1 and Step 2 both ✓).

- [ ] **Step 6: Verify already-subscribed re-run**

1. With everything imported, run the shortcut again.
2. **Verify:** Step 3 summary reads "Already subscribed N" with `succeeded: 0`.

- [ ] **Step 7: Verify stale-payload behavior**

1. Run the shortcut. Wait 6 minutes (set a timer) without tapping Import.
2. Re-open the wizard.
3. **Verify:** Step 2's description changes to "The last run is too old. Open the shortcut and run it again." Step 3 is disabled.
4. Tap "Run Shortcut" — fresh run brings it back to ✓.

- [ ] **Step 8: Verify the re-install recovery path**

1. In Shortcuts.app, delete "Vibecast Import."
2. In Vibecast wizard, tap "Run Shortcut." iOS shows "Couldn't find shortcut."
3. Tap "Install Shortcut" again. Re-install completes. Re-run works.

- [ ] **Step 9: Verify the empty-library case (if possible)**

If you have an iCloud account with **only Apple Originals subscriptions** (rare — typically requires a fresh Apple ID), run the shortcut.

**Verify:** Step 3 shows "No subscribable podcasts found in your Apple Podcasts library. Your shows may all be Apple Originals…" with no Import button.

If you can't reproduce this case, skip — covered by the URL handler unit test `test_handle_emptyList_stillWritesEmptyArray`.

- [ ] **Step 10: Final smoke pass**

Run the full test suite once more after manual verification — to confirm no regressions in audio playback, OPML import, search-subscribe, or other paths:

```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test 2>&1 | grep -E '(TEST SUCCEEDED|TEST FAILED|tests? failed)' | head -3
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 11: Hand back to user**

Report verification results. User decides whether to push to `main` (per the "no push until sign-off on local test" feedback rule) — this is the trigger for TestFlight CI to build.
