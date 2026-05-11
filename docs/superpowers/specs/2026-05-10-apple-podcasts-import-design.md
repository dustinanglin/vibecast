# Apple Podcasts Import via Shortcuts — Design Spec

## Goal

Give a user migrating from Apple Podcasts a one-tap path to bulk-subscribe all their existing Apple Podcasts shows into Vibecast, without requiring a Mac, a manually-built shortcut, or per-podcast sharing.

## Background

iOS has no public API that lets a third-party app enumerate another app's data. Apple Podcasts subscriptions live in `MTLibrary.sqlite` inside Apple Podcasts' own sandboxed group container (`243LU875E5.groups.com.apple.podcasts`), inaccessible to Vibecast.

The iOS **Shortcuts app** bridges this gap. Its built-in `Get Podcasts from Library` action returns the user's full Apple Podcasts subscription list, including each show's RSS Feed URL property. A shortcut can then format those URLs and hand them to a third-party app via that app's custom URL scheme.

Vibecast already accepts a list of feed URLs via the OPML import path implemented in Plan 4 (`SubscriptionManager.subscribe(to: URL)` plus the `ImportSummary` toast). This feature reuses that import primitive — the new work is the bridge from Apple Podcasts → Shortcuts → URL scheme → existing subscribe path.

## Scope

### In scope

- **Hosted shortcut**: a published shortcut, "Vibecast Import," distributed as an iCloud share link. Logic: `Get Podcasts from Library` → iterate, extract each podcast's Feed URL → join non-empty URLs with newlines → URL-encode → `Open URL: vibecast://import-feeds?urls=<encoded>`.
- **Custom URL scheme**: register `vibecast://` in `Info.plist`. Handle `vibecast://import-feeds?urls=<newline-separated-urlencoded-list>` via SwiftUI's `.onOpenURL` at the app root.
- **URL handler component**: parse the `urls` query parameter, split on newline, validate as `URL`s, dedupe, dispatch through `SubscriptionManager.subscribe(to: URL)` per feed. Reuses the existing `ImportSummary` tally + toast.
- **`AddPodcastSheet` row**: "Import from Apple Podcasts" affordance sits alongside the existing "Import from File" (OPML) row. Tapping it presents a dedicated wizard sub-sheet rather than directly launching the shortcut.
- **Wizard sub-sheet** (`ApplePodcastsImportWizard`): walks the user through three labeled steps with per-step ✓ status:
  - **Step 1 — Install Shortcut**: explains what the shortcut does and why; "Install Shortcut" button opens the iCloud share URL. Marked ✓ once the install URL has been opened at least once (`@AppStorage` flag).
  - **Step 2 — Run Shortcut**: "Open Shortcut" button deep-links to `shortcuts://run-shortcut?name=Vibecast%20Import`. Marked ✓ once Vibecast has received a `vibecast://import-feeds?urls=…` URL within the current session's freshness window.
  - **Step 3 — Import**: enabled only when Step 2 is ✓. Shows "Ready to import N podcasts" with a primary "Import N Podcasts" button. Tap runs the subscribe loop; the wizard transitions to an in-progress state with a count, then to a success summary ("Imported N · Already subscribed M · Failed F") before dismissing.
