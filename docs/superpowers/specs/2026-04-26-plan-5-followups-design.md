# Plan 5: Followups Design Spec

## Goal

Land an 8-item batch of polish, hardening, and bug fixes that surfaced during Plan 2/3/4 reviews and end-to-end usage, before we start visual-refresh / Vibes / Pinning work in Plans 6–8.

## Background

Vibecast has shipped a working MVP loop: subscribe (search or OPML), view list, play, refresh. Three classes of issue accumulated as followups during prior plans:

- **One reproducible crash** (Plan 4): SwiftData detached-fault when deleting a podcast.
- **Audio engine surface gaps** (Plan 2): no background playback, no lock-screen controls, custom volume slider that fights iOS, and a small duration-rounding bug.
- **Discovery hardening + polish** (Plan 3): missing HTTP status validation, no `http://` → `https://` auto-upgrade for feed URLs, missing accessibility labels on the search row, and a strict OPML parser that breaks on common malformed input (unescaped `&`).

This plan addresses all eight as a single coordinated branch. None of them require user-facing UX changes beyond what the existing views already imply.

## Items in scope

| # | Title | Origin |
|---|---|---|
| 66 | Crash on podcast removal (SwiftData detached-fault) | Plan 4 review + reproduction |
| 64 | Background audio playback + lock-screen controls | Plan 2 review |
| 65 | Remove in-app volume slider, defer to system volume | Plan 2 review |
| 28 | `handlePlaybackEnd` duration mismatch | Plan 2 review |
| 42 | HTTP status validation in iTunes + Feed services | Plan 3 review |
| 60 | Auto-upgrade `http://` feed URLs to `https://` | Plan 4 OPML real-world testing |
| 43 | Accessibility labels + 44pt tap targets on SearchResultRow | Plan 3 review |
| 59 | Lenient OPML parser + better parse-error diagnostics | Plan 4 OPML real-world testing |

## Item designs

### #66 — SwiftData detached-fault on podcast removal

**Diagnosis (already confirmed via console-pty repro):**

```
SwiftData/BackingData.swift:249: Fatal error: This backing data was detached from a context
without resolving attribute faults: ...Episode/p151 - \Episode.listenedStatus
```

When a podcast is removed via swipe-to-delete, SwiftData cascade-deletes the podcast's episodes (`@Relationship(deleteRule: .cascade) var episodes`). During the SwiftUI row-exit animation, SwiftUI re-evaluates the disappearing row's body — but the row's `Podcast` reference is now tombstoned, so `podcast.episodes.sorted(...).first.listenedStatus` faults. Middle-row deletions trigger this most reliably because surrounding rows shift and parent re-render is forced; top/bottom-row deletions are intermittent.

**Fix: switch `SubscriptionsListView` to `@Query`, drop `SubscriptionsViewModel` entirely.**

`@Query` is SwiftData's managed read path. It handles deletion-animation lifecycle correctly because SwiftData controls both the model invalidation and the view update. The hand-rolled `SubscriptionsViewModel.podcasts` cached array sat outside SwiftData's lifecycle and was the root cause.

**Migration:**

| Old (`SubscriptionsViewModel`) | New (`SubscriptionsListView` inline) |
|---|---|
| `vm.podcasts` | `@Query(sort: \Podcast.sortPosition) private var podcasts: [Podcast]` |
| `vm.fetch()` | (no-op; `@Query` auto-updates) |
| `vm.remove(podcast)` | `modelContext.delete(podcast); try? modelContext.save()` |
| `vm.markPlayed(episode)` | inline: set `listenedStatus = .played`, `playbackPosition = Double(durationSeconds)`, save |
| `vm.move(from:to:)` | `.onMove` closure: local `var reordered = podcasts`, call `reordered.move(fromOffsets:toOffset:)`, then loop and set each `podcast.sortPosition = i`, save. `@Model` instances are reference types so mutation propagates; `@Query` re-runs after save. |
| `vm.fetch()` callers (`AddPodcastSheet` dismissal, `.refreshable`) | delete (auto-update) |

The view gets `@Environment(\.modelContext) private var modelContext`.

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift` — replace `@State` view-model with `@Query` + inline ops
- Delete: `Vibecast/Vibecast/ViewModels/SubscriptionsViewModel.swift`
- Delete: `Vibecast/VibecastTests/SubscriptionsViewModelTests.swift`
- Add: `Vibecast/VibecastTests/SubscriptionsRemovalTests.swift` — regression test exercising middle-row delete (insert 4 podcasts, delete index 2 via `modelContext.delete`, save, assert remaining 3 + no crash)

The regression test can't reproduce the SwiftUI animation crash directly (it's a runtime view-cycle issue), but it can verify the new flow correctly removes the row and re-queries. The real proof is the manual repro no longer crashing.

### #64 — Background audio + lock-screen controls

Three coordinated pieces.

**#64.1 — AVAudioSession configuration (in `AVPlayerAudioEngine`)**

In `AVPlayerAudioEngine.init` (or a one-time static configure called from `VibecastApp`):

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
try session.setActive(true)
```

