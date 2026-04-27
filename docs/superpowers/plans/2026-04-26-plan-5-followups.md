# Plan 5: Followups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land 8 polish/hardening/bug-fix items deferred from Plan 2/3/4 reviews — including a SwiftData detached-fault crash, background audio + lock-screen controls, system volume integration, HTTP status validation, http→https feed upgrade, OPML resilience, and accessibility — before starting visual-refresh / Vibes / Pinning work.

**Architecture:** Bug fix uses `@Query` migration (Apple-blessed pattern, fixes the whole class of cascade-during-animation issues). Audio integration introduces a separate `NowPlayingService` to keep `PlayerManager` focused on playback orchestration; two-way coupling via a small `PlaybackController` protocol seam. Discovery hardening is mechanical: validate HTTP status, upgrade scheme, sanitize parser input.

**Tech Stack:** Swift 5.9+, SwiftUI (`@Query`), SwiftData, AVFoundation (`AVAudioSession`), MediaPlayer (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`, `MPVolumeView`), XCTest.

**Spec:** `docs/superpowers/specs/2026-04-26-plan-5-followups-design.md` (commit `8472cc7`).

**Current baseline:** 73 tests passing on `iPhone 17 Pro` simulator.

---

## Task 1: Migrate `SubscriptionsListView` to `@Query`, drop `SubscriptionsViewModel`

**Why this task:** Fixes #66, the SwiftData detached-fault crash that triggers when SwiftUI re-evaluates a row body during the deletion animation. `@Query` is SwiftData's managed read path and handles deletion-animation lifecycle correctly because SwiftData controls both model invalidation and view update.

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`
- Modify: `Vibecast/Vibecast/Views/AddPodcastSheet.swift` (remove `viewModel?.fetch()` call)
- Delete: `Vibecast/Vibecast/ViewModels/SubscriptionsViewModel.swift`
- Delete: `Vibecast/VibecastTests/SubscriptionsViewModelTests.swift`
- Add: `Vibecast/VibecastTests/SubscriptionsRemovalTests.swift`

- [ ] **Step 1.1: Read current `SubscriptionsListView.swift` and inventory ViewModel touchpoints**

Read `Vibecast/Vibecast/Views/SubscriptionsListView.swift` end-to-end. Note every reference to `vm` / `viewModel`. Verify the call sites match what the spec migration table covers: `vm.podcasts`, `vm.fetch()`, `vm.remove`, `vm.markPlayed`, `vm.move`. No code change yet — this is to confirm no extra surface has crept in since the spec was written.

- [ ] **Step 1.2: Write the failing regression test for middle-row deletion**

Create `Vibecast/VibecastTests/SubscriptionsRemovalTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class SubscriptionsRemovalTests: XCTestCase {
    func test_middleRowDelete_leavesRemainingPodcastsIntact() throws {
        let schema = Schema([Podcast.self, Episode.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let titles = ["A", "B", "C", "D"]
        let podcasts = titles.enumerated().map { i, title in
            let p = Podcast(title: title, author: "x", artworkURL: nil, feedURL: "https://e.com/\(title)", sortPosition: i)
            context.insert(p)
            return p
        }
        try context.save()

        // Delete the middle row (index 2 — "C")
        let toDelete = podcasts[2]
        context.delete(toDelete)
        try context.save()

        let remaining = try context.fetch(
            FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
        )
        XCTAssertEqual(remaining.map(\.title), ["A", "B", "D"])
    }

    func test_repeatedMiddleDeletes_doNotCrash() throws {
        let schema = Schema([Podcast.self, Episode.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        for i in 0..<6 {
            let p = Podcast(title: "P\(i)", author: "a", artworkURL: nil, feedURL: "https://e.com/\(i)", sortPosition: i)
            context.insert(p)
            // Add an episode so cascade has something to do
            let ep = Episode(podcast: p, title: "ep\(i)", publishDate: .now, descriptionText: "", durationSeconds: 60, audioURL: "https://e.com/\(i).mp3")
            context.insert(ep)
        }
        try context.save()

        // Repeatedly delete the current middle index until 1 remains
        var current = try context.fetch(FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)]))
        while current.count > 1 {
            let middle = current[current.count / 2]
            context.delete(middle)
            try context.save()
            current = try context.fetch(FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)]))
        }
        XCTAssertEqual(current.count, 1)
    }
}
```

Note: this test confirms the SwiftData side of the deletion is safe — it can't reproduce the SwiftUI animation hazard directly (would require UI testing). The animation hazard fix is structural via `@Query`; this test guards the data layer.

- [ ] **Step 1.3: Run the test — expect it to PASS already**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/SubscriptionsRemovalTests 2>&1 | tail -20`

Expected: both new tests PASS (the data-layer behavior is already correct; the bug is purely in the UI render path).

- [ ] **Step 1.4: Replace `SubscriptionsListView` body with `@Query`-driven version**

Open `Vibecast/Vibecast/Views/SubscriptionsListView.swift`. Replace the entire `SubscriptionsListView` struct with:

```swift
import SwiftUI
import SwiftData

struct SubscriptionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.playerManager) private var playerManager
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Query(sort: [SortDescriptor(\Podcast.sortPosition)]) private var podcasts: [Podcast]

    @State private var selectedPodcast: Podcast?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            listContent
                .navigationTitle("Subscriptions")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddSheet) {
                    AddPodcastSheet()
                }
                .navigationDestination(item: $selectedPodcast) { podcast in
                    PodcastDetailView(podcast: podcast)
                }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if podcasts.isEmpty {
            ContentUnavailableView(
                "No podcasts yet",
                systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Tap + to search for podcasts or import an OPML file.")
            )
        } else {
            List {
                ForEach(podcasts) { podcast in
                    let latest = podcast.episodes.sorted(by: { $0.publishDate > $1.publishDate }).first
                    let isCurrent = latest != nil && latest?.persistentModelID == playerManager?.currentEpisode?.persistentModelID
                    PodcastRowView(
                        podcast: podcast,
                        isCurrent: isCurrent,
                        isPlaying: isCurrent && (playerManager?.isPlaying ?? false),
                        onPlay: {
                            guard let ep = latest, let mgr = playerManager else { return }
                            if mgr.currentEpisode?.persistentModelID == ep.persistentModelID {
                                mgr.togglePlayPause()
                            } else {
                                mgr.play(ep)
                            }
                        },
                        onOpenDetail: { selectedPodcast = podcast }
                    )
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            if let ep = podcast.episodes
                                .sorted(by: { $0.publishDate > $1.publishDate }).first {
                                markPlayed(ep)
                            }
                        } label: {
                            Label("Played", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            remove(podcast)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    move(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await subscriptionManager?.refreshAll()
            }
        }
    }

    private func remove(_ podcast: Podcast) {
        modelContext.delete(podcast)
        try? modelContext.save()
    }

    private func markPlayed(_ episode: Episode) {
        episode.listenedStatus = .played
        episode.playbackPosition = Double(episode.durationSeconds)
        try? modelContext.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = podcasts
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, podcast) in reordered.enumerated() {
            podcast.sortPosition = index
        }
        try? modelContext.save()
    }
}

