# Vibecast MVP — Plan 4: OPML Import, Refresh & Sample-Data Deprecation

**One-sentence pitch:** Close out the MVP by adding OPML bulk-import, pull-to-refresh + detail-open refresh, and removing the synthetic sample data so first-launch users see a real empty state — plus consolidate the SwiftData `ModelContext` plumbing while we're touching the relevant files.

**Plan position:** 4 of 4 in the MVP roadmap. Plan 1 shipped foundation + core UI; Plan 2 shipped the audio engine + player UI; Plan 3 shipped iTunes search, subscribe, and real-feed-backed episodes. Plan 4 closes the user-facing loop. The accumulated cosmetic-polish followups from Plan 2 and Plan 3 reviews are explicitly **deferred to Plan 5** — they don't block the MVP. The overarching MVP design is at `docs/superpowers/specs/2026-04-19-vibecast-mvp-design.md`.

---

## Goals

- A user can import their existing podcast subscriptions in bulk via an OPML file (the standard Apple Podcasts / PocketCasts / Overcast export format).
- The user can pull down on the subscriptions list to refresh every subscribed podcast's RSS feed.
- Opening a podcast detail sheet refreshes that podcast's feed (debounced — no-op if `lastFetchedAt` is < 60 seconds old).
- First launch shows an empty subscriptions list with a clear next-step hint, not synthetic demo data.
- The four `ModelContext` instances created during Plan 1–3 collapse to a single shared `container.mainContext` to remove the cross-context staleness footgun.

## Non-goals

- "Last refreshed N min ago" timestamps, refresh-progress badges, or per-feed failure indicators on the list — Plan 5+ polish.
- Background refresh while the app is closed — out of scope for the MVP.
- Importing playback state from another app — the MVP spec explicitly excludes this.
- iCloud sync — out of scope for the MVP.
- Removing existing testers' already-seeded sample podcasts on update — surprise data loss is bad UX even when the data is synthetic. The empty-state hint only appears when the user is actually empty.
- Migrating the deferred 14 polish items from Plan 2 + Plan 3 reviews — Plan 5.

---

## Architecture

Plan 4 extends Plan 3's `Discovery/` layer rather than introducing new layers. The pattern is: small `@MainActor` services behind protocols, `SubscriptionManager` is the only piece that touches the (now shared) `ModelContext`, OPML and refresh flows reuse the existing `FeedFetcher` and `RSSParser`.

```
SubscriptionsListView
  ├─ pull-to-refresh ────────── SubscriptionManager.refreshAll
  │                                ├─► (per podcast) FeedFetcher.fetch
  │                                │                     │
  │                                │                     └─► RSSParser → ParsedFeed
  │                                │
  │                                └─► merge episodes by audioURL into existing Podcast,
  │                                    bump lastFetchedAt
  │
  ├─ tap "+" ──────────────────► AddPodcastSheet
  │                                ├─ search field (Plan 3)
  │                                │
  │                                └─ "Import from File" button (NEW)
  │                                     ├─► .fileImporter (.opml + .xml)
  │                                     │
  │                                     └─► SubscriptionManager.importOPML(data)
  │                                            ├─► OPMLImporter.extractFeedURLs
  │                                            └─► (per URL, sequential)
  │                                                  SubscriptionManager.subscribe(to: URL)
  │                                                    ├─► FeedFetcher.fetch
  │                                                    └─► insert Podcast + Episodes (fail-first)
  │
  └─ tap a row body ──────────► PodcastDetailView .task
                                   └─► SubscriptionManager.refresh(podcast)
                                         (no-op if lastFetchedAt < 60s)
```

### Files

```
Vibecast/Vibecast/Discovery/
└── OPMLImporter.swift                                — NEW: protocol + StandardOPMLImporter

Vibecast/VibecastTests/Fixtures/
├── opml-apple-podcasts.xml                           — NEW: realistic Apple Podcasts export
└── opml-malformed.xml                                — NEW: throw-path fixture

Vibecast/VibecastTests/
└── OPMLImporterTests.swift                           — NEW: 4 tests

Vibecast/Vibecast/Discovery/SubscriptionManager.swift — MODIFY: add subscribe(to: feedURL),
                                                         importOPML(from:), refreshAll(),
                                                         refresh(_:), isImportingOPML,
                                                         lastImportSummary
Vibecast/VibecastTests/SubscriptionManagerTests.swift — MODIFY: ~10 new tests
Vibecast/Vibecast/VibecastApp.swift                   — MODIFY: pass mainContext, drop seedIfNeeded
Vibecast/Vibecast/Views/SubscriptionsListView.swift   — MODIFY: .refreshable, empty state
Vibecast/Vibecast/Views/AddPodcastSheet.swift         — MODIFY: Import button + .fileImporter + alert
Vibecast/Vibecast/Views/PodcastDetailView.swift       — MODIFY: refresh on .task
```

