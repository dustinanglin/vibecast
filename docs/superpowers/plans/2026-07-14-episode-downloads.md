# Episode Downloads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offline episode playback — auto-download the newest episode per show on refresh, manual downloads from episode lists, keep-last-N retention, and a global download-settings sheet.

**Architecture:** Download state lives on the `Episode` model (3 new default-valued properties → SwiftData lightweight migration). A `DownloadManager` (`@Observable @MainActor`) owns a background-configured `URLSession`; files are stored in Application Support named by SHA256 of the audio URL (`DownloadStore`); pure selection/pruning logic is isolated in `DownloadPolicy` for testability; global settings are UserDefaults accessors (`DownloadSettings`). Playback prefers the local file when present.

**Tech Stack:** SwiftUI, SwiftData, URLSession (background configuration), CryptoKit, XCTest

**Spec:** `docs/superpowers/specs/2026-07-14-episode-downloads-design.md`

## Global Constraints

- All paths relative to the worktree root (repo root contains `Vibecast/Vibecast.xcodeproj`).
- Test command base: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17"`.
- Build command base: same with `build` instead of `test` and no `-only-testing`.
- Commit messages follow the repo convention: `feat(downloads): …`, `test(downloads): …`.
- SourceKit diagnostics on freshly written files ("Cannot find type X in scope") are false positives in this project — trust `xcodebuild` output only.
- The session identifier for the background URLSession is exactly `AnglinVibes.Vibecast.downloads`.
- UserDefaults keys are exactly: `downloadAutoEnabled`, `downloadKeepLastN`, `downloadDeleteWhenPlayed`, `downloadWifiOnly`.
- Defaults: auto-download **true**, keep-last-N **3** (0 = unlimited), delete-when-played **false**, wifi-only **true**.

---

## Task 1: `DownloadSettings` — UserDefaults accessors

**Files:**
- Create: `Vibecast/Vibecast/Downloads/DownloadSettings.swift`
- Test: `Vibecast/VibecastTests/DownloadSettingsTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `DownloadSettings.autoDownloadEnabled(defaults:) -> Bool`, `keepLastN(defaults:) -> Int`, `deleteWhenPlayed(defaults:) -> Bool`, `wifiOnly(defaults:) -> Bool`, and matching `set…` functions — all `static`, all defaulting `defaults:` to `.standard`. Later tasks call the zero-arg forms.

- [ ] **Step 1: Write the failing tests**

Create `Vibecast/VibecastTests/DownloadSettingsTests.swift`:

```swift
import XCTest
@testable import Vibecast

final class DownloadSettingsTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.downloads.\(UUID().uuidString)")!
    }

    func test_defaults_whenNothingStored() {
        let d = freshDefaults()
        XCTAssertTrue(DownloadSettings.autoDownloadEnabled(defaults: d))
        XCTAssertEqual(DownloadSettings.keepLastN(defaults: d), 3)
        XCTAssertFalse(DownloadSettings.deleteWhenPlayed(defaults: d))
        XCTAssertTrue(DownloadSettings.wifiOnly(defaults: d))
    }

    func test_roundTrips() {
        let d = freshDefaults()
        DownloadSettings.setAutoDownloadEnabled(false, defaults: d)
        DownloadSettings.setKeepLastN(10, defaults: d)
        DownloadSettings.setDeleteWhenPlayed(true, defaults: d)
        DownloadSettings.setWifiOnly(false, defaults: d)
        XCTAssertFalse(DownloadSettings.autoDownloadEnabled(defaults: d))
        XCTAssertEqual(DownloadSettings.keepLastN(defaults: d), 10)
        XCTAssertTrue(DownloadSettings.deleteWhenPlayed(defaults: d))
        XCTAssertFalse(DownloadSettings.wifiOnly(defaults: d))
    }

    func test_keepLastN_zeroMeansUnlimited_roundTrips() {
        let d = freshDefaults()
        DownloadSettings.setKeepLastN(0, defaults: d)
        XCTAssertEqual(DownloadSettings.keepLastN(defaults: d), 0)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:VibecastTests/DownloadSettingsTests 2>&1 | grep -E "(error:|BUILD FAILED)"`
Expected: `cannot find 'DownloadSettings' in scope` errors.

- [ ] **Step 3: Implement**

Create `Vibecast/Vibecast/Downloads/DownloadSettings.swift` (new `Downloads/` group directory — the project uses `PBXFileSystemSynchronizedRootGroup`, so a new folder on disk is picked up automatically):

```swift
import Foundation

/// Global download preferences. UserDefaults-backed static accessors with an
/// injectable defaults instance for tests — same pattern as
/// `VibecastApp.splashMode(defaults:)`.
///
/// `true`-defaulting Bools and the Int must use `object(forKey:) == nil` to
/// distinguish "never set" from "set to false/0".
enum DownloadSettings {
    static let autoEnabledKey = "downloadAutoEnabled"
    static let keepLastNKey = "downloadKeepLastN"
    static let deleteWhenPlayedKey = "downloadDeleteWhenPlayed"
    static let wifiOnlyKey = "downloadWifiOnly"

    static func autoDownloadEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: autoEnabledKey) as? Bool ?? true
    }

    /// How many auto-downloaded episodes to keep per show. 0 = unlimited.
    static func keepLastN(defaults: UserDefaults = .standard) -> Int {
        defaults.object(forKey: keepLastNKey) as? Int ?? 3
    }

    static func deleteWhenPlayed(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: deleteWhenPlayedKey)
    }

    static func wifiOnly(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: wifiOnlyKey) as? Bool ?? true
    }

    static func setAutoDownloadEnabled(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: autoEnabledKey)
    }

    static func setKeepLastN(_ value: Int, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: keepLastNKey)
    }

    static func setDeleteWhenPlayed(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: deleteWhenPlayedKey)
    }

    static func setWifiOnly(_ value: Bool, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: wifiOnlyKey)
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Same command as Step 2, expect all 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Downloads/DownloadSettings.swift Vibecast/VibecastTests/DownloadSettingsTests.swift
git commit -m "feat(downloads): DownloadSettings UserDefaults accessors with tests"
```

---

## Task 2: Episode model — `DownloadState` + persisted properties

**Files:**
- Modify: `Vibecast/Vibecast/Models/Episode.swift`
- Test: `Vibecast/VibecastTests/DownloadPolicyTests.swift` (created here; Task 4 extends it)

**Interfaces:**
- Consumes: nothing.
- Produces: `enum DownloadState: String, Codable, Sendable { case none, downloading, downloaded, failed }` (top-level, in Episode.swift); on `Episode`: `var downloadStateRaw: String`, `var isManualDownload: Bool`, `var downloadedAt: Date?`, computed `var downloadState: DownloadState { get set }`. `Episode.init` signature is UNCHANGED.

- [ ] **Step 1: Write the failing test**

Create `Vibecast/VibecastTests/DownloadPolicyTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Vibecast