#Preview {
    SubscriptionsListView()
        .modelContainer(SampleData.container)
}
```

- [ ] **Step 1.5: Update `AddPodcastSheet.swift` — remove `viewModel?.fetch()` call**

Read `Vibecast/Vibecast/Views/AddPodcastSheet.swift`. Find any reference to `SubscriptionsViewModel` or `viewModel?.fetch()`. The sheet was passing/calling the parent VM after subscribe — that's no longer needed because `@Query` auto-updates. Delete the parameter, the `@Bindable` if any, and the call site.

If the sheet currently takes `viewModel: SubscriptionsViewModel?` as a parameter, remove the parameter from its initializer entirely, and update any call site (in `SubscriptionsListView.sheet(isPresented:)` we already use `AddPodcastSheet()` with no args, so call sites should be clean).

- [ ] **Step 1.6: Delete `SubscriptionsViewModel.swift` and its tests**

Run:
```bash
rm Vibecast/Vibecast/ViewModels/SubscriptionsViewModel.swift
rm Vibecast/VibecastTests/SubscriptionsViewModelTests.swift
```

Then remove these from the Xcode project. The `.xcodeproj` references file paths in `project.pbxproj` — opening Xcode and deleting from the navigator handles this. Alternatively, edit `project.pbxproj` directly (search for `SubscriptionsViewModel.swift` and remove the `PBXFileReference`, `PBXBuildFile`, and `PBXGroup` children entries).

If editing `project.pbxproj` directly is tricky, the safer move is: open Xcode, remove the files via the navigator (right-click → Delete → Move to Trash), close Xcode, commit.

- [ ] **Step 1.7: Run full test suite — expect 70 tests passing (was 73 minus 5 deleted ViewModel tests plus 2 new regression tests)**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|Executed [0-9]+ tests" | tail -5`

Expected: `** TEST SUCCEEDED **` with ~70 tests run.

- [ ] **Step 1.8: Commit**

```bash
git add Vibecast/Vibecast/Views/SubscriptionsListView.swift \
        Vibecast/Vibecast/Views/AddPodcastSheet.swift \
        Vibecast/VibecastTests/SubscriptionsRemovalTests.swift \
        Vibecast/Vibecast.xcodeproj/project.pbxproj
git rm Vibecast/Vibecast/ViewModels/SubscriptionsViewModel.swift \
       Vibecast/VibecastTests/SubscriptionsViewModelTests.swift
git commit -m "fix: migrate SubscriptionsListView to @Query, drop SubscriptionsViewModel

Resolves SwiftData detached-fault crash on podcast removal. Cause was
SwiftUI re-evaluating PodcastRowView's body during the row-exit animation
on a tombstoned Podcast reference (cascade-deleted Episode property
faulted). @Query is SwiftData's managed read path and handles the
deletion-animation lifecycle correctly.

Inline the small handful of operations (remove/markPlayed/move) on the
View directly. Add SubscriptionsRemovalTests as a data-layer regression
guard."
```

---

## Task 2: Fix `handlePlaybackEnd` duration mismatch

**Why this task:** Fixes #28. When the engine reports playback complete, we currently set `playbackPosition = Double(episode.durationSeconds)` — but `durationSeconds` is feed-derived (Int, often rounded) and may differ slightly from the engine's actual duration. Result: row shows "1m left" or "−1m left" after a fully-played episode. Use `engine.duration` when available; fall back to feed value.

**Files:**
- Modify: `Vibecast/Vibecast/Audio/PlayerManager.swift`
- Modify: `Vibecast/VibecastTests/PlayerManagerTests.swift`

- [ ] **Step 2.1: Write the failing test**

Open `Vibecast/VibecastTests/PlayerManagerTests.swift`. Find the section testing `handlePlaybackEnd` (or `engine end-of-track` callback). Add:

```swift
func test_handlePlaybackEnd_usesEngineDuration_whenAvailable() throws {
    // Episode duration from feed: 1234 seconds (Int rounded).
    // Engine reports actual duration of 1234.5 seconds.
    let context = makeContext()
    let podcast = Podcast(title: "p", author: "a", artworkURL: nil, feedURL: "https://x.com")
    context.insert(podcast)
    let ep = Episode(podcast: podcast, title: "ep", publishDate: .now, descriptionText: "", durationSeconds: 1234, audioURL: "https://x.com/a.mp3")
    context.insert(ep)
    try context.save()

    let engine = MockAudioEngine()
    engine.duration = 1234.5
    let manager = PlayerManager(modelContext: context, engine: engine)

    manager.play(ep)
    engine.simulatePlaybackEnd()

    XCTAssertEqual(ep.playbackPosition, 1234.5, accuracy: 0.001)
    XCTAssertEqual(ep.listenedStatus, .played)
}

func test_handlePlaybackEnd_fallsBackToFeedDuration_whenEngineDurationZero() throws {
    let context = makeContext()
    let podcast = Podcast(title: "p", author: "a", artworkURL: nil, feedURL: "https://x.com")
    context.insert(podcast)
    let ep = Episode(podcast: podcast, title: "ep", publishDate: .now, descriptionText: "", durationSeconds: 1234, audioURL: "https://x.com/a.mp3")
    context.insert(ep)
    try context.save()

    let engine = MockAudioEngine()
    engine.duration = 0   // engine never resolved actual duration
    let manager = PlayerManager(modelContext: context, engine: engine)

    manager.play(ep)
    engine.simulatePlaybackEnd()

    XCTAssertEqual(ep.playbackPosition, 1234.0, accuracy: 0.001)
}
```

If `MockAudioEngine` doesn't expose `simulatePlaybackEnd()`, check the existing test file for the equivalent — it should be a way to invoke the engine's `onEnd` callback.

- [ ] **Step 2.2: Run tests — expect FAIL on `test_handlePlaybackEnd_usesEngineDuration_whenAvailable`**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/PlayerManagerTests/test_handlePlaybackEnd_usesEngineDuration_whenAvailable 2>&1 | tail -20`

Expected: FAIL with `XCTAssertEqual failed: ("1234.0") is not equal to ("1234.5")`.

- [ ] **Step 2.3: Fix `handlePlaybackEnd` in `PlayerManager.swift`**

Open `Vibecast/Vibecast/Audio/PlayerManager.swift`. Replace the body of `handlePlaybackEnd()`:

```swift
private func handlePlaybackEnd() {
    guard let episode = currentEpisode else { return }
    episode.listenedStatus = .played
    let canonicalDuration = duration > 0 ? duration : Double(episode.durationSeconds)
    episode.playbackPosition = canonicalDuration
    elapsed = canonicalDuration
    isPlaying = false
    try? modelContext.save()
    lastPersistedAt = elapsed
}
```

Where `duration` is the existing `var duration: TimeInterval` already on `PlayerManager` (mirror of `engine.duration`). If `PlayerManager` doesn't currently mirror `engine.duration` as a property, read directly: `let canonicalDuration = engine.duration > 0 ? engine.duration : Double(episode.durationSeconds)`.

- [ ] **Step 2.4: Run tests — expect both new tests PASS**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/PlayerManagerTests 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|Executed" | tail -3`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2.5: Commit**

```bash
git add Vibecast/Vibecast/Audio/PlayerManager.swift \
        Vibecast/VibecastTests/PlayerManagerTests.swift
git commit -m "fix: use engine.duration in handlePlaybackEnd to avoid feed/actual mismatch

Feed-derived durationSeconds is an Int rounded from RSS metadata; engine
duration is the actual track duration. Storing the engine value into
playbackPosition keeps the played episode visually pinned to 100% rather
than 99% or 101%."
```

