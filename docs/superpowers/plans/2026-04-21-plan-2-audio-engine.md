# Vibecast MVP — Plan 2: Audio Engine & Player UI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make podcast episodes actually play — an AVFoundation-backed audio engine, a persistent mini-player bar above the subscriptions list, and a full-screen player sheet, with playback state (position + status) surviving app relaunches.

**Architecture:** A thin `AudioEngine` protocol hides AVPlayer behind a testable interface. `PlayerManager` (an `@Observable` `@MainActor` service) owns playback state, bridges engine callbacks to SwiftUI, and writes playback position and listen-status transitions back through the shared `ModelContext`. The `SampleData` in-memory container is replaced by a disk-backed `ModelContainer` seeded once on first launch, so playback progress persists.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, AVFoundation, XCTest, iOS 17+

---

## Scope

This is **Plan 2 of 3**.

- **Plan 1 (done)** — Foundation & core UI: SwiftData models, sample data, rows, subscriptions list with swipe/reorder gestures, podcast detail sheet.
- **Plan 3 (next)** — Podcast discovery: iTunes Search API, Add Podcast sheet, OPML import. Plan 3 will also replace the hard-coded sample data (distinct artwork, distinct titles per podcast) with real feed content.

**Deferred on purpose:**
- **Long-press drag reorder** — the subscriptions list currently uses an `EditButton` toggle (Mail / Reminders pattern) that co-exists cleanly with swipe actions. Good enough for MVP; no change in this plan.
- **Sample data polish (distinct artwork / distinct titles per podcast)** — obsolete once Plan 3 replaces sample data with iTunes Search results.
- **Playback speed, sleep timer, background-downloads, AirPlay, lock-screen/now-playing info, remote-control events** — explicitly out of scope for the MVP spec.
- **System-volume routing via `MPVolumeView`** — the spec calls for a volume slider; we bind it to the `AVPlayer` instance's own volume. System volume stays independent. Cheap and correct for Plan 2.

After this plan, tapping any row's play control or the equivalent control in the detail sheet starts real audio playback, the mini-player bar becomes visible and stays visible, tapping it opens the full-screen player, scrubbing/skip/play-pause all work, and the episode's listen status transitions correctly (`.unplayed` → `.inProgress` → `.played`) and is saved to disk.

---

## File Map

```
Vibecast/
├── VibecastApp.swift                     — MODIFY: disk-backed ModelContainer; instantiate PlayerManager
├── Audio/
│   ├── AudioEngine.swift                 — NEW: AudioEngine protocol + AVPlayerAudioEngine (AVPlayer wrapper)
│   └── PlayerManager.swift               — NEW: @Observable playback state + bookkeeping
├── Views/
│   ├── MiniPlayerBar.swift               — NEW: persistent bottom bar
│   ├── FullScreenPlayerView.swift        — NEW: expanded player sheet
│   ├── SubscriptionsListView.swift       — MODIFY: overlay MiniPlayerBar, present FullScreenPlayer, wire onPlay
│   └── PodcastDetailView.swift           — MODIFY: wire onPlay to PlayerManager
└── Preview Content/
    └── SampleData.swift                  — MODIFY: one episode seeded with real test audio URL

VibecastTests/
└── PlayerManagerTests.swift              — NEW: MockAudioEngine + bookkeeping tests
```

