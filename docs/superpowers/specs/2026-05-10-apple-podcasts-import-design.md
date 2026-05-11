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
- **`AddPodcastSheet` row**: "Import from Apple Podcasts" affordance, sits alongside the existing "Import from File" (OPML) row. Two visual states:
  - **First-time** (UserDefaults flag absent): label reads "Import from Apple Podcasts" with a setup-required hint; tap opens the iCloud share link in Safari/Shortcuts via `UIApplication.shared.open`, the user taps "Add Shortcut" in Shortcuts.app, then we set the flag on return.
  - **Subsequent** (flag set): label reads "Import from Apple Podcasts"; tap deep-links straight to `shortcuts://run-shortcut?name=Vibecast%20Import`.
- **Resilient fallback**: if `shortcuts://run-shortcut` fails (shortcut deleted from user's library), iOS shows its own "couldn't find shortcut" alert. We additionally provide a "Re-install Shortcut" row inside the sheet so the user can recover without nuking UserDefaults.
- **Tests**: URL parsing happy-path and malformed-input cases. The Shortcuts → URL → app → import wiring is verified manually since Shortcuts isn't simulated in CI.

### Out of scope (explicit)

- **Auto-vibing on import** — imported podcasts go into the All library only. The user tags them into vibes afterward. Same posture as OPML import.
- **Apple-Originals / paid Apple Podcasts subscriptions** — shows that have no public RSS Feed URL (Apple-exclusive content). The shortcut filters these out by skipping podcasts where `Feed URL` is empty. Vibecast never sees them and never reports them. Surfacing "N shows couldn't be imported because they're Apple-only" is a future polish if users complain.
- **Two-way sync** — this is one-shot import, not ongoing mirroring of Apple Podcasts subscriptions.
- **Auto-detection of "shortcut is installed"** — iOS provides no API to inspect another app's shortcut library. We track install state via UserDefaults and the user-initiated install action.
- **Other URL scheme actions** — `vibecast://` is reserved for future deep links but this plan only ships `import-feeds`. We do not enumerate `vibecast://play/<episode-id>` or similar in this spec.
- **Universal Links** — not needed; we're not handling web URLs.
- **macOS helper script** — superseded by the Shortcuts approach.

## Architecture

Three units, each with one responsibility and a narrow interface to the next.

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

### 3. `AddPodcastSheet` UI

A new row, "Import from Apple Podcasts," matching the layout of the existing "Import from File" row.

Behavior driven by `@AppStorage("hasInstalledApplePodcastsImportShortcut") var hasInstalled: Bool = false`:

- `!hasInstalled`: tap opens the hosted iCloud share URL. After Shortcuts.app finishes installing (we can't observe this directly), we optimistically set `hasInstalled = true` on the next foreground return after the install URL was opened — guarded by a one-shot "we just opened the install URL" flag so we don't flip the bit on unrelated backgroundings.
- `hasInstalled`: tap opens `shortcuts://run-shortcut?name=Vibecast%20Import`. Shortcuts.app runs the shortcut, which then re-opens Vibecast with the `vibecast://import-feeds?urls=...` URL.

A secondary "Re-install Shortcut" affordance is reachable from inside the sheet (e.g. a small "Having trouble?" link) and re-opens the iCloud share URL — for users who deleted the shortcut from their library and need to recover.

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
[SubscriptionManager.importFeeds([URL])]
  Per URL: skip if already subscribed
           else subscribe(to: URL)  — existing path
  Tally ImportSummary
        │
        ▼
[ToastCenter] "Imported N shows, skipped M"
```

## Error handling

- **No URLs in payload**: `urls` query is empty or contains only whitespace → show toast "No podcasts to import." Don't error-crash.
- **All URLs malformed**: same toast; the user re-runs.
- **Some URLs fail to fetch RSS**: same as OPML — tallied into `failed`. No retry UI in v1; user can re-run.
- **All-Apple-originals library**: shortcut filters them out before sending. If the resulting URL list is empty, the import-feeds handler shows "No subscribable podcasts found — all your shows appear to be Apple Originals." (Plain-language explanation, no error tone.)
- **Shortcut not installed**: `shortcuts://run-shortcut?name=Vibecast%20Import` fails. iOS shows its own alert. Our "Re-install Shortcut" affordance is the recovery path.
- **User taps Import-from-Apple-Podcasts but Shortcuts.app isn't installed at all** (rare — Shortcuts is bundled with iOS): the `shortcuts://` URL won't open. We detect via `UIApplication.shared.canOpenURL` before the tap commits, and surface a help row pointing to the App Store listing for Shortcuts.
- **Re-running with already-subscribed shows**: `SubscriptionManager.subscribe(to: URL)` already guards against duplicates. The summary distinguishes `succeeded` from `alreadySubscribed`.

## Testing

- **Unit tests** on the URL handler:
  - Happy-path parse: one feed, multiple feeds, mixed whitespace, trailing newline.
  - Malformed: invalid URLs in list (filter, don't crash), empty `urls` param, missing `urls` param, wrong host (`vibecast://unknown` → no-op).
  - Dedup: same URL appearing twice in the payload counts once.
- **Integration test** on `SubscriptionManager.importFeeds(_:)`:
  - Empty list → no fetches, summary attempted=0.
  - All already-subscribed → no fetches, summary `alreadySubscribed=N`, succeeded=0.
  - Mix of new + already-subscribed + fetch-failures → summary tallies match.
- **Manual verification** (no automated test possible for cross-app flow):
  - First-time install flow: tap Import → iCloud opens → Add Shortcut → return → flag flips → next tap runs shortcut.
  - End-to-end: run shortcut with a real Apple Podcasts library → Vibecast opens → import summary toasts → shows appear in All.
  - Re-install path: delete shortcut from Shortcuts.app → next run shows iOS "not found" alert → "Re-install Shortcut" affordance recovers.
  - Re-running on an already-fully-imported library: summary should read mostly `alreadySubscribed`.

## File touch list

- **Create**: `Vibecast/Vibecast/Discovery/VibecastURLHandler.swift` — parses `vibecast://...` URLs and dispatches to `SubscriptionManager`.
- **Create**: `Vibecast/VibecastTests/VibecastURLHandlerTests.swift` — parser tests.
- **Modify**: `Vibecast/Vibecast/Vibecast.xcodeproj/.../Info.plist` — register `CFBundleURLTypes` with `vibecast` scheme.
- **Modify**: `Vibecast/Vibecast/VibecastApp.swift` — attach `.onOpenURL { url in VibecastURLHandler.handle(url, ...) }`.
- **Modify**: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift` — add `func importFeeds(_ urls: [URL]) async` mirroring `importOPML`'s tally pattern. Reuses existing `subscribe(to: URL)`.
- **Modify**: `Vibecast/Vibecast/Views/AddPodcastSheet.swift` — add "Import from Apple Podcasts" row + first-time install flow + re-install affordance. Add Swift constant for the iCloud share URL.
- **Modify**: `Vibecast/VibecastTests/SubscriptionManagerTests.swift` — add `importFeeds` tests.

## Open questions / known unknowns

These will be confirmed during implementation Task 1 (shortcut build):

1. **Does `Get Podcasts from Library` actually expose Feed URL as a property?** Strong prior yes — it's been there since iOS 17. Verify by building a trivial shortcut and inspecting available properties.
2. **What does `Feed URL` return for Apple-Originals / paid subscriptions?** Empty string vs nil vs Apple-internal URL. Determines the shortcut's filter expression.
3. **What's the exact iCloud share URL?** Captured during implementation when we publish the shortcut. The Swift constant in `AddPodcastSheet.swift` is a placeholder until then.
4. **Does Shortcuts.app preserve the shortcut name "Vibecast Import" verbatim when a user installs it?** Yes — the install dialog shows the name; users can rename, but most won't. We document this in the help text. If they rename, the deep-link breaks and they hit the re-install path.