---

## Task 3: Remove in-app volume slider; add `MPVolumeView`

**Why this task:** Fixes #65. The in-app volume slider fights iOS — hardware buttons, Control Center, and AirPods all bypass it. Apple's `MPVolumeView` is the only sanctioned way to render a system-volume slider in-app and gives the AirPlay route picker for free.

**Files:**
- Modify: `Vibecast/Vibecast/Audio/AudioEngine.swift` (drop volume from protocol)
- Modify: `Vibecast/Vibecast/Audio/AVPlayerAudioEngine.swift` (drop volume property)
- Modify: `Vibecast/Vibecast/Audio/PlayerManager.swift` (drop volume mirror)
- Modify: `Vibecast/Vibecast/Views/FullScreenPlayerView.swift` (replace Slider with SystemVolumeView)
- Add: `Vibecast/Vibecast/Views/SystemVolumeView.swift`
- Modify: `Vibecast/VibecastTests/PlayerManagerTests.swift` (remove volume test cases)

- [ ] **Step 3.1: Read current volume surface to inventory deletion targets**

Read these files to find every `volume` reference:
- `Vibecast/Vibecast/Audio/AudioEngine.swift`
- `Vibecast/Vibecast/Audio/AVPlayerAudioEngine.swift`
- `Vibecast/Vibecast/Audio/PlayerManager.swift`
- `Vibecast/Vibecast/Views/FullScreenPlayerView.swift`
- `Vibecast/VibecastTests/PlayerManagerTests.swift`

Use: `grep -n "volume" Vibecast/Vibecast/Audio/*.swift Vibecast/Vibecast/Views/FullScreenPlayerView.swift Vibecast/VibecastTests/PlayerManagerTests.swift`

- [ ] **Step 3.2: Create `SystemVolumeView.swift`**

Create `Vibecast/Vibecast/Views/SystemVolumeView.swift`:

```swift
import SwiftUI
import MediaPlayer

/// Wraps `MPVolumeView` so SwiftUI can host it. `MPVolumeView` shows the
/// system volume slider plus the AirPlay route-picker button. It writes to
/// system volume — no app-private state.
///
/// Note: in the iOS Simulator the slider renders blank/disabled. Verify on a
/// device.
struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = true
        view.showsVolumeSlider = true
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
```

- [ ] **Step 3.3: Drop volume from `AudioEngine` protocol**

Open `Vibecast/Vibecast/Audio/AudioEngine.swift`. Delete:
- The `var volume: Float { get set }` requirement (or any equivalent — match the existing pattern).

- [ ] **Step 3.4: Drop volume from `AVPlayerAudioEngine`**

Open `Vibecast/Vibecast/Audio/AVPlayerAudioEngine.swift`. Delete:
- The `var volume: Float` stored property
- Any `setVolume` method
- Any place where `AVPlayer.volume` is set in code (let it default to 1.0 — `AVAudioSession` delivers system volume)

- [ ] **Step 3.5: Drop volume from `PlayerManager`**

Open `Vibecast/Vibecast/Audio/PlayerManager.swift`. Delete:
- Any `var volume` mirror
- Any setter that propagates volume to the engine
- Anything else `volume`-related in the manager

- [ ] **Step 3.6: Replace Slider in `FullScreenPlayerView` with `SystemVolumeView`**

Open `Vibecast/Vibecast/Views/FullScreenPlayerView.swift`. Find the `Slider` bound to volume. Replace it with:

```swift
SystemVolumeView()
    .frame(height: 44)
    .padding(.horizontal)
```

Adjust frame and padding to match the surrounding visual rhythm — `MPVolumeView`'s default height is around 30pt; 44pt gives it a comfortable touch target. If the existing slider had volume-up/-down icons flanking it, keep those (purely decorative now — they can remain, they just won't be wired since `MPVolumeView` provides the slider).

- [ ] **Step 3.7: Strip volume tests from `PlayerManagerTests`**

Open `Vibecast/VibecastTests/PlayerManagerTests.swift`. Delete all volume-related test cases (any `func test_volume...`, any `manager.volume = ` setup, any volume assertions).

- [ ] **Step 3.8: Build and run tests — expect green**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -10`

Expected: `** TEST SUCCEEDED **`. Test count drops by however many volume cases existed.

- [ ] **Step 3.9: Commit**

```bash
git add Vibecast/Vibecast/Audio/AudioEngine.swift \
        Vibecast/Vibecast/Audio/AVPlayerAudioEngine.swift \
        Vibecast/Vibecast/Audio/PlayerManager.swift \
        Vibecast/Vibecast/Views/FullScreenPlayerView.swift \
        Vibecast/Vibecast/Views/SystemVolumeView.swift \
        Vibecast/VibecastTests/PlayerManagerTests.swift \
        Vibecast/Vibecast.xcodeproj/project.pbxproj
git commit -m "feat: replace in-app volume slider with MPVolumeView

Remove the custom Slider that maintained app-private volume state
(fighting hardware buttons, Control Center, AirPods). MPVolumeView is
Apple's system-volume control and gives the AirPlay route picker for
free. Drop the volume property from AudioEngine protocol, AVPlayerAudioEngine,
and PlayerManager. Simulator note: MPVolumeView renders blank in
simulator — confirm on device."
```

---

## Task 4: AVAudioSession configuration + interruption / route handling

**Why this task:** Implements piece 1 of #64. Without `.playback` category + active session, audio stops when the app backgrounds or the screen locks. `.spokenAudio` mode is Apple's correct mode for podcasts (handles AirPods/Bluetooth/CarPlay routing properly). Interruption handling pauses on phone calls and resumes after; route-change handling pauses on headphone unplug.

**Files:**
- Modify: `Vibecast/Vibecast/Audio/AVPlayerAudioEngine.swift`

- [ ] **Step 4.1: Read `AVPlayerAudioEngine.swift` to confirm shape before editing**

Read the file. Note the constructor signature, where it owns the `AVPlayer`, and whether it currently has any session-related config (it shouldn't).

- [ ] **Step 4.2: Add AVAudioSession configuration in init**

In `AVPlayerAudioEngine.init`, after the existing setup, add:

```swift
import AVFoundation  // ensure this is at file scope

// In init (or a private configure() called from init):
do {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
    try session.setActive(true)
} catch {
    // Audio session config failure is rare and non-fatal — log and continue.
    // Playback will still work in the foreground.
    print("[AVPlayerAudioEngine] Failed to configure audio session: \(error)")
}
```

- [ ] **Step 4.3: Add interruption handling**

Still in `AVPlayerAudioEngine`, add a private observer setup. Stored properties:

```swift
private var interruptionObserver: NSObjectProtocol?
private var routeChangeObserver: NSObjectProtocol?
```

Add a private method `configureNotifications()` called from init after session setup:

```swift
private func configureNotifications() {
    let center = NotificationCenter.default

    interruptionObserver = center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard
            let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            self?.handleInterruptionBegan()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self?.handleInterruptionEndedShouldResume()
                }
            }
        @unknown default: break
        }
    }

    routeChangeObserver = center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        if reason == .oldDeviceUnavailable {
            self?.handleRouteOldDeviceUnavailable()
        }
    }
}
```

In `deinit`:

```swift
deinit {
    if let token = interruptionObserver { NotificationCenter.default.removeObserver(token) }
    if let token = routeChangeObserver { NotificationCenter.default.removeObserver(token) }
}
```

- [ ] **Step 4.4: Wire interruption/route callbacks back to the player**

`AVPlayerAudioEngine` needs to pause on interruption-began / device-unavailable and resume on interruption-ended-shouldResume. The cleanest seam is closures the engine exposes (since `PlayerManager` may want to know about state changes):

Add to `AVPlayerAudioEngine`:

```swift
/// Called when an audio session interruption begins (phone call, etc).
/// Default behavior pauses internally; consumers can override to also
/// update their own state.
var onInterruptionBegan: (() -> Void)?