- **Pending-import session** (`ApplePodcastsImportSession`, `@Observable`): in-memory singleton holding the `pendingFeedURLs: [URL]?` and `receivedAt: Date?` from the most recent shortcut run. The URL handler populates it; the wizard observes it for Step 2/3 state. Treated as stale after 5 minutes — older payloads trigger "Re-run the shortcut" copy on Step 2 rather than offering the Import button.
- **Auto-present on URL receipt**: if Vibecast receives `vibecast://import-feeds` while the wizard isn't already visible (e.g. the user ran the shortcut from Shortcuts.app directly), `SubscriptionsListView` presents `AddPodcastSheet` → wizard auto-deep-linked to Step 3. Same code path as when the user navigated there manually; the only difference is the trigger.
- **Resilient fallback**: if `shortcuts://run-shortcut` fails (shortcut deleted from user's library), iOS shows its own "couldn't find shortcut" alert. The wizard's Step 1 affordance remains the recovery path — tapping it always re-opens the iCloud share URL.
- **Tests**: URL parsing happy-path and malformed-input cases. The Shortcuts → URL → app → import wiring is verified manually since Shortcuts isn't simulated in CI.

### Out of scope (explicit)

- **Auto-vibing on import** — imported podcasts go into the All library only. The user tags them into vibes afterward. Same posture as OPML import.
- **Title preview in Step 3** — the wizard shows a count of incoming podcasts, not their titles. We'd need to fetch RSS per feed to resolve titles, which is exactly the work `importFeeds` does, and doing it twice (preview then import) wastes a round-trip. v2 polish if users request it.
- **Apple-Originals / paid Apple Podcasts subscriptions** — shows that have no public RSS Feed URL (Apple-exclusive content). The shortcut filters these out by skipping podcasts where `Feed URL` is empty. Vibecast never sees them.
- **Two-way sync** — this is one-shot import, not ongoing mirroring of Apple Podcasts subscriptions. Re-running the shortcut later re-imports any new subscriptions; the dedupe layer in `subscribe(to:)` handles already-present shows.
- **Auto-detection of "shortcut is installed"** — iOS provides no API to inspect another app's shortcut library. We track Step 1's ✓ via UserDefaults as a "user-acknowledged" signal, not a true install check.
- **Background/silent import** — the user must explicitly tap "Import N Podcasts" in Step 3. We do not auto-import on URL receipt even when the wizard isn't open — auto-presenting the wizard is the strongest action we take without confirmation.
- **Persisted payload across app launches** — `pendingFeedURLs` lives in memory only. If the app is killed between Step 2 and Step 3, the user re-runs the shortcut. Persisting payloads to disk would muddy the 5-minute freshness model and add storage we'd need to clean up.
- **Other URL scheme actions** — `vibecast://` is reserved for future deep links but this plan only ships `import-feeds`. We do not enumerate `vibecast://play/<episode-id>` or similar in this spec.
- **Universal Links** — not needed; we're not handling web URLs.
- **macOS helper script** — superseded by the Shortcuts approach.

## Architecture

Four units, each with one responsibility and a narrow interface to the next.

### 1. The shortcut (iCloud-hosted)

Built once in the Shortcuts app, exported to iCloud, share URL captured at implementation time and baked into a Swift constant.

Logic (sketched in pseudocode; final form built in the Shortcuts editor):

```
podcasts := Get Podcasts from Library
urls := empty text
Repeat with each podcast in podcasts:
    feed := Feed URL of podcast
    If feed is not empty:
        Add (feed + newline) to urls
encoded := URL-encode urls
Open URLs: "vibecast://import-feeds?urls=" + encoded
```

**Why this shape:** the only thing Vibecast needs is the list of feed URLs. We don't need OPML XML — the per-feed RSS subscribe path can take a bare URL. Keeping the payload minimal (newline-joined URLs) avoids URL-length limits at any plausible library size (50 feeds × ~80 chars ≈ 4 KB, well within iOS's 64 KB practical URL handling ceiling).

**Maintenance:** the iCloud share URL may rot over time (if Apple changes their sharing scheme or the shortcut needs an update). The Swift constant lives in one place so re-publishing is a one-line change + app-update push.

### 2. URL scheme handler

A new `VibecastURLHandler` (or co-located switch inside `VibecastApp.swift`) that:

1. Receives the `URL` from SwiftUI `.onOpenURL`.
2. Switches on `url.host` (e.g. `import-feeds`).
3. For `import-feeds`: parses `URLComponents`, reads `queryItems["urls"]`, splits on newline, maps each line to `URL?`, filters out malformed and duplicates.
4. Hands the resulting `[URL]` to `SubscriptionManager.importFeeds(_:)` (new) — which internally iterates `subscribe(to: URL)`, tallies into an `ImportSummary`, and surfaces a toast through the existing `lastImportSummary` channel.