@MainActor
final class DownloadPolicyTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Podcast.self, Episode.self, Vibe.self, VibeMembership.self, QueueState.self,
            configurations: config
        )
        return container.mainContext
    }

    private func makeEpisode(in context: ModelContext, podcast: Podcast, title: String, daysAgo: Int) -> Episode {
        let episode = Episode(
            podcast: podcast,
            title: title,
            publishDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
            descriptionText: "",
            durationSeconds: 1800,
            audioURL: "https://example.com/\(UUID().uuidString).mp3"
        )
        context.insert(episode)
        podcast.episodes.append(episode)
        return episode
    }

    private func makePodcast(in context: ModelContext, title: String) -> Podcast {
        let podcast = Podcast(title: title, author: "A", artworkURL: nil, feedURL: "https://example.com/\(title)", sortPosition: 0)
        context.insert(podcast)
        return podcast
    }

    // MARK: - DownloadState accessor

    func test_downloadState_defaultsToNone() throws {
        let context = try makeContext()
        let podcast = makePodcast(in: context, title: "Show")
        let episode = makeEpisode(in: context, podcast: podcast, title: "Ep", daysAgo: 0)
        XCTAssertEqual(episode.downloadState, DownloadState.none)
        XCTAssertFalse(episode.isManualDownload)
        XCTAssertNil(episode.downloadedAt)
    }

    func test_downloadState_roundTripsThroughRaw() throws {
        let context = try makeContext()
        let podcast = makePodcast(in: context, title: "Show")
        let episode = makeEpisode(in: context, podcast: podcast, title: "Ep", daysAgo: 0)
        episode.downloadState = .downloaded
        XCTAssertEqual(episode.downloadStateRaw, "downloaded")
        XCTAssertEqual(episode.downloadState, .downloaded)
    }

    func test_downloadState_garbageRawFallsBackToNone() throws {
        let context = try makeContext()
        let podcast = makePodcast(in: context, title: "Show")
        let episode = makeEpisode(in: context, podcast: podcast, title: "Ep", daysAgo: 0)
        episode.downloadStateRaw = "garbage"
        XCTAssertEqual(episode.downloadState, DownloadState.none)
    }
}
```

Note: check `Podcast.init` in `Vibecast/Vibecast/Models/Podcast.swift` before running — if its parameter list differs from the call above (`title:author:artworkURL:feedURL:sortPosition:`), adapt the `makePodcast` helper to the real signature. Do not change `Podcast` itself.

- [ ] **Step 2: Run — expect compile failure**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:VibecastTests/DownloadPolicyTests 2>&1 | grep -E "(error:|BUILD FAILED)"`
Expected: `cannot find 'DownloadState' in scope` / `no member 'downloadState'`.

- [ ] **Step 3: Implement**

In `Vibecast/Vibecast/Models/Episode.swift`, add above `@Model final class Episode` (below the `ListenedStatus` enum):

```swift
/// Offline-download lifecycle for an episode's audio file. Stored on
/// Episode as a raw string with a default so SwiftData lightweight
/// migration adds it to existing rows (same pattern as
/// `Podcast.episodeSortOrderRaw`).
enum DownloadState: String, Codable, Sendable {
    case none
    case downloading
    case downloaded
    case failed
}
```

Inside `Episode`, add after `var isExplicit: Bool`:

```swift
    var downloadStateRaw: String = DownloadState.none.rawValue
    var isManualDownload: Bool = false
    var downloadedAt: Date?
```

And add after the `init` (with the other computed vars):

```swift
    var downloadState: DownloadState {
        get { DownloadState(rawValue: downloadStateRaw) ?? .none }
        set { downloadStateRaw = newValue.rawValue }
    }
```

Do NOT touch `Episode.init` — the new stored properties take their declaration defaults.

- [ ] **Step 4: Run — expect pass, then run the FULL suite once** (migration sanity: existing tests must still pass with the schema addition).

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "(Test Case.*failed|error:|\*\* TEST)"`
Expected: `** TEST SUCCEEDED **`, zero failures.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Models/Episode.swift Vibecast/VibecastTests/DownloadPolicyTests.swift
git commit -m "feat(downloads): DownloadState enum + persisted download fields on Episode"
```

---

## Task 3: `DownloadStore` — file layout and disk ops

**Files:**
- Create: `Vibecast/Vibecast/Downloads/DownloadStore.swift`
- Test: `Vibecast/VibecastTests/DownloadStoreTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces (all `static` on `enum DownloadStore`): `directoryURL: URL`, `fileURL(for audioURL: String) -> URL`, `exists(for: String) -> Bool`, `store(tempFile: URL, for: String) throws -> URL`, `delete(for: String)`, `deleteAll()`, `totalBytes() -> Int64`.

- [ ] **Step 1: Write the failing tests**

Create `Vibecast/VibecastTests/DownloadStoreTests.swift`:

```swift
import XCTest
@testable import Vibecast

final class DownloadStoreTests: XCTestCase {

    override func tearDown() {
        DownloadStore.deleteAll()
        super.tearDown()
    }

    func test_fileURL_isStableForSameInput() {
        let a = DownloadStore.fileURL(for: "https://example.com/ep1.mp3")
        let b = DownloadStore.fileURL(for: "https://example.com/ep1.mp3")
        XCTAssertEqual(a, b)
    }

    func test_fileURL_differsForDifferentInputs() {
        let a = DownloadStore.fileURL(for: "https://example.com/ep1.mp3")
        let b = DownloadStore.fileURL(for: "https://example.com/ep2.mp3")
        XCTAssertNotEqual(a, b)
    }

    func test_fileURL_preservesKnownAudioExtension() {
        XCTAssertEqual(DownloadStore.fileURL(for: "https://example.com/ep.m4a").pathExtension, "m4a")
    }

    func test_fileURL_fallsBackToMp3ForUnknownExtension() {
        XCTAssertEqual(DownloadStore.fileURL(for: "https://example.com/stream?id=42").pathExtension, "mp3")
        XCTAssertEqual(DownloadStore.fileURL(for: "https://example.com/ep.php").pathExtension, "mp3")
    }

    func test_fileURL_queryStringVariantsHashDifferently() {
        let a = DownloadStore.fileURL(for: "https://example.com/ep.mp3?token=1")
        let b = DownloadStore.fileURL(for: "https://example.com/ep.mp3?token=2")
        XCTAssertNotEqual(a, b)
    }

    func test_storeExistsDeleteAndTotalBytes_lifecycle() throws {
        let audioURL = "https://example.com/lifecycle-\(UUID().uuidString).mp3"
        XCTAssertFalse(DownloadStore.exists(for: audioURL))

        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let payload = Data(repeating: 0xAB, count: 1024)
        try payload.write(to: temp)

        let stored = try DownloadStore.store(tempFile: temp, for: audioURL)
        XCTAssertTrue(DownloadStore.exists(for: audioURL))
        XCTAssertEqual(stored, DownloadStore.fileURL(for: audioURL))
        XCTAssertGreaterThanOrEqual(DownloadStore.totalBytes(), 1024)

        DownloadStore.delete(for: audioURL)
        XCTAssertFalse(DownloadStore.exists(for: audioURL))
    }
}
```

- [ ] **Step 2: Run — expect compile failure**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:VibecastTests/DownloadStoreTests 2>&1 | grep -E "(error:|BUILD FAILED)"`
Expected: `cannot find 'DownloadStore' in scope`.