/// Called when an audio session interruption ends and the system signals
/// `.shouldResume`. For spoken-audio policy this is the normal "resume"
/// path; consumers should restart playback if appropriate.
var onInterruptionEndedShouldResume: (() -> Void)?

/// Called when an audio output route becomes unavailable (headphone unplug).
var onRouteOldDeviceUnavailable: (() -> Void)?

private func handleInterruptionBegan() {
    pause()
    onInterruptionBegan?()
}

private func handleInterruptionEndedShouldResume() {
    onInterruptionEndedShouldResume?()
}

private func handleRouteOldDeviceUnavailable() {
    pause()
    onRouteOldDeviceUnavailable?()
}
```

`PlayerManager` already owns `isPlaying` state. Update its init to wire these:

In `PlayerManager.init`, after setting up the engine:

```swift
// If the engine is concrete AVPlayerAudioEngine, route system events
// through to manager state. This is intentionally protocol-tagged: only
// AVPlayerAudioEngine emits these; mocks don't.
if let av = engine as? AVPlayerAudioEngine {
    av.onInterruptionBegan = { [weak self] in
        self?.isPlaying = false
    }
    av.onInterruptionEndedShouldResume = { [weak self] in
        guard let self, self.currentEpisode != nil else { return }
        self.engine.play()
        self.isPlaying = true
    }
    av.onRouteOldDeviceUnavailable = { [weak self] in
        self?.isPlaying = false
    }
}
```

(This concrete-type cast is a small wart but keeps the protocol clean for tests. Alternative: add the callbacks to `AudioEngine` protocol with default no-op implementations. Pick one based on existing protocol style — if there are already callbacks like `onTimeUpdate`/`onEnd`, these belong on the protocol too.)

**Decision rule:** If `AudioEngine` protocol already declares the existing time/end callbacks, add the three new ones there with default empty closures. Otherwise the cast is fine.

- [ ] **Step 4.5: Build and run tests — expect green (no behavioral change to existing tests)**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -10`

Expected: `** TEST SUCCEEDED **`. New code is on the AVPlayer concrete path; mocked engine in tests doesn't fire these.

- [ ] **Step 4.6: Commit**

```bash
git add Vibecast/Vibecast/Audio/AVPlayerAudioEngine.swift \
        Vibecast/Vibecast/Audio/AudioEngine.swift \
        Vibecast/Vibecast/Audio/PlayerManager.swift
git commit -m "feat: configure AVAudioSession for spoken audio + handle interruptions

Set .playback / .spokenAudio / .longFormAudio so audio plays in background
and routes correctly to AirPods/Bluetooth/CarPlay. Observe interruption
notifications: pause on .began, auto-resume on .ended with .shouldResume.
Observe route changes: pause on .oldDeviceUnavailable (headphone unplug).
Wire to PlayerManager so isPlaying stays consistent."
```

---

## Task 5: Enable `UIBackgroundModes = audio` capability

**Why this task:** Implements piece 2 of #64. Without this capability flag, iOS suspends the app when backgrounded and audio stops mid-track — even with `AVAudioSession.playback` configured. This is a project-file change, not a code change.

**Files:**
- Modify: `Vibecast/Vibecast.xcodeproj/project.pbxproj`

- [ ] **Step 5.1: Add UIBackgroundModes to both Debug and Release configurations**

Open `Vibecast/Vibecast.xcodeproj/project.pbxproj`. Find the two app-target build configurations (Debug + Release). They each have `INFOPLIST_KEY_*` entries (e.g., `INFOPLIST_KEY_UIApplicationSceneManifest_Generation`). Add:

```
INFOPLIST_KEY_UIBackgroundModes = audio;
```

To both Debug and Release. The flag value `audio` is the array entry shorthand Xcode emits when only one mode is set — that maps to `UIBackgroundModes = ["audio"]` in the generated Info.plist.

If the project uses an array form like `INFOPLIST_KEY_UIBackgroundModes = (audio)` for some reason, match that format.

- [ ] **Step 5.2: Verify the change is present**

Run: `grep -n 'UIBackgroundModes' Vibecast/Vibecast.xcodeproj/project.pbxproj`

Expected: two lines (one per configuration), both containing `audio`.

- [ ] **Step 5.3: Build and run tests — expect green**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -5`

Expected: `** TEST SUCCEEDED **`. No code changed; this just enables the capability.

- [ ] **Step 5.4: Commit**

```bash
git add Vibecast/Vibecast.xcodeproj/project.pbxproj
git commit -m "feat: enable UIBackgroundModes=audio capability

Required for AVAudioSession playback to actually continue when the app
is backgrounded or the screen is locked. Pairs with the AVAudioSession
configuration from the prior commit."
```

---

## Task 6: NowPlayingService + remote command center wiring

**Why this task:** Implements piece 3 of #64. Lock-screen, Control Center, AirPods, and CarPlay all read from `MPNowPlayingInfoCenter` and dispatch commands through `MPRemoteCommandCenter`. Without this, the user sees a generic "Vibecast" placeholder on the lock screen and can't play/pause/skip from external surfaces.

**Files:**
- Add: `Vibecast/Vibecast/Audio/NowPlayingService.swift`
- Add: `Vibecast/Vibecast/Audio/PlaybackController.swift`
- Modify: `Vibecast/Vibecast/Audio/PlayerManager.swift`
- Modify: `Vibecast/Vibecast/VibecastApp.swift`
- Add: `Vibecast/VibecastTests/NowPlayingServiceTests.swift`

- [ ] **Step 6.1: Define the `PlaybackController` protocol**

Create `Vibecast/Vibecast/Audio/PlaybackController.swift`:

```swift
import Foundation

/// Methods `NowPlayingService` invokes in response to lock-screen / Control
/// Center / AirPods commands. `PlayerManager` conforms.
@MainActor
protocol PlaybackController: AnyObject {
    func togglePlayPause()
    func seek(to seconds: TimeInterval)
    func skipForward(_ seconds: TimeInterval)
    func skipBack(_ seconds: TimeInterval)
}
```

`PlayerManager` already has all four methods with these signatures (from Plan 2). Adding `: PlaybackController` to its declaration is a one-line conformance.

- [ ] **Step 6.2: Make `PlayerManager` conform to `PlaybackController`**

Open `Vibecast/Vibecast/Audio/PlayerManager.swift`. Update the class declaration:

```swift
@Observable
@MainActor
final class PlayerManager: PlaybackController {
    // ... existing code unchanged
}
```

No method signatures need to change. Build to confirm conformance compiles.

- [ ] **Step 6.3: Define `PlaybackState` and write the failing `NowPlayingService` test**

Create `Vibecast/VibecastTests/NowPlayingServiceTests.swift`:

```swift
import XCTest
import MediaPlayer
@testable import Vibecast