**Design notes that drive this file map:**
- `AudioEngine` is a narrow protocol so `PlayerManager` can be unit-tested without a real `AVPlayer` — the production `AVPlayerAudioEngine` lives next to it in the same file only if both stay small; if either grows past ~120 lines, split them. Plan says one file; this note lets the implementer split if appropriate. (The name avoids collision with AVFoundation's existing `AVAudioEngine` class, which is an audio graph manager — a different API entirely.)
- `PlayerManager` is the only type that touches both the `ModelContext` and the engine. Views depend on `PlayerManager` through the SwiftUI environment; they never see the engine directly.
- Mini-player and full-screen player are separate files because they can be developed and previewed independently.

---

## Task 1: Persistent ModelContainer + Sample-Data Seed-Once

**Files:**
- Modify: `Vibecast/Vibecast/VibecastApp.swift`
- Modify: `Vibecast/Vibecast/Preview Content/SampleData.swift`

Replace the in-memory `SampleData.container` used by the app with a disk-backed `ModelContainer`. Seed sample data exactly once (guarded by a `UserDefaults` flag) so removing or reordering podcasts persists across launches. Seed one episode with a real working test audio URL so the audio engine can be verified end-to-end in the simulator.

- [ ] **Step 1: Add seed-once helper to `SampleData.swift`**

Open `Vibecast/Vibecast/Preview Content/SampleData.swift`. Add a new static function at the end of the `SampleData` struct, immediately before the closing brace, and add a test-audio URL constant. Leave the existing `static let container` (used by previews) untouched.

Add these members inside `struct SampleData`:

```swift
    /// Publicly hosted short MP3 used to verify audio playback in the simulator.
    /// Replace with any reachable audio URL if this stops resolving.
    static let testAudioURL = "https://download.samplelib.com/mp3/sample-15s.mp3"

    private static let seededDefaultsKey = "didSeedSampleData"

    /// Call once at app launch. Seeds sample data only if the UserDefaults flag
    /// is unset, so user-deleted or reordered podcasts survive relaunches.
    static func seedIfNeeded(into context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededDefaultsKey) else { return }
        insertSampleData(into: context)
        defaults.set(true, forKey: seededDefaultsKey)
    }
```

- [ ] **Step 2: Wire the real test audio URL into the first podcast's newest episode**

In the same file, inside the `for i in 0..<12 { ... }` loop of `insertSampleData(into:)`, replace:

```swift
                let ep = Episode(
                    podcast: podcast,
                    title: sampleTitle(index: i),
                    publishDate: Date().addingTimeInterval(-daysAgo * 86400),
                    descriptionText: sampleDescription(index: i),
                    durationSeconds: duration,
                    audioURL: ""
                )
```

with:

```swift
                let audioURL = (position == 0 && i == 0) ? testAudioURL : ""
                let ep = Episode(
                    podcast: podcast,
                    title: sampleTitle(index: i),
                    publishDate: Date().addingTimeInterval(-daysAgo * 86400),
                    descriptionText: sampleDescription(index: i),
                    durationSeconds: (position == 0 && i == 0) ? 15 : duration,
                    audioURL: audioURL
                )
```

This gives position-0 podcast's newest episode a real 15-second MP3 so the episode-end → `.played` transition can be observed in ~15 seconds of simulator time.

- [ ] **Step 3: Switch `VibecastApp` to a disk-backed container and seed once**

Replace the entire body of `Vibecast/Vibecast/VibecastApp.swift` with:

```swift
import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    private let container: ModelContainer

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Podcast.self, Episode.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        container = c
        MainActor.assumeIsolated {
            SampleData.seedIfNeeded(into: ModelContext(c))
        }
    }

    var body: some Scene {
        WindowGroup {
            SubscriptionsListView()
        }
        .modelContainer(container)
    }
}
```

`MainActor.assumeIsolated` is safe here because `App.init()` runs on the main actor when the SwiftUI runtime bootstraps; the closure contents touch `@MainActor`-isolated types (`SampleData`, `ModelContext`).

- [ ] **Step 4: Build and run on the simulator**

Cmd+R (iPhone 17 Pro simulator, or use the xcodebuild command below to drive it headlessly first):

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds. Launch the app in the simulator.

Expected on first launch: the five sample podcasts appear, including the in-progress and played states on rows 2 and 3.

Expected on second launch (after deleting a podcast and relaunching): the deleted podcast is *still* gone. (This is the persistence check.)

- [ ] **Step 5: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: all 10 Plan 1 tests still pass. `ModelTests` and `SubscriptionsViewModelTests` use their own in-memory container and are unaffected by the app-level switch.

- [ ] **Step 6: Commit**

```bash
git add Vibecast/Vibecast/VibecastApp.swift "Vibecast/Vibecast/Preview Content/SampleData.swift"
git commit -m "feat: persist ModelContainer to disk and seed sample data once"
```

---

## Task 2: AudioEngine Protocol + AVPlayerAudioEngine

**Files:**
- Create: `Vibecast/Vibecast/Audio/AudioEngine.swift`

Defines the abstraction `PlayerManager` depends on and ships the production implementation built on `AVPlayer`. Isolated so that `PlayerManager` can be tested with a `MockAudioEngine` (Task 3).

`AudioEngine` exposes: current time, duration, volume, transport (`play`, `pause`, `seek`, `load(url:startAt:)`), and two callbacks (`onTimeUpdate`, `onPlaybackEnd`).

- [ ] **Step 1: Create the `Audio` folder in Xcode**

In Xcode's file navigator, right-click the `Vibecast` group (inside the `Vibecast` project) → New Group. Name it `Audio`. This creates a synced folder on disk at `Vibecast/Vibecast/Audio/`.

- [ ] **Step 2: Create `AudioEngine.swift`**

Create file at `Vibecast/Vibecast/Audio/AudioEngine.swift`:

```swift
import Foundation
import AVFoundation

@MainActor
protocol AudioEngine: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var volume: Float { get set }

    /// Invoked on the main actor at most a few times per second while playing.
    var onTimeUpdate: ((TimeInterval) -> Void)? { get set }

    /// Invoked on the main actor when the loaded item reaches its end.
    var onPlaybackEnd: (() -> Void)? { get set }

    func load(url: URL, startAt: TimeInterval)
    func play()
    func pause()
    func seek(to: TimeInterval)
}

@MainActor
final class AVPlayerAudioEngine: AudioEngine {
    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?

    var isPlaying: Bool { player.timeControlStatus == .playing }

    var currentTime: TimeInterval {
        let t = player.currentTime()
        return t.isValid && !t.isIndefinite ? CMTimeGetSeconds(t) : 0
    }

    var duration: TimeInterval {
        guard let item = player.currentItem else { return 0 }
        let d = item.duration
        return d.isValid && !d.isIndefinite ? CMTimeGetSeconds(d) : 0
    }

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnd: (() -> Void)?

    init() {
        configureAudioSession()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func load(url: URL, startAt: TimeInterval) {
        // Tear down observers from any previous item.
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        if startAt > 0 {
            let t = CMTime(seconds: startAt, preferredTimescale: 600)
            player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        // Periodic time observer: ~4 callbacks per second.
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite {
                // Closure runs on main queue, hop to MainActor explicitly.
                Task { @MainActor in
                    self.onTimeUpdate?(seconds)
                }
            }
        }

        // End-of-item notification.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onPlaybackEnd?()
            }
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: TimeInterval) {
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Playback will still work for the simulator/foreground; log and continue.
            print("AVAudioSession config failed: \(error)")
        }
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: build succeeds. If Xcode shows stale SourceKit errors in the canvas, ignore them — `xcodebuild` is authoritative.

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Audio/AudioEngine.swift
git commit -m "feat: add AudioEngine protocol and AVPlayer-backed implementation"
```

---

## Task 3: PlayerManager (State + Bookkeeping) with Tests

**Files:**
- Create: `Vibecast/Vibecast/Audio/PlayerManager.swift`
- Create: `Vibecast/VibecastTests/PlayerManagerTests.swift`

`PlayerManager` is the single source of truth for current playback state. It:
- owns the `AudioEngine` and a `ModelContext`
- exposes `currentEpisode`, `isPlaying`, `elapsed`, `duration`, `volume`
- handles `play(_:)`, `togglePlayPause()`, `skipForward(_:)`, `skipBack(_:)`, `seek(to:)`, `setVolume(_:)`
- writes `Episode.playbackPosition` and `Episode.listenedStatus` at well-defined moments: when the unplayed threshold is crossed, when playback ends, when the user pauses/seeks, and at ~5-second throttle intervals during continuous playback
- is tested via a `MockAudioEngine` that lets tests synthesise time updates and end-of-playback events

- [ ] **Step 1: Write failing tests**

Create `Vibecast/VibecastTests/PlayerManagerTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class PlayerManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var engine: MockAudioEngine!
    var manager: PlayerManager!
    var podcast: Podcast!
    var episode: Episode!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Podcast.self, Episode.self, configurations: config)
        context = ModelContext(container)

        podcast = Podcast(title: "T", author: "A", artworkURL: nil, feedURL: "https://example.com/f")
        episode = Episode(
            podcast: podcast,
            title: "Ep",
            publishDate: .now,
            descriptionText: "",
            durationSeconds: 100,
            audioURL: "https://example.com/a.mp3"
        )
        context.insert(podcast)
        context.insert(episode)
        podcast.episodes.append(episode)
        try context.save()

        engine = MockAudioEngine()
        manager = PlayerManager(engine: engine, modelContext: context)
    }

    func test_play_setsCurrentEpisodeAndStartsEngine() {
        manager.play(episode)
        XCTAssertEqual(manager.currentEpisode?.persistentModelID, episode.persistentModelID)
        XCTAssertTrue(manager.isPlaying)
        XCTAssertTrue(engine.playCalled)
        XCTAssertEqual(engine.loadedURL?.absoluteString, "https://example.com/a.mp3")
    }

    func test_play_resumesFromSavedPosition() {
        episode.playbackPosition = 42
        manager.play(episode)
        XCTAssertEqual(engine.loadedStart, 42, accuracy: 0.001)
    }

    func test_play_withEmptyURL_setsStateWithoutStartingEngine() {
        episode.audioURL = ""
        manager.play(episode)
        XCTAssertEqual(manager.currentEpisode?.persistentModelID, episode.persistentModelID)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertFalse(engine.playCalled)
    }

    func test_timeUpdate_flipsUnplayedToInProgress() {
        XCTAssertEqual(episode.listenedStatus, .unplayed)
        manager.play(episode)
        engine.simulateTimeUpdate(1.0)
        XCTAssertEqual(episode.listenedStatus, .inProgress)
        XCTAssertEqual(episode.playbackPosition, 1.0, accuracy: 0.001)
    }

    func test_playbackEnd_flipsStatusToPlayed_andPersistsFullDuration() {
        manager.play(episode)
        engine.simulatePlaybackEnd()
        XCTAssertEqual(episode.listenedStatus, .played)
        XCTAssertEqual(episode.playbackPosition, Double(episode.durationSeconds), accuracy: 0.001)
        XCTAssertFalse(manager.isPlaying)
    }

    func test_togglePlayPause_pausesAndPersists() {
        manager.play(episode)
        engine.simulateTimeUpdate(10)
        manager.togglePlayPause()
        XCTAssertTrue(engine.pauseCalled)
        XCTAssertFalse(manager.isPlaying)
        XCTAssertEqual(episode.playbackPosition, 10, accuracy: 0.001)
    }

    func test_togglePlayPause_resumes() {
        manager.play(episode)
        manager.togglePlayPause() // pause
        engine.playCalled = false
        manager.togglePlayPause() // resume
        XCTAssertTrue(manager.isPlaying)
        XCTAssertTrue(engine.playCalled)
    }

    func test_skipForward_advancesByThirty() {
        manager.play(episode)
        engine.simulateTimeUpdate(10)
        manager.skipForward()
        XCTAssertEqual(engine.seekedTo ?? -1, 40, accuracy: 0.001)
    }

    func test_skipBack_rewindsByFifteen_clampedAtZero() {
        manager.play(episode)
        engine.simulateTimeUpdate(10)
        manager.skipBack()
        XCTAssertEqual(engine.seekedTo ?? -1, 0, accuracy: 0.001)
    }

    func test_seek_updatesElapsedAndPersists() {
        manager.play(episode)
        manager.seek(to: 55)
        XCTAssertEqual(engine.seekedTo ?? -1, 55, accuracy: 0.001)
        XCTAssertEqual(manager.elapsed, 55, accuracy: 0.001)
        XCTAssertEqual(episode.playbackPosition, 55, accuracy: 0.001)
    }

    func test_throttledSave_persistsEveryFiveSeconds() throws {
        manager.play(episode)
        engine.simulateTimeUpdate(1) // flips to inProgress, saves
        episode.playbackPosition = 0 // reset to verify subsequent saves
        engine.simulateTimeUpdate(2) // below 5s delta — no save
        XCTAssertEqual(episode.playbackPosition, 0, accuracy: 0.001)
        engine.simulateTimeUpdate(7) // above 5s delta since last save — saves
        XCTAssertEqual(episode.playbackPosition, 7, accuracy: 0.001)
    }
}

// MARK: - Test Double

@MainActor
final class MockAudioEngine: AudioEngine {
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 1.0

    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnd: (() -> Void)?

    // Captured for assertions
    var loadedURL: URL?
    var loadedStart: TimeInterval = 0
    var playCalled = false
    var pauseCalled = false
    var seekedTo: TimeInterval?

    func load(url: URL, startAt: TimeInterval) {
        loadedURL = url
        loadedStart = startAt
        currentTime = startAt
    }

    func play() {
        playCalled = true
        isPlaying = true
    }

    func pause() {
        pauseCalled = true
        isPlaying = false
    }

    func seek(to seconds: TimeInterval) {
        seekedTo = seconds
        currentTime = seconds
    }

    // Test helpers
    func simulateTimeUpdate(_ t: TimeInterval) {
        currentTime = t
        onTimeUpdate?(t)
    }

    func simulatePlaybackEnd() {
        onPlaybackEnd?()
    }
}
```

- [ ] **Step 2: Run — verify failure**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: compile errors — `PlayerManager` not defined.

- [ ] **Step 3: Create `PlayerManager.swift`**

Create `Vibecast/Vibecast/Audio/PlayerManager.swift`:

```swift
import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class PlayerManager {
    private(set) var currentEpisode: Episode?
    private(set) var isPlaying: Bool = false
    private(set) var elapsed: TimeInterval = 0

    /// Preferred duration: the engine's if loaded, otherwise the episode's stored duration.
    var duration: TimeInterval {
        let engineDuration = engine.duration
        if engineDuration > 0 { return engineDuration }
        if let seconds = currentEpisode?.durationSeconds { return TimeInterval(seconds) }
        return 0
    }

    var volume: Float {
        get { engine.volume }
        set { engine.volume = newValue }
    }

    @ObservationIgnored private let engine: AudioEngine
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private var lastPersistedAt: TimeInterval = 0
    @ObservationIgnored private static let saveIntervalSeconds: TimeInterval = 5

    init(engine: AudioEngine, modelContext: ModelContext) {
        self.engine = engine
        self.modelContext = modelContext

        engine.onTimeUpdate = { [weak self] t in
            self?.handleTimeUpdate(t)
        }
        engine.onPlaybackEnd = { [weak self] in
            self?.handlePlaybackEnd()
        }
    }

    // MARK: - Transport

    func play(_ episode: Episode) {
        // Persist position of the previous episode before switching.
        persistCurrentPosition()

        currentEpisode = episode
        elapsed = episode.playbackPosition
        lastPersistedAt = episode.playbackPosition

        guard let url = URL(string: episode.audioURL), !episode.audioURL.isEmpty else {
            // No URL — keep state, do not start the engine.
            isPlaying = false
            return
        }

        engine.load(url: url, startAt: episode.playbackPosition)
        engine.play()
        isPlaying = true
    }

    func togglePlayPause() {
        guard currentEpisode != nil else { return }
        if isPlaying {
            engine.pause()
            isPlaying = false
            persistCurrentPosition()
        } else {
            engine.play()
            isPlaying = true
        }
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: elapsed + seconds)
    }

    func skipBack(_ seconds: TimeInterval = 15) {
        seek(to: max(0, elapsed - seconds))
    }

    func seek(to seconds: TimeInterval) {
        let clamped = max(0, seconds)
        engine.seek(to: clamped)
        elapsed = clamped
        persistCurrentPosition()
    }

    // MARK: - Engine callbacks

    private func handleTimeUpdate(_ t: TimeInterval) {
        elapsed = t
        guard let episode = currentEpisode else { return }

        // First-touch transition: unplayed → inProgress.
        if episode.listenedStatus == .unplayed, t > 0 {
            episode.listenedStatus = .inProgress
            episode.playbackPosition = t
            try? modelContext.save()
            lastPersistedAt = t
            return
        }

        // Throttled periodic save.
        if t - lastPersistedAt >= Self.saveIntervalSeconds {
            episode.playbackPosition = t
            try? modelContext.save()
            lastPersistedAt = t
        }
    }

    private func handlePlaybackEnd() {
        guard let episode = currentEpisode else { return }
        episode.listenedStatus = .played
        episode.playbackPosition = Double(episode.durationSeconds)
        elapsed = Double(episode.durationSeconds)
        isPlaying = false
        try? modelContext.save()
        lastPersistedAt = elapsed
    }

    // MARK: - Persistence helper

    private func persistCurrentPosition() {
        guard let episode = currentEpisode else { return }
        episode.playbackPosition = elapsed
        if episode.listenedStatus == .unplayed && elapsed > 0 {
            episode.listenedStatus = .inProgress
        }
        try? modelContext.save()
        lastPersistedAt = elapsed
    }
}
```

- [ ] **Step 4: Run tests — verify all 11 pass**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 21 tests pass overall (10 from Plan 1 + 11 new). 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Audio/PlayerManager.swift Vibecast/VibecastTests/PlayerManagerTests.swift
git commit -m "feat: add PlayerManager with bookkeeping and mock-engine tests"
```

---

## Task 4: Wire PlayerManager into the App

**Files:**
- Modify: `Vibecast/Vibecast/VibecastApp.swift`
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`
- Modify: `Vibecast/Vibecast/Views/PodcastDetailView.swift`

Create the single `PlayerManager` instance at the app level, inject it through the SwiftUI environment, and hook the existing `onPlay` closures on each row to actually start playback. Detail views that host `EpisodeRowView` also get wired.

- [ ] **Step 1: Add a global `PlayerManager` environment key**

Append to the end of `Vibecast/Vibecast/Audio/PlayerManager.swift`:

```swift
import SwiftUI

private struct PlayerManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: PlayerManager? = nil
}

extension EnvironmentValues {
    var playerManager: PlayerManager? {
        get { self[PlayerManagerKey.self] }
        set { self[PlayerManagerKey.self] = newValue }
    }
}
```

A nullable default keeps previews (which have no `PlayerManager`) compiling; real app code force-unwraps inside `onPlay`.

- [ ] **Step 2: Instantiate `PlayerManager` in `VibecastApp` and inject it**

Replace the entire body of `Vibecast/Vibecast/VibecastApp.swift` with:

```swift
import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    private let container: ModelContainer
    @State private var playerManager: PlayerManager

    init() {
        let c: ModelContainer
        do {
            c = try ModelContainer(for: Podcast.self, Episode.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        container = c

        let manager: PlayerManager = MainActor.assumeIsolated {
            SampleData.seedIfNeeded(into: ModelContext(c))
            return PlayerManager(engine: AVPlayerAudioEngine(), modelContext: ModelContext(c))
        }
        _playerManager = State(initialValue: manager)
    }

    var body: some Scene {
        WindowGroup {
            SubscriptionsListView()
                .environment(\.playerManager, playerManager)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 3: Wire `onPlay` in `SubscriptionsListView`**

Open `Vibecast/Vibecast/Views/SubscriptionsListView.swift`. Replace the `PodcastRowView(...)` call inside `listContent(viewModel:)` — currently:

```swift
                PodcastRowView(
                    podcast: podcast,
                    onPlay: { },
                    onOpenDetail: { selectedPodcast = podcast }
                )
```

with:

```swift
                PodcastRowView(
                    podcast: podcast,
                    onPlay: {
                        if let ep = podcast.episodes
                            .sorted(by: { $0.publishDate > $1.publishDate }).first {
                            playerManager?.play(ep)
                        }
                    },
                    onOpenDetail: { selectedPodcast = podcast }
                )
```

Then add the environment property near the other `@State` / `@Environment` declarations at the top of the struct:

```swift
    @Environment(\.playerManager) private var playerManager
```

- [ ] **Step 4: Wire `onPlay` in `PodcastDetailView`**

Open `Vibecast/Vibecast/Views/PodcastDetailView.swift`. Add at the top of the struct (near the existing `@State private var viewModel`):

```swift
    @Environment(\.playerManager) private var playerManager
```

Replace the `EpisodeRowView(episode: episode, onPlay: { /* Plan 2 */ })` line with:

```swift
                    EpisodeRowView(episode: episode, onPlay: { playerManager?.play(episode) })
```

- [ ] **Step 5: Build and run on the simulator**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

Launch in the simulator. Tap the play control on the first row (Hard Fork, newest episode — the one with the real audio URL). Nothing visible changes yet — the mini-player doesn't exist. But there should be no crash. To confirm playback started, relaunch the app: Hard Fork's newest episode should show `.inProgress` state (partial ring, bold title de-emphasised to regular weight).

- [ ] **Step 6: Run all tests**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 21 tests pass.

- [ ] **Step 7: Commit**

```bash
git add Vibecast/Vibecast/Audio/PlayerManager.swift Vibecast/Vibecast/VibecastApp.swift Vibecast/Vibecast/Views/SubscriptionsListView.swift Vibecast/Vibecast/Views/PodcastDetailView.swift
git commit -m "feat: inject PlayerManager via environment and hook onPlay"
```

---

## Task 5: MiniPlayerBar View

**Files:**
- Create: `Vibecast/Vibecast/Views/MiniPlayerBar.swift`

Standalone view with a preview so it can be iterated without running the whole app. Observes a passed-in `PlayerManager`. Displays nothing externally when `currentEpisode` is nil; parent views use `.safeAreaInset` conditionally.

Layout (spec): artwork 44×44 on the left; episode title above a thin progress bar (elapsed left, −remaining right); play/pause button; skip-forward-30s button on the right.

- [ ] **Step 1: Create `MiniPlayerBar.swift`**

Create `Vibecast/Vibecast/Views/MiniPlayerBar.swift`:

```swift
import SwiftUI
import SwiftData

struct MiniPlayerBar: View {
    let player: PlayerManager
    let onTapBar: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            artwork
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentEpisode?.title ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                progressRow
            }

            playPauseButton

            skipForwardButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapBar)
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.25))
            .overlay {
                if let urlString = player.currentEpisode?.podcast?.artworkURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private var progressRow: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 2)

            HStack {
                Text(format(player.elapsed))
                Spacer()
                Text("-" + format(max(0, player.duration - player.elapsed)))
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
    }

    private var playPauseButton: some View {
        Button {
            player.togglePlayPause()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22))
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
    }

    private var skipForwardButton: some View {
        Button {
            player.skipForward()
        } label: {
            Image(systemName: "goforward.30")
                .font(.system(size: 22))
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
    }

    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.elapsed / player.duration, 0), 1)
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    @Previewable @State var player: PlayerManager = {
        let container = SampleData.container
        let context = ModelContext(container)
        let episodes = try! context.fetch(FetchDescriptor<Episode>())
        let engine = PreviewAudioEngine()
        let mgr = PlayerManager(engine: engine, modelContext: context)
        if let ep = episodes.first {
            mgr.play(ep)
            engine.simulateTime(120)
        }
        return mgr
    }()

    return VStack {
        Spacer()
        MiniPlayerBar(player: player, onTapBar: {})
    }
}