`.playback` allows audio when silent switch is on; `.spokenAudio` is Apple's mode for podcasts/audiobooks (correct ducking, AirPods/Bluetooth route handling); `.longFormAudio` policy enables CarPlay and other long-form integrations.

**Interruption handling** — observe `AVAudioSession.interruptionNotification`:
- `.began` → call `engine.pause()` and propagate to `PlayerManager.isPlaying = false`
- `.ended` with `.shouldResume` option → call `engine.play()` and propagate `isPlaying = true`. Spoken-audio convention is to auto-resume after interruption.

**Route change handling** — observe `AVAudioSession.routeChangeNotification`:
- Reason `.oldDeviceUnavailable` (headphone/AirPod unplug) → pause

These observers must hold `weak self`; route them into `PlayerManager` via a closure or delegate so the manager remains the source of truth for `isPlaying`.

**#64.2 — UIBackgroundModes capability**

Enable "Audio, AirPlay, and Picture in Picture" in target → Signing & Capabilities → Background Modes. This adds `INFOPLIST_KEY_UIBackgroundModes = "audio"` (or equivalent array form) to the build settings in `project.pbxproj`. Verify via:

```bash
grep -i 'UIBackgroundModes\|UIApplicationSceneManifest' Vibecast/Vibecast.xcodeproj/project.pbxproj
```

Must contain `audio` after the change.

**#64.3 — NowPlayingService (lock-screen + remote commands)**

New file: `Vibecast/Vibecast/Audio/NowPlayingService.swift`. `@Observable @MainActor final class NowPlayingService`. Responsibilities:

1. **Now Playing info dictionary** — populated on state changes (play/pause/seek/episode-change), **not on every time-tick**. iOS extrapolates `elapsed` from `playbackRate`.

   ```
   MPMediaItemPropertyTitle:                        episode.title
   MPMediaItemPropertyAlbumTitle:                   episode.podcast?.title ?? ""
   MPMediaItemPropertyArtist:                       episode.podcast?.author ?? ""
   MPMediaItemPropertyPlaybackDuration:             duration  (TimeInterval)
   MPNowPlayingInfoPropertyElapsedPlaybackTime:     elapsed   (TimeInterval)
   MPNowPlayingInfoPropertyPlaybackRate:            isPlaying ? 1.0 : 0.0
   MPMediaItemPropertyArtwork:                      MPMediaItemArtwork (async-loaded, see below)
   ```

2. **Artwork** — async-load from `episode.podcast?.artworkURL` once per episode change. Cache the resolved `UIImage` keyed by URL string (in-memory dictionary, no eviction needed at this scale). The `MPMediaItemArtwork` initializer takes a closure that returns a sized image; pass through the cached image.

3. **Remote commands** — wire `MPRemoteCommandCenter.shared()`:
   ```
   playCommand               → playerManager.togglePlayPause() if !isPlaying else no-op
   pauseCommand              → playerManager.togglePlayPause() if isPlaying else no-op
   togglePlayPauseCommand    → playerManager.togglePlayPause()
   skipForwardCommand        → playerManager.skipForward(30)
                               (preferredIntervals = [30])
   skipBackwardCommand       → playerManager.skipBack(15)
                               (preferredIntervals = [15])
   changePlaybackPositionCommand → playerManager.seek(to: event.positionTime)
                               (cast event to MPChangePlaybackPositionCommandEvent)
   ```
   Leave `nextTrackCommand` and `previousTrackCommand` disabled — multi-episode queue is Plan 7 Vibes territory.

**Wiring (two-way coupling):**

- **PlayerManager → NowPlayingService (state)**: `NowPlayingService` exposes `update(state: PlaybackState)` where `PlaybackState` is a value-type carrying the info-dict fields (title, podcast title, author, duration, elapsed, isPlaying, artworkURL). `PlayerManager` calls `update(state:)` from `play()`, `togglePlayPause()`, `seek(to:)`, and `handlePlaybackEnd()`.
- **NowPlayingService → PlayerManager (commands)**: introduce a small `protocol PlaybackController: AnyObject` with `togglePlayPause()`, `seek(to: TimeInterval)`, `skipForward(_: TimeInterval)`, `skipBack(_: TimeInterval)`. `PlayerManager` conforms; `NowPlayingService` holds a `weak var controller: (any PlaybackController)?` and routes `MPRemoteCommandCenter` events through it.
- **App wiring** in `VibecastApp`: instantiate `NowPlayingService()` and `PlayerManager(...)`, then `nowPlaying.controller = playerManager` and pass `nowPlaying` to `playerManager` so it can call `update(state:)`.