@MainActor
final class NowPlayingServiceTests: XCTestCase {
    func test_update_populatesNowPlayingInfo_withRequiredKeys() {
        let service = NowPlayingService()
        let state = PlaybackState(
            episodeTitle: "Hard Fork: AI Bubbles",
            podcastTitle: "Hard Fork",
            author: "The New York Times",
            duration: 3600,
            elapsed: 120,
            isPlaying: true,
            artworkURL: nil
        )

        service.update(state: state)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        XCTAssertEqual(info[MPMediaItemPropertyTitle] as? String, "Hard Fork: AI Bubbles")
        XCTAssertEqual(info[MPMediaItemPropertyAlbumTitle] as? String, "Hard Fork")
        XCTAssertEqual(info[MPMediaItemPropertyArtist] as? String, "The New York Times")
        XCTAssertEqual(info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval, 3600)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval, 120)
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)
    }

    func test_update_paused_setsRateZero() {
        let service = NowPlayingService()
        let state = PlaybackState(
            episodeTitle: "x", podcastTitle: "x", author: "x",
            duration: 100, elapsed: 50, isPlaying: false, artworkURL: nil
        )
        service.update(state: state)
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        XCTAssertEqual(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0.0)
    }

    func test_clear_emptiesNowPlayingInfo() {
        let service = NowPlayingService()
        service.update(state: PlaybackState(
            episodeTitle: "x", podcastTitle: "x", author: "x",
            duration: 100, elapsed: 0, isPlaying: false, artworkURL: nil
        ))
        service.clear()
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
    }
}
```

- [ ] **Step 6.4: Run tests — expect compile failure (`NowPlayingService` doesn't exist yet)**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/NowPlayingServiceTests 2>&1 | tail -10`

Expected: compile error "Cannot find 'NowPlayingService'" / "Cannot find 'PlaybackState'".

- [ ] **Step 6.5: Implement `NowPlayingService`**

Create `Vibecast/Vibecast/Audio/NowPlayingService.swift`:

```swift
import Foundation
import MediaPlayer
import UIKit

/// Snapshot of the current playback state, passed to `NowPlayingService.update`.
struct PlaybackState {
    let episodeTitle: String
    let podcastTitle: String
    let author: String
    let duration: TimeInterval
    let elapsed: TimeInterval
    let isPlaying: Bool
    let artworkURL: URL?
}

@Observable
@MainActor
final class NowPlayingService {
    /// Routes lock-screen / Control Center / AirPods commands back to
    /// the player. Set during app wiring.
    weak var controller: (any PlaybackController)?

    /// Cache of resolved artwork keyed by URL string.
    private var artworkCache: [String: UIImage] = [:]
    private var lastArtworkURL: URL?

    private let infoCenter = MPNowPlayingInfoCenter.default()

    init() {
        configureRemoteCommands()
    }

    // MARK: - Public API

    /// Push current playback state to the system. Call on play, pause,
    /// seek, episode-change. The system extrapolates `elapsed` from
    /// `playbackRate` so per-tick updates are not needed.
    func update(state: PlaybackState) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = state.episodeTitle
        info[MPMediaItemPropertyAlbumTitle] = state.podcastTitle
        info[MPMediaItemPropertyArtist] = state.author
        info[MPMediaItemPropertyPlaybackDuration] = state.duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.isPlaying ? 1.0 : 0.0

        if let cached = state.artworkURL.flatMap({ artworkCache[$0.absoluteString] }) {
            info[MPMediaItemPropertyArtwork] = makeArtwork(image: cached)
        }

        infoCenter.nowPlayingInfo = info

        // Async-load artwork if not cached and write back when ready.
        if let url = state.artworkURL,
           artworkCache[url.absoluteString] == nil,
           lastArtworkURL != url {
            lastArtworkURL = url
            Task { [weak self] in
                guard let image = await self?.loadImage(from: url) else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.artworkCache[url.absoluteString] = image
                    var current = self.infoCenter.nowPlayingInfo ?? [:]
                    current[MPMediaItemPropertyArtwork] = self.makeArtwork(image: image)
                    self.infoCenter.nowPlayingInfo = current
                }
            }
        }
    }

    /// Clear all Now Playing info (e.g., when no episode is loaded).
    func clear() {
        infoCenter.nowPlayingInfo = nil
        lastArtworkURL = nil
    }

    // MARK: - Private

    private func makeArtwork(image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func loadImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.controller?.togglePlayPause()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.controller?.togglePlayPause()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.controller?.togglePlayPause()
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 30
            self?.controller?.skipForward(interval)
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            self?.controller?.skipBack(interval)
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let pos = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                return .commandFailed
            }
            self?.controller?.seek(to: pos)
            return .success
        }

        // Multi-episode queue is Plan 7 territory.
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }
}
```

- [ ] **Step 6.6: Run NowPlayingService tests — expect PASS**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/NowPlayingServiceTests 2>&1 | tail -15`

Expected: 3 tests PASS.

- [ ] **Step 6.7: Wire `NowPlayingService` into `PlayerManager`**

Open `Vibecast/Vibecast/Audio/PlayerManager.swift`. Add a stored property and constructor parameter:

```swift
private let nowPlaying: NowPlayingService

init(modelContext: ModelContext, engine: any AudioEngine, nowPlaying: NowPlayingService) {
    self.modelContext = modelContext
    self.engine = engine
    self.nowPlaying = nowPlaying
    // ... existing setup
}
```

Add a private helper:

```swift
private func publishNowPlaying() {
    guard let episode = currentEpisode else {
        nowPlaying.clear()
        return
    }
    let state = PlaybackState(
        episodeTitle: episode.title,
        podcastTitle: episode.podcast?.title ?? "",
        author: episode.podcast?.author ?? "",
        duration: duration > 0 ? duration : Double(episode.durationSeconds),
        elapsed: elapsed,
        isPlaying: isPlaying,
        artworkURL: episode.podcast?.artworkURL.flatMap(URL.init(string:))
    )
    nowPlaying.update(state: state)
}
```

Call `publishNowPlaying()` at the end of these methods:
- `play(_:)`
- `togglePlayPause()`
- `seek(to:)`
- `handlePlaybackEnd()`
- The interruption-resume callback (added in Task 4)

- [ ] **Step 6.8: Update `VibecastApp.swift` to instantiate and connect `NowPlayingService`**

Open `Vibecast/Vibecast/VibecastApp.swift`. Where `PlayerManager` is currently instantiated, add:

```swift
let nowPlaying = NowPlayingService()
let playerManager = PlayerManager(
    modelContext: container.mainContext,
    engine: AVPlayerAudioEngine(),
    nowPlaying: nowPlaying
)
nowPlaying.controller = playerManager
```

If the existing wiring uses `@State` or environment injection, fold these in following the same pattern. The order matters: `nowPlaying` must be created before `playerManager`, and `nowPlaying.controller = playerManager` must happen after both exist.

- [ ] **Step 6.9: Update existing `PlayerManagerTests` to pass `nowPlaying`**

Open `Vibecast/VibecastTests/PlayerManagerTests.swift`. Find every `PlayerManager(modelContext:, engine:)` instantiation. Update each to:

```swift
PlayerManager(modelContext: context, engine: engine, nowPlaying: NowPlayingService())
```

`MPNowPlayingInfoCenter` writes from a real `NowPlayingService` are harmless in the test bundle — they update the system info center but no test asserts on it. We don't introduce a default-value parameter on the init; the explicit call site keeps construction predictable.

- [ ] **Step 6.10: Build and run full test suite**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -10`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6.11: Commit**