Registration in `Info.plist` adds:

```
CFBundleURLTypes:
  - CFBundleURLName: app.vibecast.scheme
    CFBundleURLSchemes: [vibecast]
```

Identical pattern to the existing OPML pickup path — same dedupe, same per-feed failure swallow, same `ImportSummary` shape. The only new public surface is `importFeeds(_:)` on `SubscriptionManager`.

### 3. `AddPodcastSheet` UI + wizard sub-sheet

A new row, "Import from Apple Podcasts," matching the layout of the existing "Import from File" row. Tapping it presents `ApplePodcastsImportWizard` as a sub-sheet.

The wizard renders three vertically-stacked steps, each with a leading status indicator (empty circle → ✓), a one-line title, a short description, and a primary action button.

**Step 1 — Install Shortcut**

- Description: "Add the Vibecast Import shortcut to your Shortcuts app. This only needs to happen once."
- Button: "Install Shortcut" → `UIApplication.shared.open(iCloudShareURL)`.
- ✓ state: when `@AppStorage("hasOpenedApplePodcastsImportShortcutInstall") == true`. Set the flag immediately on tap; we can't observe the actual install, but we use this as a "user has acknowledged Step 1" signal so Step 2 becomes enabled. Step 1 button remains tappable post-✓ for the re-install case.

**Step 2 — Run Shortcut**

- Description: "Open the shortcut and run it. It reads your Apple Podcasts subscriptions and sends them here."
- Button: "Run Shortcut" → `UIApplication.shared.open(URL(string: "shortcuts://run-shortcut?name=Vibecast%20Import")!)`. Disabled until Step 1 ✓.
- ✓ state: when `ApplePodcastsImportSession.shared.pendingFeedURLs` is non-nil AND `receivedAt` is within the freshness window (5 minutes).

**Step 3 — Import**

- Description: dynamic based on session state.
  - No payload received: "Run the shortcut to see what's ready to import."
  - Payload received: "Found N podcasts ready to import. {M of these are already in your library.}"
- Button: "Import N Podcasts" → calls `SubscriptionManager.importFeeds(_:)`. Disabled until Step 2 ✓.
- During import: button replaced by a progress row showing "Importing… (k of N)". A bool on `SubscriptionManager` (`isImportingFeeds`) drives this; mirrors `isImportingOPML`.
- On completion: replaced by a summary row ("Imported 23 · Already subscribed 4 · Failed 1") and a "Done" button that dismisses both sheets.

**Layout / styling**

Follows the project's existing editorial language: paper-warm background, Inter-medium for titles, Inter-regular for descriptions, mono-eyebrow uppercase "STEP 1/2/3" labels above each step's title. Status circles fill with `Brand.Color.accent` when ✓. Tap targets ≥ 44pt. No iconography beyond the status circle — the existing AddPodcastSheet keeps its visual restraint.

### 4. Pending-import session

`ApplePodcastsImportSession` — a tiny `@Observable @MainActor final class` with `static let shared`. State:

```swift
var pendingFeedURLs: [URL]? = nil
var receivedAt: Date? = nil
var shouldPresentWizard: Bool = false
```

- `VibecastURLHandler` writes to it on receiving a valid `vibecast://import-feeds` URL.
- `SubscriptionsListView` observes `shouldPresentWizard` and, when true, presents `AddPodcastSheet` with the wizard auto-shown, then immediately resets the flag to false so re-opens require a new shortcut run.
- The wizard reads `pendingFeedURLs` + `receivedAt` for Step 2/3 state, and clears them when the user successfully imports or dismisses.
- A 5-minute freshness check (`Date().timeIntervalSince(receivedAt) < 300`) avoids importing stale data from a long-abandoned run.

## Data flow