- [ ] **Step 3: Implement**

Create `Vibecast/Vibecast/Downloads/DownloadStore.swift`:

```swift
import Foundation
import CryptoKit

/// Disk layout for downloaded episode audio. Files live in Application
/// Support (NOT Caches — Caches is purgeable under storage pressure and
/// offline listening must survive it), named by SHA256 of the episode's
/// audioURL — same content-addressed scheme as `ArtworkCache`. Paths are
/// always derived, never persisted, so container relocation between app
/// updates can't strand stale absolute paths.
enum DownloadStore {

    static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    static func fileURL(for audioURL: String) -> URL {
        let digest = SHA256.hash(data: Data(audioURL.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directoryURL
            .appendingPathComponent(name)
            .appendingPathExtension(preferredExtension(for: audioURL))
    }

    /// The URL's own extension when it's a recognized audio container,
    /// otherwise "mp3". AVPlayer uses the extension as a format hint for
    /// local files, so an accurate one matters more than a pretty one.
    private static func preferredExtension(for audioURL: String) -> String {
        guard let url = URL(string: audioURL) else { return "mp3" }
        let ext = url.pathExtension.lowercased()
        let known: Set<String> = ["mp3", "m4a", "m4b", "aac", "wav", "mp4"]
        return known.contains(ext) ? ext : "mp3"
    }

    static func exists(for audioURL: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: audioURL).path)
    }

    /// Move a completed download's temp file into the store. Must be called
    /// synchronously from `urlSession(_:downloadTask:didFinishDownloadingTo:)`
    /// — the temp file is deleted by the system when that delegate returns.
    @discardableResult
    static func store(tempFile: URL, for audioURL: String) throws -> URL {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        var destination = fileURL(for: audioURL)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempFile, to: destination)
        // Re-downloadable content is excluded from iCloud/iTunes backup
        // per Apple data-storage guidelines.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? destination.setResourceValues(values)
        return destination
    }

    static func delete(for audioURL: String) {
        try? FileManager.default.removeItem(at: fileURL(for: audioURL))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    static func totalBytes() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directoryURL, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return files.reduce(Int64(0)) { sum, url in
            sum + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }
}
```

- [ ] **Step 4: Run — expect pass** (same command as Step 2, all 6 tests pass).

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Downloads/DownloadStore.swift Vibecast/VibecastTests/DownloadStoreTests.swift
git commit -m "feat(downloads): DownloadStore — content-addressed audio files in App Support"
```

---

## Task 4: `DownloadPolicy` — pure selection + pruning logic

**Files:**
- Create: `Vibecast/Vibecast/Downloads/DownloadPolicy.swift`
- Test: `Vibecast/VibecastTests/DownloadPolicyTests.swift` (extend the Task 2 file)

**Interfaces:**
- Consumes: `Episode.downloadState`, `Episode.isManualDownload`, `Episode.publishDate`, `Episode.podcast` (Task 2).
- Produces (`static` on `enum DownloadPolicy`): `autoDownloadCandidates(from newEpisodes: [Episode]) -> [Episode]`, `pruneCandidates(in episodes: [Episode], keepLastN: Int) -> [Episode]`.

- [ ] **Step 1: Add failing tests to `DownloadPolicyTests.swift`**

Append inside the existing test class:

```swift
    // MARK: - autoDownloadCandidates

    func test_autoDownloadCandidates_picksNewestPerShow() throws {
        let context = try makeContext()
        let showA = makePodcast(in: context, title: "A")
        let showB = makePodcast(in: context, title: "B")
        let aOld = makeEpisode(in: context, podcast: showA, title: "a-old", daysAgo: 2)
        let aNew = makeEpisode(in: context, podcast: showA, title: "a-new", daysAgo: 0)
        let bOnly = makeEpisode(in: context, podcast: showB, title: "b", daysAgo: 1)

        let picked = DownloadPolicy.autoDownloadCandidates(from: [aOld, aNew, bOnly])

        XCTAssertEqual(picked.count, 2)
        XCTAssertTrue(picked.contains(where: { $0.title == "a-new" }))
        XCTAssertTrue(picked.contains(where: { $0.title == "b" }))
        XCTAssertFalse(picked.contains(where: { $0.title == "a-old" }))
    }

    func test_autoDownloadCandidates_skipsAlreadyDownloadedOrDownloading() throws {
        let context = try makeContext()
        let show = makePodcast(in: context, title: "A")
        let episode = makeEpisode(in: context, podcast: show, title: "ep", daysAgo: 0)
        episode.downloadState = .downloaded
        XCTAssertTrue(DownloadPolicy.autoDownloadCandidates(from: [episode]).isEmpty)
        episode.downloadState = .downloading
        XCTAssertTrue(DownloadPolicy.autoDownloadCandidates(from: [episode]).isEmpty)
    }

    func test_autoDownloadCandidates_emptyInput() {
        XCTAssertTrue(DownloadPolicy.autoDownloadCandidates(from: []).isEmpty)
    }

    // MARK: - pruneCandidates

    func test_pruneCandidates_keepsNewestN_dropsRest() throws {
        let context = try makeContext()
        let show = makePodcast(in: context, title: "A")
        var episodes: [Episode] = []
        for i in 0..<5 {
            let e = makeEpisode(in: context, podcast: show, title: "ep\(i)", daysAgo: i)
            e.downloadState = .downloaded
            episodes.append(e)
        }

        let victims = DownloadPolicy.pruneCandidates(in: episodes, keepLastN: 3)

        XCTAssertEqual(victims.count, 2)
        XCTAssertEqual(Set(victims.map(\.title)), ["ep3", "ep4"])  // the two oldest
    }

    func test_pruneCandidates_manualDownloadsExempt() throws {
        let context = try makeContext()
        let show = makePodcast(in: context, title: "A")
        var episodes: [Episode] = []
        for i in 0..<4 {
            let e = makeEpisode(in: context, podcast: show, title: "ep\(i)", daysAgo: i)
            e.downloadState = .downloaded
            e.isManualDownload = (i == 3)  // the oldest is manual
            episodes.append(e)
        }

        let victims = DownloadPolicy.pruneCandidates(in: episodes, keepLastN: 3)

        // 3 auto-downloads exist (ep0-ep2), all within keep-3; the manual
        // ep3 is exempt even though it's oldest.
        XCTAssertTrue(victims.isEmpty)
    }

    func test_pruneCandidates_zeroMeansUnlimited() throws {
        let context = try makeContext()
        let show = makePodcast(in: context, title: "A")
        var episodes: [Episode] = []
        for i in 0..<5 {
            let e = makeEpisode(in: context, podcast: show, title: "ep\(i)", daysAgo: i)
            e.downloadState = .downloaded
            episodes.append(e)
        }
        XCTAssertTrue(DownloadPolicy.pruneCandidates(in: episodes, keepLastN: 0).isEmpty)
    }

    func test_pruneCandidates_ignoresNonDownloaded() throws {
        let context = try makeContext()
        let show = makePodcast(in: context, title: "A")
        let e = makeEpisode(in: context, podcast: show, title: "ep", daysAgo: 0)
        e.downloadState = .failed
        XCTAssertTrue(DownloadPolicy.pruneCandidates(in: [e], keepLastN: 1).isEmpty)
    }