**Test:** `NowPlayingServiceTests` mocks `MPNowPlayingInfoCenter` (or asserts via the protocol seam — see "Architecture" below) and verifies the info dictionary is populated correctly on play/pause/seek/episode-change. Remote command wiring is harder to test in a unit context; cover via manual verification.

### #65 — Remove in-app volume slider, defer to system volume

**Code changes:**
- Delete `volume: Float { get set }` from the `AudioEngine` protocol
- Delete `volume` setter / state from `AVPlayerAudioEngine` (let `AVPlayer.volume` stay at its default 1.0; `AVAudioSession` delivers system volume)
- Delete `volume`-related state from `PlayerManager`
- Replace the volume `Slider` in `FullScreenPlayerView` with `MPVolumeView` via a `UIViewRepresentable` wrapper (new file or inline): `Vibecast/Vibecast/Views/SystemVolumeView.swift`. Configure to show only the volume slider + AirPlay button (`MPVolumeView` shows both by default).
- Update `PlayerManagerTests` — remove volume-related cases

**Files:**
- Modify: `Vibecast/Vibecast/Audio/AudioEngine.swift`, `AVPlayerAudioEngine.swift`, `PlayerManager.swift`
- Modify: `Vibecast/Vibecast/Views/FullScreenPlayerView.swift`
- Add: `Vibecast/Vibecast/Views/SystemVolumeView.swift` (UIViewRepresentable wrapping MPVolumeView)
- Modify: `Vibecast/VibecastTests/PlayerManagerTests.swift`