/// Preview-only engine so the mini-player renders with a non-zero elapsed/duration.
@MainActor
private final class PreviewAudioEngine: AudioEngine {
    var isPlaying: Bool = true
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 1800
    var volume: Float = 1.0
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnd: (() -> Void)?
    func load(url: URL, startAt: TimeInterval) { currentTime = startAt }
    func play() { isPlaying = true }
    func pause() { isPlaying = false }
    func seek(to: TimeInterval) { currentTime = to }
    func simulateTime(_ t: TimeInterval) { currentTime = t; onTimeUpdate?(t) }
}
```

- [ ] **Step 2: Verify in Xcode canvas**

Open `MiniPlayerBar.swift` in Xcode, open the canvas (Cmd+Option+Return). Expected: a bar at the bottom showing artwork placeholder, episode title, thin progress bar at ~120/1800 filled, a pause icon, and a skip-forward-30 icon.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Views/MiniPlayerBar.swift
git commit -m "feat: add MiniPlayerBar view"
```

---

## Task 6: Overlay Mini-Player on Subscriptions List

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`

Attach the mini-player to the bottom safe area of the subscriptions list using `.safeAreaInset(edge: .bottom)` so list content never slides underneath it. The bar appears once the user has started playback at least once during the current app session (i.e., `PlayerManager.currentEpisode != nil`).

Per the spec, "persistent bar at the bottom of the subscriptions list whenever audio has been played." On a cold relaunch the `PlayerManager` is reset, so the bar will only reappear after another play — that behaviour is acceptable for MVP (the spec doesn't call for cross-launch player state, only episode state).

- [ ] **Step 1: Add a state hook for the full-screen player sheet and a `safeAreaInset` modifier**

Open `Vibecast/Vibecast/Views/SubscriptionsListView.swift`. Add a new `@State` near the other states:

```swift
    @State private var showFullScreenPlayer = false
