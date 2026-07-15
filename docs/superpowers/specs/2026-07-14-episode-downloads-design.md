# Episode Downloads Design

**Date:** 2026-07-14
**Status:** Approved
**Target:** Usable for offline listening before 2026-07-18 (trip)

## Problem

Vibecast streams all audio. No offline listening — a trip with no connectivity means no podcasts. Users need episodes downloaded to disk, downloaded automatically as new episodes appear, with sane storage management.

## Goals

1. Auto-download the newest episode of each subscribed show when it's discovered (foreground refresh — the app has no background refresh today, and that stays true).
2. Retention: keep the last N auto-downloads per show (default 3), prune older ones automatically.
3. Manual download of any episode from a show's episode list; manual downloads are exempt from auto-pruning.
4. Global settings page: auto-download toggle, keep-last-N, delete-when-played, wifi-only, storage summary, delete-all.
5. Downloaded episodes play from disk (verified working in airplane mode).

## Non-Goals

- True background refresh / BGTaskScheduler (new episodes still only discovered when the app is opened).
- Per-podcast setting overrides (global-only; the model doesn't preclude adding them later).
- A dedicated Downloads screen (storage summary in settings covers V1 of this).
- Streaming-while-downloading dedup (a playing episode can also be downloading; they're independent).

## Decisions Made

| Question | Decision |
|---|---|
| Download trigger | Foreground (on refresh discovering new episodes); in-flight downloads survive backgrounding via background URLSession |
| Settings scope | Global-only |
| Auto-download count | Newest 1 per show per refresh |
| Retention default | Keep last 3 auto-downloads per show |
| Manual downloads | Exempt from pruning |
| Downloads overview | Storage summary + delete-all in settings; no dedicated screen |
| State storage | On the `Episode` model (Approach A) — not a separate SwiftData model, not filesystem-as-truth |

## Design

### 1. Data model — `Episode` additions

Three persisted properties with defaults (SwiftData lightweight migration, same pattern as `Podcast.episodeSortOrderRaw`):

```swift
var downloadStateRaw: String = DownloadState.none.rawValue
var isManualDownload: Bool = false
var downloadedAt: Date?
```

Typed accessor over the raw string:

```swift
enum DownloadState: String, Codable, Sendable {
    case none, downloading, downloaded, failed
}

var downloadState: DownloadState {
    get { DownloadState(rawValue: downloadStateRaw) ?? .none }
    set { downloadStateRaw = newValue.rawValue }
}
```

The local file path is **never persisted** — derived from `audioURL` (see DownloadStore). Live progress percent is in-memory only (on DownloadManager), never written to SwiftData.

### 2. Files — `DownloadStore`

Enum with static functions (pure path math + FileManager; no state, no DI ceremony):

- Directory: `Application Support/Downloads/` (created on demand). NOT Caches (purgeable) — these files must survive storage pressure.
- Filename: `SHA256(audioURL)` hex (CryptoKit, same scheme as `ArtworkCache.diskPath(for:)`) + the audio URL's path extension, falling back to `mp3`.
- Every written file gets `URLResourceValues.isExcludedFromBackup = true` (re-downloadable content per Apple guidelines).
- API: `fileURL(for audioURL: String) -> URL`, `exists(for:) -> Bool`, `delete(for:)`, `totalBytes() -> Int64`, `deleteAll()`.

### 3. Engine — `DownloadManager`

`@Observable @MainActor final class DownloadManager`, created once in `VibecastApp.init` and injected through the environment (same pattern as `PlayerManager` / `SubscriptionManager`).

**URLSession:** `URLSessionConfiguration.background(withIdentifier: "AnglinVibes.Vibecast.downloads")` with a delegate. Background configuration means in-flight downloads continue when the app is backgrounded or terminated by the system.

**Background completion plumbing:** a minimal `UIApplicationDelegateAdaptor` (`AppDelegate: NSObject, UIApplicationDelegate`) implementing `application(_:handleEventsForBackgroundURLSession:completionHandler:)`, storing the completion handler; DownloadManager calls it from `urlSessionDidFinishEvents(forBackgroundURLSession:)`. This is the only app-delegate responsibility.

**Task↔episode mapping:** `downloadTask.taskDescription = episode.audioURL`. On delegate callbacks (including after relaunch), the episode is re-fetched from the model context by `audioURL` — no in-memory mapping needed to survive process death.

**Wifi-only:** enforced per-request via `URLRequest.allowsCellularAccess = !DownloadSettings.wifiOnly()`, read at enqueue time. No session rebuild when the setting changes; already-queued tasks keep the policy they were enqueued with.

**Public API:**

```swift
func download(_ episode: Episode, manual: Bool)
func cancelDownload(_ episode: Episode)
func deleteDownload(_ episode: Episode)
func deleteAllDownloads()
func totalStorageBytes() -> Int64
func episodeWasPlayed(_ episode: Episode)   // honors delete-when-played
func autoDownload(newEpisodes: [Episode])   // newest-1-per-show picker + prune
func pruneAll()                             // full prune pass (after keep-last-N lowered)
var progress: [PersistentIdentifier: Double]  // observed by rows
```

**State transitions:** `download()` sets `.downloading` and enqueues. Delegate `didFinishDownloadingTo` moves the temp file into DownloadStore, sets `.downloaded` + `downloadedAt`. Delegate `didCompleteWithError` (non-cancel) sets `.failed`. `cancel`/`delete` reset to `.none`, clear `isManualDownload` and `downloadedAt`, remove the file.

### 4. Auto-download + retention

**Hook:** `SubscriptionManager` gains `var onNewEpisodes: (([Episode]) -> Void)?`. `mergeFeed(_:into:)`'s new-episode branch collects inserted episodes; after a refresh batch saves, the callback fires with all of them. Wired in `VibecastApp`: `subs.onNewEpisodes = { downloadManager.autoDownload(newEpisodes: $0) }`. SubscriptionManager stays ignorant of downloads.

**`autoDownload(newEpisodes:)`:** no-op if `DownloadSettings.autoDownloadEnabled()` is false. Groups by podcast, picks the newest (by `publishDate`) per show, calls `download(_, manual: false)` for each, then prunes each affected show.

**Pruning (per show):** fetch episodes of that podcast where `downloadState == .downloaded && !isManualDownload`, sort newest-first by `publishDate`, keep `DownloadSettings.keepLastN()` (0 = unlimited → skip), delete the rest via `deleteDownload`. Runs after each auto-download and when keep-last-N is lowered in settings.

### 5. Settings — `DownloadSettings`

UserDefaults-backed static accessors with injectable defaults (same testable pattern as `VibecastApp.splashMode(defaults:)`):

| Setting | Key | Default |
|---|---|---|
| Auto-download new episodes | `downloadAutoEnabled` | `true` |
| Keep last N per show | `downloadKeepLastN` | `3` (choices 1/3/5/10/unlimited; unlimited stored as 0) |
| Delete when played | `downloadDeleteWhenPlayed` | `false` |
| Wifi-only | `downloadWifiOnly` | `true` |

**`DownloadSettingsView`** (sheet): four controls (toggle / picker / toggle / toggle), then a storage section — "Storage used: X MB" (computed from `totalStorageBytes()`, formatted with `ByteCountFormatter`) and a "Delete All Downloads" button behind a confirmation dialog. Lowering keep-last-N triggers a prune pass across all shows.

**Entry point:** `VibeMasthead` gains an `onTapSettings` callback rendered as a `gearshape` button alongside its existing buttons; `SubscriptionsListView` presents the sheet.

### 6. Playback + played-deletion

**Play path (`PlayerManager`):** where the URL is resolved today (`URL(string: episode.audioURL)` — both the play and restore paths), first check:

```swift
if episode.downloadState == .downloaded, DownloadStore.exists(for: episode.audioURL) {
    url = DownloadStore.fileURL(for: episode.audioURL)   // AVPlayerItem handles file:// natively
} else {
    if episode.downloadState == .downloaded { episode.downloadState = .none }  // file went missing; self-heal
    url = URL(string: episode.audioURL)
}
```

No `AudioEngine` changes.

**Delete-when-played:** every code path that sets `listenedStatus = .played` — `PlayerManager.markPlayed(_:advance:)` (covers auto-advance + explicit) and the swipe actions in `PodcastDetailView` and `SubscriptionsListView` — also calls `downloadManager.episodeWasPlayed(episode)`, which deletes the file iff the setting is on and the episode is downloaded.

**Wiring:** `PlayerManager` gains a `weak var downloadManager: DownloadManager?` assigned in `VibecastApp.init` after both objects exist (avoids init-order coupling; nil in unit tests that don't care about downloads). Views reach DownloadManager through the environment like the other managers.

### 7. Episode list UI

In the show's episode list (`PodcastDetailView`):

- **Trailing swipe** (net-new; leading swipe stays Played/Unplayed): context-sensitive single action — "Download" (`.none`/`.failed`), "Cancel" (`.downloading`), "Remove" (`.downloaded`).
- **Row indicator** (`EpisodeRowView`): compact glyph next to the duration label — `arrow.down.circle.fill` when downloaded, a determinate progress ring while downloading (driven by `DownloadManager.progress`), `exclamationmark.circle` when failed. No glyph for `.none`.
- Downloading/failed states also need VoiceOver labels consistent with the app's existing natural-language a11y work.

The library list (`SubscriptionsListView`) is unchanged — its trailing swipe is already occupied by Remove/Unsubscribe.

### 8. Error handling

- **Network failure / disk full:** task errors land in `.failed`; retry = swipe Download again (or tap the failure glyph).
- **Cancel:** resets to `.none`, partial temp data discarded (no resume-data support in V1 — YAGNI).
- **File missing at play time:** self-heals to `.none` and streams (see §6).
- **App killed mid-download:** background session resumes/completes on its own; on next launch DownloadManager reconnects to the session identifier and reconciles — any episode stuck in `.downloading` with no live task and no file resets to `.failed`.
- **Feed URL changed for an episode:** merge is keyed by `audioURL`, so a changed URL is a "new" episode — old download prunes naturally.

### 9. Testing

Unit (XCTest, patterns already in the suite):
- `DownloadSettings` accessors with isolated UserDefaults suites (default values + round-trips).
- `DownloadStore` path derivation: stable hash, extension handling (`.mp3` fallback), URL-with-query-string cases.
- Newest-1-per-show picker: multiple shows × multiple new episodes → exactly one per show, the newest.
- Pruning: in-memory ModelContainer with a podcast + mixed manual/auto downloaded episodes → verify keeps newest N auto, never touches manual, honors unlimited (0).
- Play-path URL resolution: downloaded+exists → file URL; downloaded+missing → remote URL + state reset.

Manual (device, before Saturday):
1. Fresh refresh downloads newest episode per show; progress rings render.
2. Airplane mode → downloaded episode plays; non-downloaded episode fails gracefully.
3. Manual download of an old episode survives a prune cycle.
4. Delete-when-played on → finishing an episode removes its file.
5. Background the app mid-download → download completes.
6. Settings storage number matches reality; Delete All zeroes it.

## Files

| Action | Path | Responsibility |
|---|---|---|
| Modify | `Vibecast/Vibecast/Models/Episode.swift` | 3 new properties + `DownloadState` enum + accessor |
| Create | `Vibecast/Vibecast/Downloads/DownloadStore.swift` | Path math, file ops, storage totals |
| Create | `Vibecast/Vibecast/Downloads/DownloadManager.swift` | Background URLSession engine, state transitions, auto-download, pruning |
| Create | `Vibecast/Vibecast/Downloads/DownloadSettings.swift` | UserDefaults accessors |
| Create | `Vibecast/Vibecast/Views/DownloadSettingsView.swift` | Settings sheet |
| Modify | `Vibecast/Vibecast/VibecastApp.swift` | Create/inject DownloadManager, AppDelegate adaptor, wire `onNewEpisodes` |
| Modify | `Vibecast/Vibecast/Discovery/SubscriptionManager.swift` | `onNewEpisodes` callback from `mergeFeed` |
| Modify | `Vibecast/Vibecast/Audio/PlayerManager.swift` | Local-URL play path, `episodeWasPlayed` on markPlayed |
| Modify | `Vibecast/Vibecast/Views/PodcastDetailView.swift` | Trailing download swipe, played-hook |
| Modify | `Vibecast/Vibecast/Views/EpisodeRowView.swift` | Download state glyph + progress ring |
| Modify | `Vibecast/Vibecast/Views/SubscriptionsListView.swift` | Settings sheet presentation, played-hook |
| Modify | `Vibecast/Vibecast/Views/VibeMasthead.swift` | `onTapSettings` gear button |
| Create | `Vibecast/VibecastTests/DownloadSettingsTests.swift` | Settings tests |
| Create | `Vibecast/VibecastTests/DownloadStoreTests.swift` | Path/hash tests |
| Create | `Vibecast/VibecastTests/DownloadPolicyTests.swift` | Picker + pruning tests |