The `Discovery/` folder grows by exactly one file. The `SampleData.swift` file stays — only the launch-time `seedIfNeeded` call goes away. Previews and tests still depend on `SampleData.container`.

---

## Service Contracts

### `OPMLImporter`

```swift
@MainActor
protocol OPMLImporter {
    func extractFeedURLs(from data: Data) throws -> [URL]
}

enum OPMLImportError: Error {
    case malformed
}

final class StandardOPMLImporter: NSObject, OPMLImporter, XMLParserDelegate {
    func extractFeedURLs(from data: Data) throws -> [URL]
    // SAX delegate walks <outline> elements recursively. For each leaf with
    // an xmlUrl attribute, parse as URL and accumulate. Apple Podcasts wraps
    // subscriptions inside category outlines (<outline text="Tech"><outline xmlUrl=.../></outline>);
    // we ignore the categories. Within-file duplicates de-duped. Invalid
    // xmlUrl strings silently skipped. Throws OPMLImportError.malformed
    // if XMLParser.parse() returns false.
}
```

### `SubscriptionManager` extensions

```swift
@Observable @MainActor
final class SubscriptionManager {
    // Existing (Plan 3): inFlightSubscriptions, failedSubscribes, search,
    // isSubscribed, subscribe(to: PodcastSearchResult)

    private(set) var lastImportSummary: ImportSummary?
    private(set) var isImportingOPML: Bool = false

    @ObservationIgnored private let importer: OPMLImporter   // NEW dependency

    init(searcher: PodcastSearchService,
         fetcher: FeedFetcher,
         importer: OPMLImporter,
         modelContext: ModelContext)

    /// OPML path. Same fail-first behavior as subscribe(to: PodcastSearchResult)
    /// — if the RSS fetch fails, no Podcast row is inserted. Title/author/artwork
    /// come from the parsed RSS (no iTunes metadata available).
    func subscribe(to feedURL: URL) async

    /// Parses OPML data, deduplicates within-file, iterates subscribe(to: URL)
    /// sequentially, tallies an ImportSummary, exposes via lastImportSummary.
    /// Sets isImportingOPML true for the duration. Throws if the OPML data
    /// itself is malformed (separate from per-feed failures).
    func importOPML(from data: Data) async throws

    /// Pull-to-refresh on the list. Iterates all subscribed podcasts
    /// sequentially. Per-podcast errors are swallowed. Updates lastFetchedAt
    /// only on per-podcast success.
    func refreshAll() async

    /// Detail-open refresh. No-op if podcast.lastFetchedAt is < 60s old
    /// (RefreshDebounceSeconds constant).
    func refresh(_ podcast: Podcast) async
}

struct ImportSummary {
    let attempted: Int
    let succeeded: Int
    let alreadySubscribed: Int
    let failed: Int
}
```

### Episode merge logic (used by `subscribe(to: feedURL)` and `refresh(_:)`)

```
For each ParsedEpisode in feed.episodes:
  if existing Episode where audioURL matches:
    update existing.title, .descriptionText, .durationSeconds, .publishDate, .isExplicit
    (preserve playbackPosition + listenedStatus — user state never touched)
  else:
    insert new Episode

After loop: podcast.lastFetchedAt = .now
```

No deletion. Episodes that fall off the public RSS feed remain in local storage with their playback state intact. The 50-cap from `RSSParser` already bounds growth from any single fetch.

### Multi-context consolidation

`VibecastApp.init` simplifies:

```swift
init() {
    let c: ModelContainer
    do { c = try ModelContainer(for: Podcast.self, Episode.self) }
    catch { fatalError("Failed to create ModelContainer: \(error)") }
    container = c

    // No more SampleData.seedIfNeeded — Plan 4 ships an empty first launch.
    // Both managers share the views' main context, eliminating the cross-
    // context staleness footgun from Plan 3.
    let player: PlayerManager
    let subs: SubscriptionManager
    (player, subs) = MainActor.assumeIsolated {
        let p = PlayerManager(engine: AVPlayerAudioEngine(), modelContext: c.mainContext)
        let s = SubscriptionManager(
            searcher: iTunesSearchService(),
            fetcher: URLSessionFeedFetcher(),
            importer: StandardOPMLImporter(),
            modelContext: c.mainContext
        )
        return (p, s)
    }
    _playerManager = State(initialValue: player)
    _subscriptionManager = State(initialValue: subs)
}
```

---

## UI Changes

### `SubscriptionsListView`

Add `.refreshable` to the `List`:

```swift
List { ForEach(vm.podcasts) { ... } }
    .listStyle(.plain)
    .refreshable {
        await subscriptionManager?.refreshAll()
        viewModel?.fetch()  // pick up newly inserted episodes for existing rows;
                            // existing rows themselves don't change, but the row
                            // widget's "latest episode" widget needs the newest.
    }
```

When `vm.podcasts.isEmpty`, replace the entire `List` with:

```swift
ContentUnavailableView(
    "No podcasts yet",
    systemImage: "antenna.radiowaves.left.and.right",
    description: Text("Tap + to search for podcasts or import an OPML file.")
)
```

The `+` toolbar button stays visible — that's the user's path forward. Existing sheets (`PodcastDetailView`, `FullScreenPlayerView`, `AddPodcastSheet`) continue to be presented from the same modifiers as today.

The Plan 3 sheet-dismiss `.onChange(of: showAddPodcast)` refetch hook stays intact — it now also picks up OPML imports.

### `PodcastDetailView`

Extend the existing `.task`:

```swift
.task {
    if viewModel == nil {
        viewModel = PodcastDetailViewModel(podcast: podcast)
    }
    await subscriptionManager?.refresh(podcast)
    viewModel?.refetch()  // new method on PodcastDetailViewModel; pulls fresh episodes
}
```

`refresh(_:)` self-debounces (60s `lastFetchedAt` check), so rapidly entering/leaving the detail sheet doesn't spam the network.

### `AddPodcastSheet`

Add an "Import from File" button in a `.safeAreaInset(edge: .top)` strip below the navigation bar's search drawer:

```swift
Button {
    showFileImporter = true
} label: {
    Label("Import from File", systemImage: "square.and.arrow.down")
}
.buttonStyle(.bordered)
.disabled(manager.isImportingOPML)
```

System file picker via `.fileImporter`:

```swift
.fileImporter(
    isPresented: $showFileImporter,
    allowedContentTypes: [UTType(filenameExtension: "opml") ?? .xml, .xml],
    allowsMultipleSelection: false
) { result in
    Task {
        guard case let .success(urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
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
```

While `manager.isImportingOPML == true`, the results area shows a centered `ProgressView` plus "Importing podcasts…" text (replacing the search results / idle / error states for the duration).

Alerts:
- **Success summary** — "Imported X of Y podcasts." plus follow-on lines for `alreadySubscribed` and `failed` if either is > 0. Auto-dismisses the sheet on tap.
- **Failure** — "Couldn't parse OPML file. Make sure it's a valid OPML export."

The Plan 3 search-flow UI (idle/searching/results/empty/error states) remains unchanged.

### iOS file-importer permissions

Files chosen via `.fileImporter` arrive as security-scoped URLs. The snippet above wraps reads in `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`. No `Info.plist` entries needed.

---

## Sample-Data Deprecation

Three changes:

1. **`VibecastApp.init`** drops the `SampleData.seedIfNeeded` call entirely. The first-launch UI is now whatever `vm.podcasts` resolves to — empty for new users.

2. **`SampleData.swift`** stays. `SampleData.container` is still used by SwiftUI previews and unit tests. `SampleData.testAudioURL` stays for any future audio-engine integration tests. The `insertSampleData(into:)` function stays — it's called by `SampleData.container`'s setup. Only the `seededDefaultsKey` static constant becomes orphaned (no longer used in production code, but harmless to leave defined since `seedIfNeeded(into:)` may still be useful in tests).