```

Then apply `.safeAreaInset` to the `NavigationStack`. Replace the block that currently looks like:

```swift
        NavigationStack {
            Group {
                if let viewModel {
                    listContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Vibecast")
            .toolbar {
                // ...
            }
            .sheet(item: $selectedPodcast) { podcast in
                PodcastDetailView(podcast: podcast)
            }
        }
```

with:

```swift
        NavigationStack {
            Group {
                if let viewModel {
                    listContent(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Vibecast")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddPodcast = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.light))
                    }
                }
            }
            .sheet(item: $selectedPodcast) { podcast in
                PodcastDetailView(podcast: podcast)
            }
            .safeAreaInset(edge: .bottom) {
                if let playerManager, playerManager.currentEpisode != nil {
                    MiniPlayerBar(
                        player: playerManager,
                        onTapBar: { showFullScreenPlayer = true }
                    )
                }
            }
        }
```

(Only the `.safeAreaInset` block is new — the rest is unchanged.)

- [ ] **Step 2: Build and run**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Launch in the simulator. Expected:
- On launch, no mini-player visible.
- Tap play on Hard Fork's newest episode (real URL). Audio starts (wear headphones or unmute the simulator); mini-player bar appears at the bottom.
- Title matches the episode, progress bar advances, play/pause button toggles playback, skip-forward-30 jumps ahead by 30 seconds.
- List content is not occluded — the bottom-most row is pushed up by the bar.

- [ ] **Step 3: Commit**

```bash
git add Vibecast/Vibecast/Views/SubscriptionsListView.swift
git commit -m "feat: overlay mini-player on subscriptions list"
```

---

## Task 7: FullScreenPlayerView

**Files:**
- Create: `Vibecast/Vibecast/Views/FullScreenPlayerView.swift`

The expanded player sheet, opened by tapping the mini-player (Task 8 wires the sheet presentation). Layout per spec: drag handle pill, "Now Playing" label, large artwork with shadow, episode title + podcast name, scrubber with elapsed / −remaining, Jump-back-15 / Play-pause / Jump-forward-30, volume slider with speaker icons.

The scrubber uses a `Slider` bound to local `@State` for dragging, flushing via `PlayerManager.seek(to:)` on release.

- [ ] **Step 1: Create `FullScreenPlayerView.swift`**

Create `Vibecast/Vibecast/Views/FullScreenPlayerView.swift`:

```swift
import SwiftUI
import SwiftData

struct FullScreenPlayerView: View {
    let player: PlayerManager

    /// Non-nil while the user is dragging the scrubber.
    @State private var scrubValue: Double?
    @State private var volume: Float

    init(player: PlayerManager) {
        self.player = player
        _volume = State(initialValue: player.volume)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Now Playing")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Spacer(minLength: 24)

            artwork

            Spacer(minLength: 20)

            VStack(spacing: 4) {
                Text(player.currentEpisode?.title ?? "")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(player.currentEpisode?.podcast?.title ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)

            scrubber
                .padding(.horizontal, 32)

            Spacer(minLength: 20)

            transportControls

            Spacer(minLength: 28)

            volumeSlider
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 280, height: 280)
            .overlay {
                if let urlString = player.currentEpisode?.podcast?.artworkURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)
                }
            }
            .shadow(radius: 12, y: 6)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubValue ?? player.elapsed },
                    set: { scrubValue = $0 }
                ),
                in: 0...(max(player.duration, 1)),
                onEditingChanged: { isEditing in
                    if !isEditing, let v = scrubValue {
                        player.seek(to: v)
                        scrubValue = nil
                    }
                }
            )

            HStack {
                Text(format(scrubValue ?? player.elapsed))
                Spacer()
                Text("-" + format(max(0, player.duration - (scrubValue ?? player.elapsed))))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button {
                player.skipBack()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .buttonStyle(.plain)

            Button {
                player.skipForward()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)
        }
    }

    private var volumeSlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { Double(volume) },
                    set: {
                        volume = Float($0)
                        player.volume = volume
                    }
                ),
                in: 0...1
            )

            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    @Previewable @State var player: PlayerManager = {
        let container = SampleData.container
        let context = ModelContext(container)
        let episodes = try! context.fetch(FetchDescriptor<Episode>())
        let engine = PreviewAudioEngine()
        let mgr = PlayerManager(engine: engine, modelContext: context)
        if let ep = episodes.first {
            mgr.play(ep)
            engine.simulateTime(300)
        }
        return mgr
    }()

    return FullScreenPlayerView(player: player)
}