```
Apple Podcasts subscriptions
        │
        ▼
[Shortcuts app: "Vibecast Import"]
  Get Podcasts from Library
  Extract Feed URL per podcast
  Filter non-empty
  URL-encode joined list
        │
        ▼
[iOS]  vibecast://import-feeds?urls=<encoded-list>
        │
        ▼
[Vibecast: .onOpenURL]
        │
        ▼
[VibecastURLHandler]
  Parse, split, dedupe, validate
        │
        ▼
[ApplePodcastsImportSession.shared]
  pendingFeedURLs = [URL]
  receivedAt = .now
  shouldPresentWizard = true (if wizard not already visible)
        │
        ▼
[Wizard sub-sheet — Step 3 enabled]
  Renders "Found N podcasts ready to import"
  User taps "Import N Podcasts"
        │
        ▼
[SubscriptionManager.importFeeds([URL])]
  isImportingFeeds = true
  Per URL: skip if already subscribed
           else subscribe(to: URL)  — existing path
  Tally ImportSummary
  isImportingFeeds = false
        │
        ▼
[Wizard — summary row]
  "Imported N · Already subscribed M · Failed F"
  User taps "Done" → dismiss wizard + AddPodcastSheet
```

## Error handling

- **No URLs in payload**: `urls` query is empty or contains only whitespace → `pendingFeedURLs` set to `[]`. Step 3 renders "No subscribable podcasts found in your Apple Podcasts library — your shows may all be Apple Originals." Import button hidden; "Done" dismisses.
- **All URLs malformed**: URL handler filters them out, same empty-list state as above.
- **Some URLs fail to fetch RSS**: same as OPML — tallied into `failed`. Surfaced in the wizard's final summary row.
- **Shortcut not installed**: `shortcuts://run-shortcut?name=Vibecast%20Import` fails. iOS shows its own "couldn't find shortcut" alert. Step 1 in the wizard remains tappable post-✓ specifically for this recovery — the user re-taps "Install Shortcut" to re-open the iCloud share URL.
- **Shortcuts.app isn't installed at all** (rare — Shortcuts is bundled with iOS but can be removed): `UIApplication.shared.canOpenURL(URL(string: "shortcuts://")!)` returns false. Step 2's button copy and behavior change to "Install Shortcuts.app" linking to the App Store listing.
- **Stale received payload**: if `receivedAt` is older than 5 minutes when the wizard opens, Step 2 reverts to its pre-✓ state and Step 3 shows "Last run is too old — please run the shortcut again." Prevents auto-import of a long-abandoned payload after the user has changed their Apple Podcasts subscriptions in the meantime.
- **Re-running with already-subscribed shows**: `SubscriptionManager.subscribe(to: URL)` already guards against duplicates. The wizard's summary distinguishes `succeeded` from `alreadySubscribed` from `failed`.
- **User backgrounds during import**: same as OPML — the import task is on the main actor and survives backgrounding. On foreground return, the wizard shows whatever state the import progressed to.

## Testing