```bash
git add Vibecast/Vibecast/Audio/NowPlayingService.swift \
        Vibecast/Vibecast/Audio/PlaybackController.swift \
        Vibecast/Vibecast/Audio/PlayerManager.swift \
        Vibecast/Vibecast/VibecastApp.swift \
        Vibecast/VibecastTests/NowPlayingServiceTests.swift \
        Vibecast/VibecastTests/PlayerManagerTests.swift \
        Vibecast/Vibecast.xcodeproj/project.pbxproj
git commit -m "feat: NowPlayingService for lock-screen + remote commands

Adds MPNowPlayingInfoCenter integration (title, podcast, artist, duration,
elapsed, playback rate, async-loaded artwork) and MPRemoteCommandCenter
wiring (play, pause, toggle, skip ±30/15, seek). PlayerManager conforms
to a small PlaybackController protocol so NowPlayingService routes commands
back without a circular import. Multi-track commands (next/previous)
disabled — queue is Plan 7."
```

---

## Task 7: HTTP status validation in `iTunesSearchService` and `URLSessionFeedFetcher`

**Why this task:** Implements #42. Both services currently rely on URLSession's thrown `URLError` and downstream parse errors — they don't validate the HTTP status. A 500 with empty body parses as "no results" / fails downstream as a parse error rather than surfacing a server error.

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/PodcastSearchService.swift`
- Modify: `Vibecast/Vibecast/Discovery/FeedFetcher.swift`
- Modify: `Vibecast/VibecastTests/PodcastSearchServiceTests.swift`
- Modify: `Vibecast/VibecastTests/FeedFetcherTests.swift`

- [ ] **Step 7.1: Write failing tests for both services**

In `Vibecast/VibecastTests/PodcastSearchServiceTests.swift`, add:

```swift
func test_search_throwsServerError_on500Response() async throws {
    MockURLProtocol.handler = { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }
    let session = MockURLProtocol.makeSession()
    let service = iTunesSearchService(session: session)

    do {
        _ = try await service.search("anything")
        XCTFail("expected error")
    } catch let error as PodcastSearchError {
        XCTAssertEqual(error, .serverError(status: 500))
    } catch {
        XCTFail("expected PodcastSearchError, got \(error)")
    }
}
```

In `Vibecast/VibecastTests/FeedFetcherTests.swift`, add:

```swift
func test_fetch_throwsServerError_on503Response() async throws {
    MockURLProtocol.handler = { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        return (response, Data())
    }
    let session = MockURLProtocol.makeSession()
    let fetcher = URLSessionFeedFetcher(session: session)

    do {
        _ = try await fetcher.fetch(URL(string: "https://example.com/feed")!)
        XCTFail("expected error")
    } catch let error as FeedFetchError {
        XCTAssertEqual(error, .serverError(status: 503))
    } catch {
        XCTFail("expected FeedFetchError, got \(error)")
    }
}
```

- [ ] **Step 7.2: Run tests — expect compile failures (`PodcastSearchError`, `FeedFetchError` don't exist)**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/PodcastSearchServiceTests/test_search_throwsServerError_on500Response 2>&1 | tail -10`

Expected: compile error "Cannot find 'PodcastSearchError'".

- [ ] **Step 7.3: Add `PodcastSearchError` and validate status in `iTunesSearchService`**

Open `Vibecast/Vibecast/Discovery/PodcastSearchService.swift`. Add at file scope (before or after the protocol):

```swift
enum PodcastSearchError: Error, Equatable {
    case invalidResponse
    case serverError(status: Int)
}
```

Update `iTunesSearchService.search`:

```swift
let (data, response) = try await session.data(from: url)
guard let http = response as? HTTPURLResponse else { throw PodcastSearchError.invalidResponse }
guard (200..<300).contains(http.statusCode) else {
    throw PodcastSearchError.serverError(status: http.statusCode)
}
let envelope = try JSONDecoder().decode(ITunesSearchEnvelope.self, from: data)
// ... existing code unchanged
```

- [ ] **Step 7.4: Add `FeedFetchError` and validate status in `URLSessionFeedFetcher`**

Open `Vibecast/Vibecast/Discovery/FeedFetcher.swift`. Add at file scope:

```swift
enum FeedFetchError: Error, Equatable {
    case invalidResponse
    case serverError(status: Int)
}
```

Update `URLSessionFeedFetcher.fetch`:

```swift
func fetch(_ feedURL: URL) async throws -> ParsedFeed {
    let (data, response) = try await session.data(from: feedURL)
    guard let http = response as? HTTPURLResponse else { throw FeedFetchError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
        throw FeedFetchError.serverError(status: http.statusCode)
    }
    return try RSSParser().parse(data)
}
```

- [ ] **Step 7.5: Run tests — expect both new tests PASS**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -5`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7.6: Commit**

```bash
git add Vibecast/Vibecast/Discovery/PodcastSearchService.swift \
        Vibecast/Vibecast/Discovery/FeedFetcher.swift \
        Vibecast/VibecastTests/PodcastSearchServiceTests.swift \
        Vibecast/VibecastTests/FeedFetcherTests.swift
git commit -m "feat: validate HTTP status in iTunesSearchService and FeedFetcher

A 500 with empty body previously parsed as 'no results' / failed
downstream as a parse error. Now both services check for HTTPURLResponse
and (200..<300) status, throwing .serverError(status:) otherwise. Adds
named PodcastSearchError and FeedFetchError enums."
```

---

## Task 8: Auto-upgrade `http://` feed URLs to `https://`

**Why this task:** Implements #60. ATS blocks plain `http://` requests. During Plan 4 OPML real-world testing, 8 plain-http feeds in the user's export silently failed import; all 8 had working https mirrors. Unconditional upgrade fixes the realistic case; if https fails, the original http would have been ATS-blocked anyway, and the https error message is clearer.

**Files:**
- Add: `Vibecast/Vibecast/Discovery/URL+UpgradeScheme.swift`
- Modify: `Vibecast/Vibecast/Discovery/FeedFetcher.swift`
- Add: `Vibecast/VibecastTests/URLUpgradeSchemeTests.swift`

- [ ] **Step 8.1: Write the failing test for the URL extension**

Create `Vibecast/VibecastTests/URLUpgradeSchemeTests.swift`:

```swift
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
```