@MainActor
private final class PreviewAudioEngine: AudioEngine {
    var isPlaying: Bool = true
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 1800
    var volume: Float = 0.6
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnd: (() -> Void)?
    func load(url: URL, startAt: TimeInterval) { currentTime = startAt }
    func play() { isPlaying = true }
    func pause() { isPlaying = false }
    func seek(to: TimeInterval) { currentTime = to }
    func simulateTime(_ t: TimeInterval) { currentTime = t; onTimeUpdate?(t) }
}
```

- [ ] **Step 2: Verify in Xcode canvas**

Open `FullScreenPlayerView.swift` in Xcode, open the canvas. Expected: artwork placeholder, "Now Playing" label, title/author, scrubber at ~300/1800, jump-back-15 / pause / jump-forward-30 row, volume slider at ~0.6.

- [ ] **Step 3: Build**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: builds successfully.

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Views/FullScreenPlayerView.swift
git commit -m "feat: add FullScreenPlayerView with scrubber, transport, volume"
```

---

## Task 8: Open Full-Screen Player + End-to-End Verification

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`

Present `FullScreenPlayerView` as a sheet when the user taps the mini-player. Then run through the full playback flow in the simulator.

- [ ] **Step 1: Present `FullScreenPlayerView` from `SubscriptionsListView`**

Open `Vibecast/Vibecast/Views/SubscriptionsListView.swift`. The `showFullScreenPlayer` state was added in Task 6. Add a second `.sheet(isPresented:)` modifier just below the existing `.sheet(item:)` inside the `NavigationStack` block:

```swift
            .sheet(isPresented: $showFullScreenPlayer) {
                if let playerManager, playerManager.currentEpisode != nil {
                    FullScreenPlayerView(player: playerManager)
                }
            }