```

- [ ] **Step 2: Run — expect compile failure** (`cannot find 'DownloadPolicy' in scope`).

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:VibecastTests/DownloadPolicyTests 2>&1 | grep -E "(error:|BUILD FAILED)"`

- [ ] **Step 3: Implement**

Create `Vibecast/Vibecast/Downloads/DownloadPolicy.swift`:

```swift
import Foundation
import SwiftData

/// Pure selection logic for auto-download and retention. No I/O, no
/// UserDefaults — callers pass everything in, which keeps these fully
/// unit-testable against an in-memory container.
@MainActor
enum DownloadPolicy {

    /// From a batch of newly discovered episodes, the newest per show that
    /// isn't already downloaded or in flight. "Newest 1 per show per
    /// refresh" per the spec.
    static func autoDownloadCandidates(from newEpisodes: [Episode]) -> [Episode] {
        let eligible = newEpisodes.filter {
            $0.downloadState == DownloadState.none || $0.downloadState == .failed
        }
        let byShow = Dictionary(grouping: eligible) { $0.podcast?.persistentModelID }
        return byShow.compactMap { key, episodes in
            guard key != nil else { return nil }   // orphaned episodes: skip
            return episodes.max(by: { $0.publishDate < $1.publishDate })
        }
    }

    /// Downloaded, non-manual episodes beyond the newest `keepLastN`.
    /// `keepLastN == 0` means unlimited (prune nothing).
    static func pruneCandidates(in episodes: [Episode], keepLastN: Int) -> [Episode] {
        guard keepLastN > 0 else { return [] }
        let autoDownloaded = episodes
            .filter { $0.downloadState == .downloaded && !$0.isManualDownload }
            .sorted { $0.publishDate > $1.publishDate }
        guard autoDownloaded.count > keepLastN else { return [] }
        return Array(autoDownloaded.dropFirst(keepLastN))
    }
}
```

- [ ] **Step 4: Run — expect pass** (same command; all DownloadPolicyTests pass).

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Downloads/DownloadPolicy.swift Vibecast/VibecastTests/DownloadPolicyTests.swift
git commit -m "feat(downloads): DownloadPolicy — newest-per-show picker and keep-last-N pruning"
```

---

## Task 5: `DownloadManager` + `AppDelegate` + environment key

**Files:**
- Create: `Vibecast/Vibecast/Downloads/DownloadManager.swift`
- Create: `Vibecast/Vibecast/AppDelegate.swift`

**Interfaces:**
- Consumes: `DownloadStore` (Task 3), `DownloadPolicy` (Task 4), `DownloadSettings` (Task 1), `Episode.downloadState`/`isManualDownload`/`downloadedAt` (Task 2).
- Produces: `DownloadManager` — `init(modelContext:)`, `download(_ episode: Episode, manual: Bool)`, `cancelDownload(_:)`, `deleteDownload(_:)`, `deleteAllDownloads()`, `totalStorageBytes() -> Int64`, `episodeWasPlayed(_:)`, `autoDownload(newEpisodes: [Episode])`, `pruneAll()`, `var progress: [PersistentIdentifier: Double]`, `var backgroundCompletionHandler: (() -> Void)?`, `static let sessionIdentifier`. Environment key `\.downloadManager` (`DownloadManager?`). `AppDelegate` with `@MainActor static weak var downloadManager`.

No unit tests in this task — the policy and store layers it composes are covered by Tasks 1–4, and background-URLSession delegate behavior is verified manually in Task 10. Verify by building.

- [ ] **Step 1: Create `Vibecast/Vibecast/Downloads/DownloadManager.swift`**

```swift
import Foundation
import SwiftData
import Observation
import SwiftUI

/// Owns episode audio downloads end-to-end: enqueue, progress, terminal
/// state transitions, retention pruning, and delete-when-played.
///
/// Uses a background-configured URLSession so in-flight downloads keep
/// going when the app is backgrounded or terminated. Task↔episode mapping
/// is `taskDescription = episode.audioURL`, which survives process death —
/// on relaunch the session reconnects by identifier and episodes are
/// re-fetched from the model context by audioURL.
///
/// Live progress is in-memory only (never persisted); terminal states are
/// written to the Episode model so `@Query`-driven rows react.
@Observable
@MainActor
final class DownloadManager: NSObject {

    static let sessionIdentifier = "AnglinVibes.Vibecast.downloads"

    /// Fractional progress per in-flight episode, keyed by persistent ID.
    private(set) var progress: [PersistentIdentifier: Double] = [:]