3. **`UserDefaults` flag** (`"didSeedSampleData"`) is intentionally **not** cleaned up. Existing testers' defaults carry the orphaned key forever — harmless, no conflict with anything else. Cleaning up would mean dead code we'd want to remove later. Apps drop orphaned `UserDefaults` keys all the time.

**Existing-tester migration:** anyone who has the seeded sample podcasts on disk from Plan 2 or Plan 3 keeps them after Plan 4 ships. The new behavior is "no auto-seed for users who have never launched before." The empty-state hint only appears when `vm.podcasts.isEmpty` is genuinely true.

---

## Refresh Strategy (recap)

| Trigger | Effect | Debounce |
|---|---|---|
| Pull-to-refresh on list | `refreshAll()` — re-fetch every subscription, merge by audioURL | None (user-initiated; spinner is the indicator) |
| Open podcast detail | `refresh(_ podcast:)` — single fetch | 60s `lastFetchedAt` check |
| Tap `+` on a search result | `subscribe(to: PodcastSearchResult)` — initial fetch only (Plan 3) | n/a |
| OPML import | `subscribe(to: feedURL)` per imported URL | n/a |

No automatic background refresh. No on-launch refresh. No "Last refreshed N min ago" indicator (Plan 5+).

---

## Error Handling

| Failure | UX | Recovery |
|---|---|---|
| OPML file invalid (malformed XML) | Alert: "Couldn't parse OPML file. Make sure it's a valid OPML export." | User picks another file |
| OPML file unreadable (system error) | Same alert | User retries |
| OPML feed URL fails RSS fetch | Counted in `ImportSummary.failed`; row not inserted (fail-first). Final alert summarizes "X imported, Y failed." | None automatic |
| OPML feed already subscribed | Counted in `ImportSummary.alreadySubscribed`; silently skipped | n/a |
| `refreshAll` fails for a single podcast | Per-podcast error swallowed; refresh continues for others | Pull-to-refresh again |
| `refresh(_:)` fails on detail open | Silent — keeps existing episodes in place | Pull-to-refresh from list |
| User cancels file picker | `.fileImporter` handles itself; no alert | n/a |

The "no UI signal on per-podcast refresh failure" is intentional. Pull-to-refresh's spinner already tells the user something happened, existing episodes still work, and adding a per-row failure badge is Plan 5+ polish territory.

---

## Testing Strategy

**Bundle-resource fixtures** (same pattern as Plan 3):

```
Vibecast/VibecastTests/Fixtures/
├── opml-apple-podcasts.xml      — realistic Apple Podcasts export with category outlines
└── opml-malformed.xml           — invalid XML for the throw path
```

**`OPMLImporterTests.swift`** (4 tests):
- `test_extractFeedURLs_flattensCategoryOutlines` — Apple Podcasts shape with nested `<outline text="Tech"><outline xmlUrl=...></outline></outline>` flattens to a flat URL list
- `test_extractFeedURLs_dedupesWithinFile` — same `xmlUrl` in two categories returns once
- `test_extractFeedURLs_skipsInvalidURLs` — outlines with non-URL `xmlUrl` strings silently dropped
- `test_extractFeedURLs_throwsOnMalformedXML` — invalid XML produces `OPMLImportError.malformed`

**`SubscriptionManagerTests.swift`** extensions (11 tests):

| Test | Behavior pinned |
|---|---|
| `test_subscribeFeedURL_insertsRowOnSuccess` | Bare-URL path creates `Podcast` row with parsed RSS metadata (title/author/artwork) |
| `test_subscribeFeedURL_skipsRowOnFetchFailure` | Same fail-first contract as the search path |
| `test_subscribeFeedURL_dedupesByFeedURL` | Already-subscribed feed URL is a no-op |
| `test_importOPML_addsSucceeded_skipsAlreadySubscribed` | Tally `succeeded` and `alreadySubscribed` correctly |
| `test_importOPML_tallisFailedSubscribes` | One feed fails, others succeed → `failed: 1` |
| `test_importOPML_setsLastImportSummary` | `lastImportSummary` populated after run |
| `test_importOPML_throwsOnMalformedFile` | Importer's `OPMLImportError.malformed` propagates to caller |
| `test_refreshAll_iteratesAllSubscribedPodcasts` | Mock fetcher invoked once per existing podcast |
| `test_refreshAll_mergesEpisodesByAudioURL` | Existing episode with new metadata gets updated; new episodes inserted; user state on existing preserved |
| `test_refresh_skipsWhenLastFetchedAtIsRecent` | `lastFetchedAt` < 60s old → no-op (mock fetcher not invoked) |
| `test_refresh_updatesLastFetchedAtOnSuccess` | After a successful fetch, `lastFetchedAt` is bumped |