```

- [ ] **Step 2: Build and run**

```bash
xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- [ ] **Step 3: Manual simulator verification**

Launch the app (unmute the simulator or plug in headphones).

| Step | Action | Expected |
|---|---|---|
| 1 | Tap play on Hard Fork newest episode | Audio plays; mini-player appears at bottom |
| 2 | Verify bar | Episode title correct; progress bar advances; `0:0N / -0:NN` times update |
| 3 | Tap the mini-player pause button | Audio pauses; icon flips to play |
| 4 | Tap the mini-player play button | Audio resumes |
| 5 | Tap the mini-player skip-forward-30 button | Elapsed jumps ahead ~30s (but clamps at 15s-duration track — may jump straight to end) |
| 6 | Tap the mini-player bar body (not the buttons) | Full-screen player sheet slides up with drag indicator |
| 7 | Verify full-screen layout | Artwork, "Now Playing" label, title/author, scrubber, jump-back-15/play-pause/jump-forward-30 row, volume slider |
| 8 | Drag the scrubber | Elapsed label tracks the drag; on release, audio seeks to the new position |
| 9 | Drag the volume slider | Audio volume changes |
| 10 | Tap jump-back-15 | Elapsed goes back 15s (or clamps at 0) |
| 11 | Swipe the full-screen player down | Sheet dismisses; mini-player still visible underneath |
| 12 | Let the 15s track play out | Audio ends; episode row in the list shows played state (faded accent ring, checkmark) |
| 13 | Quit app and relaunch | Hard Fork's newest episode still shows played state (persistence check) |
| 14 | Tap play on a second row (no real URL) | No crash; mini-player updates to show that episode's title, but no audio plays |

If any step fails, stop and investigate before proceeding.

- [ ] **Step 4: Run all tests one more time**

```bash
xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Expected: 21 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Views/SubscriptionsListView.swift
git commit -m "feat: present FullScreenPlayerView from mini-player tap"
```

---

## Task 9: Push to Remote

- [ ] **Step 1: Confirm branch state**

```bash
git status
git log --oneline origin/main..HEAD
```

Expected: clean working tree; 8–9 new commits on the feature branch.

- [ ] **Step 2: Push**

```bash
git push -u origin feature/plan-2-audio-engine
```

- [ ] **Step 3: Verify on GitHub**

Confirm the branch is visible on GitHub and the new files (`Vibecast/Audio/AudioEngine.swift`, `Vibecast/Audio/PlayerManager.swift`, `Vibecast/Views/MiniPlayerBar.swift`, `Vibecast/Views/FullScreenPlayerView.swift`, `VibecastTests/PlayerManagerTests.swift`) are present.