    /// Stored by AppDelegate when iOS relaunches us for background session
    /// events; called once the session drains its event queue.
    @ObservationIgnored var backgroundCompletionHandler: (() -> Void)?

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private var session: URLSession!

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        reconcileOnLaunch()
    }

    // MARK: - Public API

    func download(_ episode: Episode, manual: Bool) {
        guard episode.downloadState != .downloaded,
              episode.downloadState != .downloading,
              !episode.audioURL.isEmpty,
              let url = URL(string: episode.audioURL) else { return }

        var request = URLRequest(url: url)
        // Wifi-only is read at enqueue time; tasks keep the policy they
        // were enqueued with.
        request.allowsCellularAccess = !DownloadSettings.wifiOnly()

        episode.downloadState = .downloading
        if manual { episode.isManualDownload = true }
        try? modelContext.save()
        progress[episode.persistentModelID] = 0

        let task = session.downloadTask(with: request)
        task.taskDescription = episode.audioURL
        task.resume()
    }

    func cancelDownload(_ episode: Episode) {
        let audioURL = episode.audioURL
        session.getAllTasks { tasks in
            for task in tasks where task.taskDescription == audioURL {
                task.cancel()
            }
        }
        episode.downloadState = DownloadState.none
        episode.isManualDownload = false
        progress[episode.persistentModelID] = nil
        try? modelContext.save()
    }

    func deleteDownload(_ episode: Episode) {
        DownloadStore.delete(for: episode.audioURL)
        episode.downloadState = DownloadState.none
        episode.isManualDownload = false
        episode.downloadedAt = nil
        progress[episode.persistentModelID] = nil
        try? modelContext.save()
    }

    func deleteAllDownloads() {
        let downloaded = DownloadState.downloaded.rawValue
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.downloadStateRaw == downloaded }
        )
        let episodes = (try? modelContext.fetch(descriptor)) ?? []
        for episode in episodes {
            episode.downloadState = DownloadState.none
            episode.isManualDownload = false
            episode.downloadedAt = nil
        }
        DownloadStore.deleteAll()
        try? modelContext.save()
    }

    func totalStorageBytes() -> Int64 {
        DownloadStore.totalBytes()
    }

    /// Honors the delete-when-played setting. Call from every code path
    /// that transitions an episode to `.played`.
    func episodeWasPlayed(_ episode: Episode) {
        guard DownloadSettings.deleteWhenPlayed(),
              episode.downloadState == .downloaded else { return }
        deleteDownload(episode)
    }

    /// Auto-download entry point, wired to SubscriptionManager's
    /// new-episode callback. Newest 1 per show; pruning runs when each
    /// download COMPLETES (pruning at enqueue would count the in-flight
    /// episode before it exists on disk).
    func autoDownload(newEpisodes: [Episode]) {
        guard DownloadSettings.autoDownloadEnabled() else { return }
        for episode in DownloadPolicy.autoDownloadCandidates(from: newEpisodes) {
            download(episode, manual: false)
        }
    }

    func pruneAll() {
        let podcasts = (try? modelContext.fetch(FetchDescriptor<Podcast>())) ?? []
        for podcast in podcasts { prune(podcast) }
    }

    // MARK: - Internals

    private func prune(_ podcast: Podcast) {
        let victims = DownloadPolicy.pruneCandidates(
            in: podcast.episodes,
            keepLastN: DownloadSettings.keepLastN()
        )
        for episode in victims { deleteDownload(episode) }
    }

    private func episode(forAudioURL audioURL: String) -> Episode? {
        var descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.audioURL == audioURL }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    fileprivate func finishDownload(audioURL: String, success: Bool) {
        guard let episode = episode(forAudioURL: audioURL) else { return }
        progress[episode.persistentModelID] = nil
        if success {
            episode.downloadState = .downloaded
            episode.downloadedAt = .now
            try? modelContext.save()
            if !episode.isManualDownload, let podcast = episode.podcast {
                prune(podcast)
            }
        } else {
            episode.downloadState = .failed
            try? modelContext.save()
        }
    }

    fileprivate func failDownload(audioURL: String) {
        finishDownload(audioURL: audioURL, success: false)
    }

    fileprivate func updateProgress(audioURL: String, fraction: Double) {
        guard let episode = episode(forAudioURL: audioURL) else { return }
        progress[episode.persistentModelID] = fraction
    }

    /// After relaunch: any episode stuck in `.downloading` with no live
    /// task resolves to `.downloaded` (file arrived while we were dead) or
    /// `.failed` (it didn't).
    private func reconcileOnLaunch() {
        session.getAllTasks { [weak self] tasks in
            let active = Set(tasks.compactMap(\.taskDescription))
            Task { @MainActor [weak self] in
                self?.reconcileStuckDownloads(activeAudioURLs: active)
            }
        }
    }

    private func reconcileStuckDownloads(activeAudioURLs: Set<String>) {
        let downloading = DownloadState.downloading.rawValue
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.downloadStateRaw == downloading }
        )
        let stuck = (try? modelContext.fetch(descriptor)) ?? []
        var changed = false
        for episode in stuck where !activeAudioURLs.contains(episode.audioURL) {
            if DownloadStore.exists(for: episode.audioURL) {
                episode.downloadState = .downloaded
                episode.downloadedAt = episode.downloadedAt ?? .now
            } else {
                episode.downloadState = .failed
            }
            changed = true
        }
        if changed { try? modelContext.save() }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let audioURL = downloadTask.taskDescription else { return }
        // The temp file dies when this method returns — move it NOW, on
        // this thread, before hopping to the main actor.
        let stored = (try? DownloadStore.store(tempFile: location, for: audioURL)) != nil
        Task { @MainActor in
            self.finishDownload(audioURL: audioURL, success: stored)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0,
              let audioURL = downloadTask.taskDescription else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.updateProgress(audioURL: audioURL, fraction: fraction)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Success and cancellation are handled elsewhere; only real
        // failures land here.
        guard let error, (error as NSError).code != NSURLErrorCancelled,
              let audioURL = task.taskDescription else { return }
        Task { @MainActor in
            self.failDownload(audioURL: audioURL)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - Environment

private struct DownloadManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: DownloadManager? = nil
}

extension EnvironmentValues {
    var downloadManager: DownloadManager? {
        get { self[DownloadManagerKey.self] }
        set { self[DownloadManagerKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Create `Vibecast/Vibecast/AppDelegate.swift`**

```swift
import UIKit

/// Minimal app delegate whose ONLY job is receiving the background-
/// URLSession relaunch callback and parking the completion handler on
/// DownloadManager. Everything else stays in the SwiftUI App.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Set by VibecastApp.init once the manager exists.
    @MainActor static weak var downloadManager: DownloadManager?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == DownloadManager.sessionIdentifier else {
            completionHandler()
            return
        }
        MainActor.assumeIsolated {
            AppDelegate.downloadManager?.backgroundCompletionHandler = completionHandler
        }
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"`
Expected: `** BUILD SUCCEEDED **`. If actor-isolation errors appear on the delegate methods, they are compile errors to fix (the `nonisolated` + `Task { @MainActor }` pattern above is the intended shape).

- [ ] **Step 4: Commit**

```bash
git add Vibecast/Vibecast/Downloads/DownloadManager.swift Vibecast/Vibecast/AppDelegate.swift
git commit -m "feat(downloads): DownloadManager — background URLSession engine + AppDelegate hook"
```

---

## Task 6: SubscriptionManager `onNewEpisodes` + VibecastApp wiring

**Files:**
- Modify: `Vibecast/Vibecast/Discovery/SubscriptionManager.swift`
- Modify: `Vibecast/Vibecast/VibecastApp.swift`
- Test: `Vibecast/VibecastTests/SubscriptionManagerTests.swift` (extend)

**Interfaces:**
- Consumes: `DownloadManager.autoDownload(newEpisodes:)` (Task 5).
- Produces: `SubscriptionManager.onNewEpisodes: (([Episode]) -> Void)?`; fires after each refresh save with only the newly inserted episodes. The initial `subscribe(to:)` path deliberately does NOT fire it (subscribing isn't "a new episode showed up").

- [ ] **Step 1: Write the failing test**

Open `Vibecast/VibecastTests/SubscriptionManagerTests.swift` and read its existing fakes (there is a fake `FeedFetcher` used to drive `refreshAll` in the existing tests — reuse it and the existing setup helpers exactly as the neighboring tests do). Add a test with this logic, adapted to the file's existing helper names:

```swift
    @MainActor
    func test_refreshAll_firesOnNewEpisodesWithOnlyInsertedEpisodes() async throws {
        // Arrange: a subscribed podcast whose existing feed has 1 episode,
        // then point the fake fetcher at a feed with that same episode
        // (same audioURL) plus 1 genuinely new one.
        // (Use the file's existing container/manager/fake-fetcher setup.)

        var received: [[Episode]] = []
        manager.onNewEpisodes = { received.append($0) }

        await manager.refreshAll()

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received[0].count, 1)
        XCTAssertEqual(received[0][0].audioURL, "https://example.com/new-episode.mp3")
    }

    @MainActor
    func test_refreshAll_noNewEpisodes_doesNotFireCallback() async throws {
        // Arrange: fake fetcher returns a feed identical to what's stored.
        var fired = false
        manager.onNewEpisodes = { _ in fired = true }

        await manager.refreshAll()

        XCTAssertFalse(fired)
    }
```

The comments in the Arrange sections describe intent; implement them with the concrete fixture code the existing tests in that file already use (fake fetcher returning a `ParsedFeed`, podcast pre-inserted into the in-memory container).

- [ ] **Step 2: Run — expect compile failure** (`no member 'onNewEpisodes'`).

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:VibecastTests/SubscriptionManagerTests 2>&1 | grep -E "(error:|BUILD FAILED)"`

- [ ] **Step 3: Implement in `SubscriptionManager.swift`**

Add the property near the other `var` declarations at the top of the class (after `private(set) var isImportingFeeds: Bool = false`):

```swift
    /// Fired after a refresh saves, with the episodes that were newly
    /// inserted by the merge (never existing/updated ones). Wired by
    /// VibecastApp to the download manager's auto-download entry point.
    /// Deliberately NOT fired by the initial subscribe — subscribing to a
    /// back catalog isn't "a new episode showed up."
    var onNewEpisodes: (([Episode]) -> Void)?
```

Change `mergeFeed` to return the inserted episodes. The current signature is `private func mergeFeed(_ feed: ParsedFeed, into podcast: Podcast)`; make it:

```swift
    @discardableResult
    private func mergeFeed(_ feed: ParsedFeed, into podcast: Podcast) -> [Episode] {
```

Inside, declare `var inserted: [Episode] = []` before the `for parsed in feed.episodes` loop; in the `else` branch (the new-episode insert), after `podcast.episodes.append(episode)` add `inserted.append(episode)`; and end the function with `return inserted` (after `podcast.lastFetchedAt = .now`).

In `refreshAll()`, collect and fire. Replace:

```swift
        for (podcast, feed) in fetched {
            mergeFeed(feed, into: podcast)
        }
        if !fetched.isEmpty {
            try? modelContext.save()
        }
        lastFullRefreshAt = .now
```

with:

```swift
        var newEpisodes: [Episode] = []
        for (podcast, feed) in fetched {
            newEpisodes.append(contentsOf: mergeFeed(feed, into: podcast))
        }
        if !fetched.isEmpty {
            try? modelContext.save()
        }
        lastFullRefreshAt = .now
        if !newEpisodes.isEmpty {
            onNewEpisodes?(newEpisodes)
        }
```

In `fetchAndMerge(_:)` (the detail-open refresh), replace:

```swift
        mergeFeed(feed, into: podcast)
        try? modelContext.save()
```

with:

```swift
        let newEpisodes = mergeFeed(feed, into: podcast)
        try? modelContext.save()
        if !newEpisodes.isEmpty {
            onNewEpisodes?(newEpisodes)
        }
```

Do not touch `subscribe(to:)`.

- [ ] **Step 4: Run — expect pass** (same command as Step 2; new tests pass, existing SubscriptionManagerTests still pass).

- [ ] **Step 5: Wire everything in `VibecastApp.swift`**

Add the delegate adaptor and manager state (after `@Environment(\.scenePhase)`):

```swift
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
```

and alongside the other `@State` managers:

```swift
    @State private var downloadManager: DownloadManager
```

In `init()`, the `MainActor.assumeIsolated` block currently builds `(player, subs)`. Extend it to also build and wire the download manager — the tuple becomes `(player, subs, downloads)`:

```swift
        let player: PlayerManager
        let subs: SubscriptionManager
        let downloads: DownloadManager
        (player, subs, downloads) = MainActor.assumeIsolated {
            let nowPlaying = NowPlayingService()
            let p = PlayerManager(engine: AVPlayerAudioEngine(), modelContext: c.mainContext, nowPlaying: nowPlaying)
            nowPlaying.controller = p
            let s = SubscriptionManager(
                searcher: iTunesSearchService(),
                fetcher: URLSessionFeedFetcher(),
                importer: StandardOPMLImporter(),
                modelContext: c.mainContext
            )
            let d = DownloadManager(modelContext: c.mainContext)
            s.onNewEpisodes = { [weak d] episodes in
                d?.autoDownload(newEpisodes: episodes)
            }
            p.downloadManager = d
            AppDelegate.downloadManager = d
            try? VibeSeeder.seedIfNeeded(in: c.mainContext)
            return (p, s, d)
        }
        _playerManager = State(initialValue: player)
        _subscriptionManager = State(initialValue: subs)
        _downloadManager = State(initialValue: downloads)
```

Note: `p.downloadManager = d` requires the `PlayerManager` property added in Task 7. **If executing tasks in order, add that line in Task 7 instead and leave this init without it** — this task's build must pass on its own. Concretely for Task 6: include everything above EXCEPT the `p.downloadManager = d` line.

In `body`, add the environment injection after `.environment(\.subscriptionManager, subscriptionManager)`:

```swift
                    .environment(\.downloadManager, downloadManager)
```

- [ ] **Step 6: Build + full test suite**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "(Test Case.*failed|error:|\*\* TEST)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Vibecast/Vibecast/Discovery/SubscriptionManager.swift Vibecast/Vibecast/VibecastApp.swift Vibecast/VibecastTests/SubscriptionManagerTests.swift
git commit -m "feat(downloads): onNewEpisodes refresh callback wired to auto-download"
```

---

## Task 7: PlayerManager — local playback + played hooks

**Files:**
- Modify: `Vibecast/Vibecast/Audio/PlayerManager.swift`
- Modify: `Vibecast/Vibecast/VibecastApp.swift` (one line)
- Test: `Vibecast/VibecastTests/PlayerManagerTests.swift` (extend)

**Interfaces:**
- Consumes: `DownloadStore.exists(for:)`/`fileURL(for:)` (Task 3), `DownloadManager.episodeWasPlayed(_:)` (Task 5), `Episode.downloadState` (Task 2).
- Produces: `PlayerManager.downloadManager: DownloadManager?` (weak, `@ObservationIgnored`); private `playbackURL(for:) -> URL?` used by both the play and restore paths.

- [ ] **Step 1: Write the failing tests**

Open `Vibecast/VibecastTests/PlayerManagerTests.swift` and read the existing fake engine (the suite already drives PlayerManager with a scripted `AudioEngine` — find its name and the property it records loads into; below assumes `FakeAudioEngine` with `var loadedURL: URL?` recorded in `load(url:startAt:)`; adapt names to what actually exists, extending the fake with a `loadedURL` recording property if it lacks one). Add:

```swift
    @MainActor
    func test_play_usesLocalFileWhenDownloadedAndFileExists() throws {
        // (Use the file's existing container + fake engine setup.)
        let episode = /* insert an episode via the file's existing fixture helper */
        episode.downloadState = .downloaded

        // Materialize a real file at the store path.
        try FileManager.default.createDirectory(at: DownloadStore.directoryURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: DownloadStore.fileURL(for: episode.audioURL))
        defer { DownloadStore.delete(for: episode.audioURL) }

        manager.play(episode)

        XCTAssertEqual(engine.loadedURL, DownloadStore.fileURL(for: episode.audioURL))
        XCTAssertTrue(engine.loadedURL?.isFileURL ?? false)
    }

    @MainActor
    func test_play_fallsBackToRemoteAndSelfHealsWhenFileMissing() throws {
        let episode = /* insert an episode via the file's existing fixture helper */
        episode.downloadState = .downloaded
        // No file written — the store path is empty for this URL.

        manager.play(episode)

        XCTAssertEqual(engine.loadedURL, URL(string: episode.audioURL))
        XCTAssertEqual(episode.downloadState, DownloadState.none)  // self-healed
    }
```

The `/* insert an episode … */` markers mean: use the same episode-creation fixture the neighboring tests in this file already use — do not invent a new fixture style.

- [ ] **Step 2: Run — expect failure** (compile error on `downloadState` fine-grained assertions passing but `loadedURL` mismatch, or missing property — depends on the fake; drive to a clean failing state before implementing).

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:VibecastTests/PlayerManagerTests 2>&1 | grep -E "(Test Case|error:|BUILD FAILED)"`

- [ ] **Step 3: Implement in `PlayerManager.swift`**

Add the manager reference after `@ObservationIgnored private let nowPlaying: NowPlayingService`:

```swift
    /// Weak back-reference for delete-when-played + local-file resolution.
    /// Assigned by VibecastApp after both objects exist; nil in unit tests
    /// that don't exercise downloads.
    @ObservationIgnored weak var downloadManager: DownloadManager?
```

Add the resolver as a private method (near `persistCurrentPosition`):

```swift
    /// Local file when downloaded and present on disk; remote URL
    /// otherwise. A downloaded episode whose file vanished (storage
    /// cleanup, reinstall edge) self-heals back to `.none` and streams.
    private func playbackURL(for episode: Episode) -> URL? {
        if episode.downloadState == .downloaded {
            if DownloadStore.exists(for: episode.audioURL) {
                return DownloadStore.fileURL(for: episode.audioURL)
            }
            episode.downloadState = DownloadState.none
            try? modelContext.save()
        }
        return URL(string: episode.audioURL)
    }
```

In `play(_:clearQueueSource:)`, replace:

```swift
        guard let url = URL(string: episode.audioURL), !episode.audioURL.isEmpty else {
```

with:

```swift
        guard !episode.audioURL.isEmpty, let url = playbackURL(for: episode) else {
```

In the `init` restore path, replace:

```swift
            if let url = URL(string: restoredEpisode.audioURL), !restoredEpisode.audioURL.isEmpty {
                engine.load(url: url, startAt: restoredEpisode.playbackPosition)
            }
```

with:

```swift
            if !restoredEpisode.audioURL.isEmpty, let url = playbackURL(for: restoredEpisode) {
                engine.load(url: url, startAt: restoredEpisode.playbackPosition)
            }
```

Add the played hooks. In `handlePlaybackEnd()`, after `try? modelContext.save()` (the line following `isPlaying = false`), add:

```swift
        downloadManager?.episodeWasPlayed(episode)
```

In `markPlayed(_:advance:)`, after `try? modelContext.save()`, add:

```swift
        downloadManager?.episodeWasPlayed(episode)
```

- [ ] **Step 4: Add the deferred wiring line in `VibecastApp.swift`**

In the `MainActor.assumeIsolated` block from Task 6, add (after `let d = DownloadManager(...)` / callback wiring):

```swift
            p.downloadManager = d
```

- [ ] **Step 5: Run — expect pass**, then the full suite.

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "(Test Case.*failed|error:|\*\* TEST)"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add Vibecast/Vibecast/Audio/PlayerManager.swift Vibecast/Vibecast/VibecastApp.swift Vibecast/VibecastTests/PlayerManagerTests.swift
git commit -m "feat(downloads): play from local file when downloaded + delete-when-played hooks"
```

---

## Task 8: Episode row badge + download swipe action

**Files:**
- Modify: `Vibecast/Vibecast/Views/EpisodeRowView.swift`
- Modify: `Vibecast/Vibecast/Views/PodcastDetailView.swift`
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift` (played-hook fallback only)

**Interfaces:**
- Consumes: `Episode.downloadState` (Task 2), `\.downloadManager` environment + `download/cancelDownload/deleteDownload/episodeWasPlayed/progress` (Task 5).
- Produces: `EpisodeRowView` gains `var downloadProgress: Double? = nil` (default keeps all existing call sites compiling).

No unit tests — SwiftUI view layer; verified by build + Task 10's manual pass.

- [ ] **Step 1: Add the badge to `EpisodeRowView.swift`**

Add the stored property after `var isPlaying: Bool = false`:

```swift
    /// Fractional progress while `.downloading`, from
    /// DownloadManager.progress. Nil when not downloading.
    var downloadProgress: Double? = nil
```

Change `metadata` to wrap the footnote with the badge:

```swift
    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            dateEyebrow
            titleText
                .frame(minHeight: 16 * 1.22 * 2, alignment: .topLeading)  // 2-line reservation
            HStack(spacing: 6) {
                downloadBadge
                footnote
            }
        }
    }
```

Add the badge view (near `footnote`):

```swift
    /// Compact download-state glyph leading the footnote. Nothing for
    /// `.none` — absence is the common case and shouldn't take space.
    @ViewBuilder
    private var downloadBadge: some View {
        switch episode.downloadState {
        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Brand.Color.accent)
                .accessibilityLabel("Downloaded")
        case .downloading:
            ProgressRing(
                fraction: downloadProgress ?? 0,
                size: 11,
                color: Brand.Color.accent
            )
            .accessibilityLabel("Downloading, \(Int((downloadProgress ?? 0) * 100)) percent")
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.orange)
                .accessibilityLabel("Download failed")
        case .none:
            EmptyView()
        }
    }
```

(`ProgressRing` is already a private struct in this same file — reuse it as-is.)

- [ ] **Step 2: Wire the detail view in `PodcastDetailView.swift`**

Add the environment (after the existing `@Environment` lines):

```swift
    @Environment(\.downloadManager) private var downloadManager
```

Pass progress into the row — the `EpisodeRowView(...)` call gains one argument after `isPlaying:`:

```swift
                    downloadProgress: downloadManager?.progress[episode.persistentModelID],
```

Add the trailing swipe directly after the existing `.swipeActions(edge: .leading, ...)` block:

```swift
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if let dl = downloadManager {
                        switch episode.downloadState {
                        case .none, .failed:
                            Button {
                                dl.download(episode, manual: true)
                            } label: {
                                Label("Download", systemImage: "arrow.down.circle")
                            }
                            .tint(Brand.Color.accent)
                        case .downloading:
                            Button {
                                dl.cancelDownload(episode)
                            } label: {
                                Label("Cancel", systemImage: "xmark.circle")
                            }
                            .tint(.gray)
                        case .downloaded:
                            Button {
                                dl.deleteDownload(episode)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
```

In the private `markPlayed(_:)` helper, the `else` fallback (no playerManager) also needs the played hook — after `try? modelContext.save()` add:

```swift
            downloadManager?.episodeWasPlayed(episode)
```

(The main path goes through `mgr.markPlayed`, which Task 7 already hooked.)

- [ ] **Step 3: Same fallback hook in `SubscriptionsListView.swift`**

This view has its own leading Played swipe with a private `markPlayed`-style helper mirroring PodcastDetailView's (search `func markPlayed` / `listenedStatus = .played` in the file). In its no-playerManager fallback branch — the one that sets `episode.listenedStatus = .played` directly and saves — add after the save:

```swift
            downloadManager?.episodeWasPlayed(episode)
```

If the view lacks a `@Environment(\.downloadManager)` line at this point (Task 9 adds one; task order may vary), add it with the other `@Environment` declarations:

```swift
    @Environment(\.downloadManager) private var downloadManager
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Views/EpisodeRowView.swift Vibecast/Vibecast/Views/PodcastDetailView.swift Vibecast/Vibecast/Views/SubscriptionsListView.swift
git commit -m "feat(downloads): row download badge + trailing download swipe in episode list"
```

---

## Task 9: Settings sheet + masthead gear button

**Files:**
- Create: `Vibecast/Vibecast/Views/DownloadSettingsView.swift`
- Modify: `Vibecast/Vibecast/Views/VibeMasthead.swift`
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`

**Interfaces:**
- Consumes: `DownloadSettings` get/set (Task 1), `DownloadManager.pruneAll()/deleteAllDownloads()/totalStorageBytes()` (Task 5).
- Produces: `VibeMasthead` gains `let onTapSettings: () -> Void` (breaking change — every `VibeMasthead(...)` call site including previews must add it).

- [ ] **Step 1: Create `Vibecast/Vibecast/Views/DownloadSettingsView.swift`**

A standard `Form` — intentionally system-styled for V1; brand styling is a follow-up.

```swift
import SwiftUI

/// Global download preferences + storage management. Presented as a sheet
/// from the masthead gear button.
struct DownloadSettingsView: View {
    @Environment(\.downloadManager) private var downloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var autoEnabled = DownloadSettings.autoDownloadEnabled()
    @State private var keepLastN = DownloadSettings.keepLastN()
    @State private var deleteWhenPlayed = DownloadSettings.deleteWhenPlayed()
    @State private var wifiOnly = DownloadSettings.wifiOnly()
    @State private var storageBytes: Int64 = 0
    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Download new episodes", isOn: $autoEnabled)
                        .onChange(of: autoEnabled) { _, value in
                            DownloadSettings.setAutoDownloadEnabled(value)
                        }
                    Picker("Keep per show", selection: $keepLastN) {
                        Text("1").tag(1)
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("10").tag(10)
                        Text("All").tag(0)
                    }
                    .onChange(of: keepLastN) { _, value in
                        DownloadSettings.setKeepLastN(value)
                        downloadManager?.pruneAll()
                        refreshStorage()
                    }
                } header: {
                    Text("Automatic downloads")
                } footer: {
                    Text("The newest episode of each show downloads when it appears. Episodes you download yourself are always kept.")
                }

                Section("Playback") {
                    Toggle("Delete when played", isOn: $deleteWhenPlayed)
                        .onChange(of: deleteWhenPlayed) { _, value in
                            DownloadSettings.setDeleteWhenPlayed(value)
                        }
                }

                Section("Network") {
                    Toggle("Download on Wi-Fi only", isOn: $wifiOnly)
                        .onChange(of: wifiOnly) { _, value in
                            DownloadSettings.setWifiOnly(value)
                        }
                }

                Section("Storage") {
                    LabeledContent("Storage used", value: formattedStorage)
                    Button("Delete All Downloads", role: .destructive) {
                        showDeleteAllConfirm = true
                    }
                    .disabled(storageBytes == 0)
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete all downloaded episodes?",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    downloadManager?.deleteAllDownloads()
                    refreshStorage()
                }
            }
            .onAppear { refreshStorage() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var formattedStorage: String {
        ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file)
    }

    private func refreshStorage() {
        storageBytes = downloadManager?.totalStorageBytes() ?? 0
    }
}

#Preview {
    DownloadSettingsView()
}
```

- [ ] **Step 2: Add the gear to `VibeMasthead.swift`**

Add the callback after `let onTapAdd: () -> Void`:

```swift
    let onTapSettings: () -> Void
```

In `body`, the corner-buttons HStack currently reads:

```swift
                HStack(spacing: 4) {
                    StackIcon(action: onTapStack)
                    AddIconButton(action: onTapAdd)
                }
```

Change to:

```swift
                HStack(spacing: 4) {
                    Button(action: onTapSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Brand.Color.inkSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Download settings")
                    StackIcon(action: onTapStack)
                    AddIconButton(action: onTapAdd)
                }
```

Then scan the REST of `VibeMasthead.swift` (previews at the bottom) and every other `VibeMasthead(` call site for the missing argument — add `onTapSettings: {}` to previews. `rg "VibeMasthead\(" Vibecast/` to find them all.

- [ ] **Step 3: Present the sheet from `SubscriptionsListView.swift`**

Add state (near `@State private var showManageVibes = false`):

```swift
    @State private var showDownloadSettings = false
```

In the `VibeMasthead(...)` call, add after `onTapAdd: { showAddSheet = true }`:

```swift
                    onTapSettings: { showDownloadSettings = true }
```

Find the existing sheet modifiers (search `.sheet(isPresented: $showManageVibes`) and add alongside them:

```swift
        .sheet(isPresented: $showDownloadSettings) {
            DownloadSettingsView()
                .environment(\.downloadManager, downloadManager)
        }
```

The view also needs the environment read — add with the other `@Environment` lines:

```swift
    @Environment(\.downloadManager) private var downloadManager
```

(Environment doesn't automatically flow into sheets' new presentation contexts in all configurations — passing it explicitly as above is the safe pattern.)

- [ ] **Step 4: Build**

Run: `xcodebuild build -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)"`
Expected: `** BUILD SUCCEEDED **`. Missing-argument errors on `VibeMasthead(` mean a call site was missed in Step 2.

- [ ] **Step 5: Commit**

```bash
git add Vibecast/Vibecast/Views/DownloadSettingsView.swift Vibecast/Vibecast/Views/VibeMasthead.swift Vibecast/Vibecast/Views/SubscriptionsListView.swift
git commit -m "feat(downloads): settings sheet with storage summary + masthead gear entry"
```

---

## Task 10: Full suite + manual verification

**Files:** none (verification only)

- [ ] **Step 1: Full test suite**

Run: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17" 2>&1 | grep -E "(Test Case.*failed|error:|\*\* TEST)"`
Expected: `** TEST SUCCEEDED **`, zero failures.

- [ ] **Step 2: Manual pass on simulator or device** (human-in-the-loop — report results, don't self-certify):

1. Fresh install → subscribe to 2–3 shows → pull-to-refresh → newest episode per show shows a progress ring, then the downloaded badge.
2. Airplane mode → downloaded episode plays; a non-downloaded episode does not.
3. Manually download an old episode → trigger new-episode pruning (or lower keep-N) → the manual download survives.
4. Delete-when-played ON → finish an episode → its badge and file disappear; storage number in settings drops.
5. Start a large download → background the app → return → it completed or is still progressing (not lost).
6. Settings: storage total looks plausible; Delete All zeroes it and clears all badges.
7. VoiceOver spot-check: badge labels ("Downloaded", "Downloading, N percent"), gear button ("Download settings").

- [ ] **Step 3: Report results to the user before any merge/TestFlight step.**