**Total new tests for Plan 4:** 15 (4 OPML + 11 manager). Project lands at ~73 tests total after Plan 4.

**`MockOPMLImporter`** added alongside the existing `MockSearchService` and `MockFeedFetcher` test doubles.

**No XCUITests** — the simulator manual-verification step is run by the user, same as Plans 1–3.

---

## Manual Verification

To be expanded into a step-by-step matrix in the implementation plan. Coverage:

1. Cold launch with no subscriptions → empty-state appears
2. Subscribe via search → row appears, episodes populate (Plan 3 baseline)
3. Pull-to-refresh on the list → spinner, completes, list updated
4. Open a podcast detail → no-op due to debounce (just-subscribed); back out, wait 60s, re-open → fetch fires (subtle, can verify via logs or temporary print)
5. Tap `+`, "Import from File", pick a sample OPML file → progress indicator → summary alert with counts → new podcasts in list with episodes
6. OPML with one bad feed URL → summary shows "X imported, 1 failed"
7. Quit + relaunch → all subscriptions persist with episodes

Note: the user will need to provide or generate a sample OPML file for step 5. The plan will include instructions on creating one (Apple Podcasts → Settings → Subscriptions → Export, or hand-craft).

---

## Followups Explicitly Deferred to Plan 5

These are tracked as task-list items and addressed in a separate brainstorming + plan session:

- Mid-file `import SwiftUI` in `PlayerManager.swift` and `SubscriptionManager.swift` — split env-keys into separate files
- Swift 6 `nonisolated(unsafe) static let defaultValue = nil` on `PlayerManagerKey` and `SubscriptionManagerKey`
- `FullScreenPlayerView` volume slider — bind directly to `player.volume`, drop the `@State` mirror
- Shared `format(_:)` time helper for `MiniPlayerBar` and `FullScreenPlayerView`
- `handlePlaybackEnd` duration mismatch (#28)
- HTTP status validation in `iTunesSearchService` and `URLSessionFeedFetcher` (#42)
- 44pt tap targets + accessibility labels on `SearchResultRow` and `PlayControlView` (#43)
- `RSSParser` not reusable on second `parse()` call
- Replace `try? modelContext.save()` swallows with `Logger`
- Auto-clear Task race in `failedSubscribes` (5s timer can wipe a fresh failure)
- `failedSubscribes` leak when `isSubscribed` early-return path is hit
- `AddPodcastSheet.runSearch` `Task.checkCancellation()` after the `await`
- `SearchResultRow` `#Preview` missing the `isFailed: true` row

Plan 4's opportunistic cleanups: any of the above that fall in a file Plan 4 modifies anyway are fair game for inline fixes. Specifically:
- Multi-`ModelContext` consolidation **is** in Plan 4 (architectural prerequisite for shared-context refresh semantics).
- The `import SwiftUI` mid-file in `SubscriptionManager.swift` is fair game while we're modifying that file for OPML/refresh; the implementation plan will include splitting it into a sibling `Discovery/SubscriptionManager+Environment.swift` file.

---

## Success Criteria

- [x] User can import an OPML file and see the contained subscriptions appear in the list with real episodes
- [x] User can pull down on the subscriptions list to refresh every subscription's RSS feed
- [x] Opening a podcast detail re-fetches its RSS feed (debounced 60s)
- [x] First-launch user sees an empty subscriptions list with a clear hint, not synthetic demo data
- [x] All four `ModelContext` instances from Plans 1–3 collapse to a single shared `mainContext`
- [x] Plan 1, 2, 3 features (reorder, swipe, audio playback, mini-player, full-screen player, search-and-subscribe) continue to work end-to-end
- [x] All new code is covered by unit tests using bundled fixtures; no live network calls in test runs