`MPVolumeView` has known simulator quirks (the slider doesn't render in simulator — appears empty). Manual verification must happen on device or be acknowledged as a known sim limitation in the verification step.

### #28 — handlePlaybackEnd duration mismatch

In `PlayerManager.handlePlaybackEnd`:

```swift
private func handlePlaybackEnd() {
    guard let episode = currentEpisode else { return }
    episode.listenedStatus = .played
    let actualDuration = engine.duration
    let canonicalDuration = actualDuration > 0 ? actualDuration : Double(episode.durationSeconds)
    episode.playbackPosition = canonicalDuration
    elapsed = canonicalDuration
    isPlaying = false
    try? modelContext.save()
    lastPersistedAt = elapsed
}
```

The feed-derived `episode.durationSeconds` (Int, often rounded) stays untouched as the canonical metadata field. We use the engine's actual duration when available so `playbackPosition` lines up with the real end-of-file. `progressFraction` already clamps to 1.0, so visual rounding stays clean.

**Test:** add a case to `PlayerManagerTests` that simulates `handlePlaybackEnd` after a load with `engine.duration = 1234.5` and `episode.durationSeconds = 1234` (different values) and asserts `playbackPosition == 1234.5`.

### #42 — HTTP status validation

Both `iTunesSearchService.search(_:)` and `URLSessionFeedFetcher.fetch(_:)` call `session.data(from:)` and only act on the data. Neither validates the HTTP status code today — a 500 with empty body parses as "no results" / fails downstream as a parse error rather than surfacing a server error. Neither service has a named error enum yet; we introduce one per service.

**New error enums** (live alongside their respective services in `Vibecast/Vibecast/Discovery/`):

```swift
enum PodcastSearchError: Error, Equatable {
    case invalidResponse
    case serverError(status: Int)
}

enum FeedFetchError: Error, Equatable {
    case invalidResponse
    case serverError(status: Int)
}
```

**Fix in both services:**

```swift
let (data, response) = try await session.data(from: url)
guard let http = response as? HTTPURLResponse else { throw <ServiceError>.invalidResponse }
guard (200..<300).contains(http.statusCode) else {
    throw <ServiceError>.serverError(status: http.statusCode)
}
// proceed with data
```

**Tests:** add `MockURLProtocol`-backed cases in `PodcastSearchServiceTests` and `FeedFetcherTests` that return 500 + empty body; assert the right error case is thrown.

UI surface: existing error-handling paths in `AddPodcastSheet` and `SubscriptionManager.subscribe` already display thrown errors generically — these new cases will surface as the existing "Couldn't add — try again" or "Couldn't reach feed" messaging without UI changes.

### #60 — http:// → https:// auto-upgrade

In `URLSessionFeedFetcher.fetch(_:)`, before making the request, unconditionally upgrade `http://` → `https://`. Add a small helper extension on `URL` in a new file `Vibecast/Vibecast/Discovery/URL+UpgradeScheme.swift`:

```swift
extension URL {
    /// Returns a copy of this URL with the scheme upgraded from `http` to `https`,
    /// or self if the scheme is already `https` (or non-http).
    func upgradedToHTTPS() -> URL {
        guard scheme?.lowercased() == "http" else { return self }
        var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)
        comps?.scheme = "https"
        return comps?.url ?? self
    }
}
```

Use it at the top of `fetch(_:)`:

```swift
func fetch(_ feedURL: URL) async throws -> ParsedFeed {
    let url = feedURL.upgradedToHTTPS()
    // existing logic
}
```

**No fallback to http.** ATS would block plain `http://` anyway; if `https://` fails the feed is effectively dead, and surfacing the https error gives users a clearer signal than silent ATS rejection. Real-world testing during Plan 4 confirmed all 8 plain-http feeds in the user's OPML export had working https mirrors.

**Tests:** unit test for `URL.upgradedToHTTPS()` extension. Integration test in `FeedFetcherTests` not strictly necessary — the extension is the entire change.

### #43 — Accessibility on SearchResultRow

`SearchResultRow` has a subscribe button that cycles through 4 states: idle (`+`), in-flight (spinner), subscribed (`checkmark`), failed-recently (`+ "Couldn't add — try again"`). Each needs a clear VoiceOver label.

```swift
.accessibilityLabel(accessibilityLabelForState)
.accessibilityHint(accessibilityHintForState)

private var accessibilityLabelForState: String {
    if isSubscribed       { return "Already subscribed to \(result.title)" }
    if isInFlight         { return "Subscribing to \(result.title)" }
    if recentlyFailed     { return "Couldn't subscribe to \(result.title), try again" }
    return "Subscribe to \(result.title)"
}

private var accessibilityHintForState: String {
    if isSubscribed   { return "Already in your library" }
    if isInFlight     { return "Working on it" }
    return "Adds this podcast to your library"
}
```

Tap target: ensure the subscribe button has `.frame(minWidth: 44, minHeight: 44)` and a `.contentShape(Rectangle())` so the full 44pt area is hit-testable. Audit `PodcastRowView`'s play button while we're in there — same standard.

**Tests:** SwiftUI accessibility is awkward to unit-test; cover via manual verification with VoiceOver enabled in the simulator.

### #59 — Lenient OPML parser + better diagnostics

**Pre-sanitize step** in `StandardOPMLImporter.extractFeedURLs(from data: Data)`:

```swift
private static let unescapedAmpersand = try! NSRegularExpression(
    pattern: "&(?!(amp|lt|gt|quot|apos|#[0-9]+|#x[0-9a-fA-F]+);)",
    options: []
)

private func sanitize(_ data: Data) -> Data {
    guard var s = String(data: data, encoding: .utf8) else { return data }
    let range = NSRange(s.startIndex..., in: s)
    s = Self.unescapedAmpersand.stringByReplacingMatches(
        in: s, range: range, withTemplate: "&amp;"
    )
    return Data(s.utf8)
}
```

Apply before instantiating `XMLParser`. Covers the realistic 90% of malformed-OPML cases (Apple Podcasts / Overcast exports occasionally include `&` without escaping when a podcast title contains it).

**Diagnostics on parse failure** — extend `OPMLImportError`:

```swift
enum OPMLImportError: LocalizedError {
    case malformed(line: Int, column: Int)

    var errorDescription: String? {
        switch self {
        case .malformed(let line, let col):
            return "Couldn't parse OPML at line \(line), column \(col). Make sure it's a valid OPML export."
        }
    }
}
```

When `XMLParser.parse()` returns false, capture `parser.lineNumber` and `parser.columnNumber` and throw the new case. Update `AddPodcastSheet`'s failure alert to show the localized description (it already does, via `LocalizedError`).

**Tests:** add fixtures `feed-malformed-unescaped-ampersand.opml` (sanitizable; should succeed after pre-sanitize) and `feed-malformed-unrecoverable.xml` (truly broken; should throw `.malformed` with line/column populated).

## Architecture choices

**`NowPlayingService` as a separate class (not in `PlayerManager`)**

`PlayerManager` is already 180 lines doing playback orchestration, persistence, and listened-status state machine. Folding lock-screen + remote commands in would push it well past a comfortable size. Splitting also makes the Now Playing layer independently testable: we can mock the service in `PlayerManagerTests` and test the service's info-dictionary output in isolation. The protocol seam is `protocol NowPlayingPublishing` with one method `update(state: PlaybackState)` where `PlaybackState` carries the info-dict fields.

**MPVolumeView in full-screen player**

The alternative is removing the slider with no replacement and relying purely on hardware buttons + Control Center + the lock-screen MPVolumeView. We're going with the in-player MPVolumeView because (a) it's a familiar affordance, (b) it gives the AirPlay route picker for free without us having to wire it separately, and (c) full-screen player is exactly the surface where users expect output controls.

**`@Query` migration scope**

Only `SubscriptionsListView` migrates to `@Query` in this plan. `PodcastDetailView` already uses a different pattern (`PodcastDetailViewModel` with explicit refetch on `.task`) and isn't affected by the deletion crash — no need to touch it.

`SubscriptionManager` keeps its hand-rolled SwiftData operations (subscribe / refresh / import). Those happen in service code, not in view bodies, and don't hit the deletion-animation hazard. They also benefit from explicit transaction control.

## Out of scope

- Visual refresh / Vibes / Pinning — Plans 6, 7, 8.
- Migration of `SubscriptionManager` operations to `@Query`-style — services keep explicit context ops.
- `PodcastDetailViewModel` migration to `@Query` — not affected by the crash, and the explicit `.task`-driven refetch is correct for that view.
- AirPlay-specific UI beyond what `MPVolumeView` provides for free.
- Multi-episode queue behavior (next/previous track on lock screen) — Plan 7 Vibes.
- Sleep timer, playback speed, chapter markers — none of these are in scope and none require lock-screen plumbing changes when we eventually add them.
- Detection or repair of OPML malformation beyond unescaped `&` — anything the sanitize step doesn't handle still throws `.malformed(line:column:)`.
- Backporting `engine.duration` into `episode.durationSeconds`. The feed value remains the canonical metadata; only `playbackPosition` is corrected.
- Test coverage of `MPRemoteCommandCenter` wiring or `MPVolumeView` rendering — both are manual-verification only.

## Verification

**Per-task automated:**
- All existing tests continue to pass (current baseline: 73 tests after Plan 4 wrap).
- New regression test for #66 (post-delete fetch shape).
- New test for #28 duration mismatch.
- New tests for #42 (500 status from both services).
- New test for `URL.upgradedToHTTPS()` (#60).
- New OPML fixtures + tests for #59 (sanitizable + unrecoverable).

**Manual end-to-end (Task 9-equivalent at end of plan):**
1. **#66 crash gone**: subscribe to 4 podcasts, swipe-delete the middle one repeatedly with different middle indices — no crash.
2. **#64 background audio**: play episode → lock screen → audio continues; lock-screen shows artwork + title + scrubber; play/pause/skip/scrub from lock screen all work; phone-call interruption pauses then resumes; headphone unplug pauses.
3. **#65 system volume**: full-screen player shows MPVolumeView; hardware buttons adjust system volume; AirPlay picker visible.
4. **#28 duration**: play short episode to completion, confirm "0m left" (not e.g. "1m left").
5. **#42 server errors**: (offline / hosts file trick to force 500) — error surfaces in AddPodcastSheet with a clear message.
6. **#60 http upgrade**: re-import the OPML file with the 8 plain-http feeds (after deleting any previously-subscribed copies) — confirm all 8 succeed via https.
7. **#43 accessibility**: enable VoiceOver in simulator, navigate SearchResultRow states — all four states announce correctly.
8. **#59 lenient OPML**: re-import the original `Griffin & David` OPML *unmodified* — succeeds. Try a deliberately-broken file — error includes line/column.

## Dependencies and order

The 8 items are largely independent. Suggested ordering for implementation:

1. **#66** (crash) — first, structurally important (`@Query` migration); tests need to be updated before everything else lands so we have a clean baseline.
2. **#28** (duration) — small, isolated to `PlayerManager`.
3. **#65** (volume) — touches `AudioEngine` protocol + `PlayerManager` + view; do before #64 so audio engine is clean.
4. **#64** (background audio) — biggest item; AVAudioSession + capability + NowPlayingService.
5. **#42 + #60** (discovery hardening) — both touch URLSession-backed services; can land together.
6. **#59** (OPML) — independent.
7. **#43** (a11y) — independent, view-only.

Each lands as its own commit on the branch with tests passing. Final plan-wrapping verification is the manual end-to-end above, on real hardware where possible (volume + background audio behave differently in simulator).