- [ ] **Step 8.2: Run tests — expect compile failure (`upgradedToHTTPS` doesn't exist)**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/URLUpgradeSchemeTests 2>&1 | tail -10`

Expected: compile error.

- [ ] **Step 8.3: Implement `URL.upgradedToHTTPS()`**

Create `Vibecast/Vibecast/Discovery/URL+UpgradeScheme.swift`:

```swift
import Foundation

extension URL {
    /// Returns a copy of this URL with the scheme upgraded from `http`
    /// to `https`. Returns self unchanged for `https` URLs or any other
    /// scheme.
    func upgradedToHTTPS() -> URL {
        guard scheme?.lowercased() == "http" else { return self }
        var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)
        comps?.scheme = "https"
        return comps?.url ?? self
    }
}
```

- [ ] **Step 8.4: Use it in `URLSessionFeedFetcher.fetch`**

Open `Vibecast/Vibecast/Discovery/FeedFetcher.swift`. Update `fetch`:

```swift
func fetch(_ feedURL: URL) async throws -> ParsedFeed {
    let url = feedURL.upgradedToHTTPS()
    let (data, response) = try await session.data(from: url)
    guard let http = response as? HTTPURLResponse else { throw FeedFetchError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
        throw FeedFetchError.serverError(status: http.statusCode)
    }
    return try RSSParser().parse(data)
}
```

- [ ] **Step 8.5: Run tests — expect all PASS**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -5`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8.6: Commit**

```bash
git add Vibecast/Vibecast/Discovery/URL+UpgradeScheme.swift \
        Vibecast/Vibecast/Discovery/FeedFetcher.swift \
        Vibecast/VibecastTests/URLUpgradeSchemeTests.swift \
        Vibecast/Vibecast.xcodeproj/project.pbxproj
git commit -m "feat: auto-upgrade http:// feed URLs to https://

ATS blocks plain http requests; modern feed hosts virtually all serve
https. Plan 4 OPML testing surfaced 8 plain-http feeds — all 8 had
working https mirrors. Unconditional upgrade in URLSessionFeedFetcher
plus a small URL extension."
```

---

## Task 9: Lenient OPML parser + better diagnostics

**Why this task:** Implements #59. The current `StandardOPMLImporter` rejects the user's real Apple Podcasts export because of an unescaped `&` in `Griffin & David`. Pre-sanitize unescaped ampersands (the realistic 90%); surface line/column on truly-broken input.

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/OPMLImporter.swift`
- Modify: `Vibecast/VibecastTests/OPMLImporterTests.swift`
- Add: `Vibecast/VibecastTests/Fixtures/opml-unescaped-ampersand.opml`
- Add: `Vibecast/VibecastTests/Fixtures/opml-unrecoverable.opml`

- [ ] **Step 9.1: Add fixtures**

Create `Vibecast/VibecastTests/Fixtures/opml-unescaped-ampersand.opml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Sanitizable</title></head>
<body>
  <outline text="Griffin & David" type="rss" xmlUrl="https://example.com/g-and-d.rss"/>
  <outline text="Hard Fork" type="rss" xmlUrl="https://example.com/hard-fork.rss"/>
</body>
</opml>
```

Create `Vibecast/VibecastTests/Fixtures/opml-unrecoverable.opml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Broken</title></head>
<body>
  <outline text="x" xmlUrl="<bad>"/>
  <outline unclosed
</body>
```

- [ ] **Step 9.2: Add fixtures to the Xcode test target**

In Xcode, drag both files into `VibecastTests/Fixtures/`. Ensure they're added to the `VibecastTests` target. Save and verify they appear in `project.pbxproj` under the test target's resources.

- [ ] **Step 9.3: Write failing tests**

Open `Vibecast/VibecastTests/OPMLImporterTests.swift`. Add:

```swift
func test_importer_sanitizesUnescapedAmpersand_andSucceeds() throws {
    let url = Bundle(for: type(of: self)).url(forResource: "opml-unescaped-ampersand", withExtension: "opml")!
    let data = try Data(contentsOf: url)

    let importer = StandardOPMLImporter()
    let urls = try importer.extractFeedURLs(from: data)

    XCTAssertEqual(urls.count, 2)
    XCTAssertTrue(urls.contains(URL(string: "https://example.com/g-and-d.rss")!))
    XCTAssertTrue(urls.contains(URL(string: "https://example.com/hard-fork.rss")!))
}

func test_importer_throwsMalformedWithLineColumn_onUnrecoverableInput() throws {
    let url = Bundle(for: type(of: self)).url(forResource: "opml-unrecoverable", withExtension: "opml")!
    let data = try Data(contentsOf: url)

    let importer = StandardOPMLImporter()
    do {
        _ = try importer.extractFeedURLs(from: data)
        XCTFail("expected error")
    } catch let error as OPMLImportError {
        if case .malformed(let line, let column) = error {
            XCTAssertGreaterThan(line, 0)
            XCTAssertGreaterThan(column, 0)
        } else {
            XCTFail("expected .malformed(line:column:), got \(error)")
        }
    }
}
```

- [ ] **Step 9.4: Run tests — expect FAIL (sanitize doesn't exist; line/column not in error case)**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/OPMLImporterTests 2>&1 | tail -15`

Expected: at least one failure.

- [ ] **Step 9.5: Add pre-sanitize step + line/column error**

Open `Vibecast/Vibecast/Discovery/OPMLImporter.swift`. Update the error enum:

```swift
enum OPMLImportError: Error, LocalizedError, Equatable {
    case malformed(line: Int, column: Int)

    var errorDescription: String? {
        switch self {
        case .malformed(let line, let col):
            return "Couldn't parse OPML at line \(line), column \(col). Make sure it's a valid OPML export."
        }
    }
}
```

Add the regex constant on `StandardOPMLImporter`:

```swift
private static let unescapedAmpersand = try! NSRegularExpression(
    pattern: "&(?!(amp|lt|gt|quot|apos|#[0-9]+|#x[0-9a-fA-F]+);)",
    options: []
)
```

Add a private sanitize method:

```swift
private func sanitize(_ data: Data) -> Data {
    guard var s = String(data: data, encoding: .utf8) else { return data }
    let range = NSRange(s.startIndex..., in: s)
    s = Self.unescapedAmpersand.stringByReplacingMatches(
        in: s, range: range, withTemplate: "&amp;"
    )
    return Data(s.utf8)
}
```

Update `extractFeedURLs(from data:)` to sanitize before parsing and emit line/column on failure:

```swift
func extractFeedURLs(from data: Data) throws -> [URL] {
    feedURLs.removeAll()
    seen.removeAll()

    let sanitized = sanitize(data)
    let parser = XMLParser(data: sanitized)
    parser.delegate = self
    if !parser.parse() {
        throw OPMLImportError.malformed(
            line: parser.lineNumber,
            column: parser.columnNumber
        )
    }
    return feedURLs
}
```

(Adjust based on actual existing structure — replace whatever the current parse-and-throw shape is.)

- [ ] **Step 9.6: Run tests — expect both new cases PASS**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VibecastTests/OPMLImporterTests 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -5`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 9.7: Commit**

```bash
git add Vibecast/Vibecast/Discovery/OPMLImporter.swift \
        Vibecast/VibecastTests/OPMLImporterTests.swift \
        Vibecast/VibecastTests/Fixtures/opml-unescaped-ampersand.opml \
        Vibecast/VibecastTests/Fixtures/opml-unrecoverable.opml \
        Vibecast/Vibecast.xcodeproj/project.pbxproj
git commit -m "feat: sanitize unescaped ampersands in OPML; surface line/column on parse failure

Apple Podcasts / Overcast OPML exports occasionally include literal '&'
in podcast titles without XML-escaping it ('Griffin & David'). XMLParser
rejects the entire file. Pre-sanitize unescaped ampersands via regex,
covering the realistic 90% of malformed-OPML cases. For genuinely-broken
input, throw OPMLImportError.malformed(line:column:) with positions from
XMLParser so users can fix the source file."
```

---

## Task 10: Accessibility labels + 44pt tap targets on `SearchResultRow` and `PodcastRowView`

**Why this task:** Implements #43. VoiceOver users get unhelpful labels on the subscribe button (just "button") and the play button (just "button"). The subscribe button has 4 states — idle / in-flight / subscribed / failed — each needs a distinct label. Verify ≥44×44pt tap targets while we're auditing.

**Files:**
- Modify: `Vibecast/Vibecast/Views/SearchResultRow.swift`
- Modify: `Vibecast/Vibecast/Views/PodcastRowView.swift` (or `PlayControlView.swift` if play button lives there)

- [ ] **Step 10.1: Read both files to confirm existing button structure**

Read:
- `Vibecast/Vibecast/Views/SearchResultRow.swift`
- `Vibecast/Vibecast/Views/PlayControlView.swift` (the play button is here per the codebase grep)

Identify the four `SearchResultRow` button states and the play button structure.

- [ ] **Step 10.2: Add accessibility to `SearchResultRow` subscribe button**

Open `Vibecast/Vibecast/Views/SearchResultRow.swift`. Find the subscribe button. Add:

```swift
.accessibilityLabel(accessibilityLabel)
.accessibilityHint(accessibilityHint)
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())
```

And add private computed properties on the View struct:

```swift
private var accessibilityLabel: String {
    if isSubscribed   { return "Already subscribed to \(result.title)" }
    if isInFlight     { return "Subscribing to \(result.title)" }
    if recentlyFailed { return "Couldn't subscribe to \(result.title), try again" }
    return "Subscribe to \(result.title)"
}

private var accessibilityHint: String {
    if isSubscribed   { return "Already in your library" }
    if isInFlight     { return "Working on it" }
    if recentlyFailed { return "Tap to try again" }
    return "Adds this podcast to your library"
}
```

(Match the actual property names on `SearchResultRow` — the existing flags may be named differently; adjust the conditions to match.)

- [ ] **Step 10.3: Add accessibility to `PlayControlView` play button**

Open `Vibecast/Vibecast/Views/PlayControlView.swift`. Find the button. Add:

```swift
.accessibilityLabel(playButtonAccessibilityLabel)
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())
```

```swift
private var playButtonAccessibilityLabel: String {
    if isCurrent && isPlaying  { return "Pause \(episode.title)" }
    if isCurrent && !isPlaying { return "Resume \(episode.title)" }
    if episode.listenedStatus == .played { return "Replay \(episode.title)" }
    return "Play \(episode.title)"
}
```

- [ ] **Step 10.4: Build and run tests — expect green (no behavioral changes)**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|error:" | tail -5`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 10.5: Commit**