- **Unit tests** on the URL handler:
  - Happy-path parse: one feed, multiple feeds, mixed whitespace, trailing newline.
  - Malformed: invalid URLs in list (filter, don't crash), empty `urls` param, missing `urls` param, wrong host (`vibecast://unknown` → no-op).
  - Dedup: same URL appearing twice in the payload counts once.
- **Unit tests** on `ApplePodcastsImportSession`:
  - Receiving a payload sets `pendingFeedURLs`, `receivedAt`, and `shouldPresentWizard`.
  - Within freshness window: state remains "ready."
  - After 5+ minutes: state reads as "stale."
  - `clear()` resets all three fields.
- **Integration test** on `SubscriptionManager.importFeeds(_:)`:
  - Empty list → no fetches, summary attempted=0.
  - All already-subscribed → no fetches, summary `alreadySubscribed=N`, succeeded=0.
  - Mix of new + already-subscribed + fetch-failures → summary tallies match.
- **Manual verification** (no automated test possible for cross-app flow):
  - First-time wizard flow: tap "Import from Apple Podcasts" → wizard opens at Step 1 → tap Install → iCloud opens → Add Shortcut → return → Step 1 ✓, Step 2 enabled.
  - Step 2 → Step 3: tap Run → Shortcuts.app runs the shortcut → Vibecast re-foregrounds → wizard shows ✓ on Step 2, "Found N podcasts" on Step 3.
  - Step 3 import: tap "Import N Podcasts" → progress row → summary row → shows appear in All view after Done.
  - Auto-present: close the wizard, run shortcut from Shortcuts.app directly → Vibecast foregrounds → AddPodcastSheet + wizard auto-open to Step 3.
  - Stale payload: run shortcut, leave wizard alone for 6 minutes → reopen → Step 2 reverts to "Run the shortcut again."
  - Re-install path: delete shortcut from Shortcuts.app → tap Run in Step 2 → iOS "not found" alert → tap Install in Step 1 → re-install flow works.
  - Re-running on an already-fully-imported library: summary reads `alreadySubscribed=N`, `succeeded=0`.

## File touch list

- **Create**: `Vibecast/Vibecast/Discovery/VibecastURLHandler.swift` — parses `vibecast://...` URLs and writes parsed feed URLs into `ApplePodcastsImportSession`.
- **Create**: `Vibecast/Vibecast/Discovery/ApplePodcastsImportSession.swift` — `@Observable @MainActor` singleton holding the pending payload + freshness timestamp + auto-present trigger.
- **Create**: `Vibecast/Vibecast/Views/ApplePodcastsImportWizard.swift` — the wizard sub-sheet view with the three-step UI.
- **Create**: `Vibecast/VibecastTests/VibecastURLHandlerTests.swift` — URL parser tests.
- **Create**: `Vibecast/VibecastTests/ApplePodcastsImportSessionTests.swift` — session freshness / state-transition tests.
- **Modify**: `Vibecast/Vibecast/Vibecast.xcodeproj/.../Info.plist` — register `CFBundleURLTypes` with `vibecast` scheme.
- **Modify**: `Vibecast/Vibecast/VibecastApp.swift` — attach `.onOpenURL { url in VibecastURLHandler.handle(url) }` at the app root, inject `ApplePodcastsImportSession.shared` into the environment.
- **Modify**: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift` — add `func importFeeds(_ urls: [URL]) async` mirroring `importOPML`'s tally pattern, plus an `isImportingFeeds: Bool` flag for the wizard progress row. Reuses existing `subscribe(to: URL)`.
- **Modify**: `Vibecast/Vibecast/Views/AddPodcastSheet.swift` — add "Import from Apple Podcasts" row at the bottom of the existing rows; row taps present the wizard. Add `iCloudShortcutInstallURL` constant (placeholder until shortcut is published).
- **Modify**: `Vibecast/Vibecast/Views/SubscriptionsListView.swift` — observe `ApplePodcastsImportSession.shared.shouldPresentWizard`; when true, present `AddPodcastSheet` with the wizard pre-opened.
- **Modify**: `Vibecast/VibecastTests/SubscriptionManagerTests.swift` — add `importFeeds` tests.

## Open questions / known unknowns

These will be confirmed during implementation Task 1 (shortcut build):

1. **Does `Get Podcasts from Library` actually expose Feed URL as a property?** Strong prior yes — it's been there since iOS 17. Verify by building a trivial shortcut and inspecting available properties.
2. **What does `Feed URL` return for Apple-Originals / paid subscriptions?** Empty string vs nil vs Apple-internal URL. Determines the shortcut's filter expression.
3. **What's the exact iCloud share URL?** Captured during implementation when we publish the shortcut. The Swift constant in `AddPodcastSheet.swift` is a placeholder until then.
4. **Does Shortcuts.app preserve the shortcut name "Vibecast Import" verbatim when a user installs it?** Yes — the install dialog shows the name; users can rename, but most won't. We document this in the help text. If they rename, the deep-link breaks and they hit the re-install path.