```bash
git add Vibecast/Vibecast/Views/SearchResultRow.swift \
        Vibecast/Vibecast/Views/PlayControlView.swift
git commit -m "feat: add accessibility labels and 44pt tap targets to row buttons

SearchResultRow's subscribe button has four states (idle / in-flight /
subscribed / failed); each gets a distinct VoiceOver label. PlayControlView's
play button label reflects current/playing/replay state. Both ensure ≥44pt
hit-test area via .frame(minWidth: 44, minHeight: 44) + .contentShape."
```

---

## Task 11: End-to-end manual verification

**Why this task:** Several items in this plan can only be verified manually — particularly background audio (sim ≠ device), the lock-screen UI, hardware volume buttons, AirPlay route picker, and VoiceOver. This task is gated by the user's hands-on confirmation; the agent cannot drive the simulator interactively.

**No code changes.** This task hands back to the user with the verification script below. The user reports each step as pass/partial/fail.

- [ ] **Step 11.1: Build a fresh debug install on the simulator**

Run:
```bash
xcodebuild -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/vibecast-plan5-final build
xcrun simctl install booted /tmp/vibecast-plan5-final/Build/Products/Debug-iphonesimulator/Vibecast.app
```

- [ ] **Step 11.2: User verification script (12 checkpoints)**

Run through each. Report back per step.

1. **#66 — middle-row delete no longer crashes.** Subscribe to 4 podcasts. Swipe-delete the middle one (index 1 or 2). Repeat with another middle one. App should not crash.
2. **#66 — top-row and bottom-row delete still work.** Delete top row, delete bottom row. No crash, list updates correctly.
3. **#28 — duration shows 0m left after a fully-played episode.** Play a short episode to completion (30s test fixture or a real short ad). Confirm "0m left" shown — not "1m left" or "−1m left".
4. **#65 — full-screen player shows MPVolumeView.** Open a playing episode in full-screen. Confirm a system volume slider is rendered (note: simulator may render blank — verify on device if possible). AirPlay route-picker button visible to the right of the slider.
5. **#65 — hardware volume buttons control system volume only.** No app-private slider remains.
6. **#64 — background audio continues when screen locks.** Play episode → press Home (or Cmd+Shift+H twice in simulator) → confirm audio keeps playing.
7. **#64 — lock-screen Now Playing panel shows artwork, title, podcast.** With audio playing, swipe down for the lock screen. Confirm Now Playing card shows: episode title, podcast title, podcast artwork, scrubber.
8. **#64 — lock-screen play/pause/skip work.** From the Now Playing card, pause → confirm app pauses; play → confirm app resumes; skip-forward → +30s; skip-back → −15s; scrubber drag → seeks.
9. **#64 — phone-call interruption pauses then resumes.** Trigger a simulator interruption (Hardware → Trigger Audio Session Interruption — if the simulator supports it; otherwise verify on device). Audio pauses on call begin and resumes on call end.
10. **#64 — headphone unplug pauses.** Plug headphones (or AirPods) → play → unplug → audio pauses. Simulator-only test: route change via Hardware menu if available.
11. **#42 — server error surfaces clearly.** (Optional, requires offline / hosts-file trick.) Force a 500 on iTunes search; confirm AddPodcastSheet shows an error message rather than silent "no results."
12. **#60 — http feed import succeeds via https.** Re-import the OPML file with the 8 plain-http feeds (delete any prior subscriptions to those podcasts first). All 8 should now subscribe (assuming https mirrors are still up).
13. **#43 — VoiceOver labels.** Enable VoiceOver in simulator settings. Navigate to AddPodcastSheet → search → focus subscribe button. Confirm the announcement is one of the four state-specific labels, not "button."
14. **#59 — original Griffin & David OPML imports cleanly.** Re-import the user's `apple-podcasts-export.opml` (the one we sanitized in-place during Plan 4). Should succeed with no parse error.

- [ ] **Step 11.3: Push branch after all checkpoints pass**

When the user confirms all 12 checkpoints pass:

```bash
git push -u origin feature/plan-5-followups
```

This requires user permission per `.claude/settings.local.json`.

---

## Summary

11 tasks. Test count progression:
- Baseline: 73
- After Task 1 (@Query): −5 (delete VM tests) +2 (regression) = **70**
- After Task 2 (#28 duration): +2 = **72**
- After Task 3 (#65 volume): drops volume test cases (count varies; expect ~−2) = **~70**
- After Task 4 (AVAudioSession): +0 (no unit tests for system observers) = **~70**
- After Task 5 (UIBackgroundModes capability): +0 = **~70**
- After Task 6 (NowPlayingService): +3 = **~73**
- After Task 7 (#42 status validation): +2 = **~75**
- After Task 8 (#60 https upgrade): +5 = **~80**
- After Task 9 (#59 OPML): +2 = **~82**
- After Task 10 (#43 a11y): +0 (manual-verified) = **~82**
- After Task 11 (manual): +0 = **~82**

Final approximate test count: **~82 tests**, plus a manually-verified background-audio + lock-screen integration on device.
