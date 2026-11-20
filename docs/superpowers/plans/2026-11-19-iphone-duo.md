# iPhone Duo Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Vibecast lay out natively in every iPhone Duo pose (side-bar toolbar items, Library + Stage two-pane) without changing other iPhones.

**Architecture:** A hinge monitor (UIKit `UIHingeInteraction` in a scene delegate) publishes the pose. A pure resolver turns pose + container geometry into a layout mode (`single`, `sideBySide`, `stacked`). `SubscriptionsListView` hosts the Library and, on iOS 27.1, an `ArrangementView` whose secondary is the Stage. A `StageModel` owns what the Stage shows and how state carries across pose changes.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest. iOS 27.1 APIs behind availability checks; deployment target stays 26.4.

**Spec:** `docs/superpowers/specs/2026-11-19-iphone-duo-design.md`

## Global Constraints

- Deployment target stays iOS 26.4. Every Duo API sits behind `if #available(iOS 27.1, *)`.
- Non-Duo iPhones: no visual or behavioural change; portrait-only. `Info.plist` orientations unchanged.
- No custom-drawn vertical bar; toolbar items are `Label(title, systemImage:)`.
- Side bar order: Add podcast, Vibes, Download settings (low visibility priority).
- No Up Next list (parked).
- AGENTS.md rules: no force unwraps, views hold no business logic, tests `@MainActor final class`, names `test_subject_condition_expectation`, commit prefixes.
- Test command: `xcodebuild test -project Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination "platform=iOS Simulator,name=iPhone 17"`.

## Review Focus

- Device closes while a show is on the Stage → the show must appear as the pushed detail, not vanish. (Task 3 test)
- Device opens while the player sheet is up → sheet dismissed, Stage shows Now Playing, no double player. (Task 3 test)
- Podcast on the Stage is unsubscribed → Stage falls back to Now Playing/empty, no dangling model. (Task 3 test)
- Split View multitasking on the inner display (compact width, hinge open) → single pane. (Task 2 test)
- Closed Duo → portrait only; open Duo → landscape allowed; non-Duo → portrait only. (Task 1 test)

---

### Task 1: Pose monitor and Duo-only landscape

**Files:** Create `Vibecast/Vibecast/Duo/DuoPose.swift`, `Vibecast/Vibecast/Duo/SceneDelegate.swift`; modify `AppDelegate.swift`, `VibecastApp.swift`; test `VibecastTests/DuoPoseTests.swift`.

**Produces:**
- `enum DuoPose: Equatable { case notFoldable, closed, partiallyOpen, fullyOpen }`
- `extension DuoPose { var supportedOrientations: UIInterfaceOrientationMask }` — `.portrait` for `notFoldable` and `closed`, `.allButUpsideDown` otherwise.
- `@Observable @MainActor final class DuoPoseMonitor { static let shared; private(set) var pose: DuoPose; func update(_:) }`
- `EnvironmentValues.duoPose: DuoPose` injected at the root from the monitor.

- [ ] Tests: `test_supportedOrientations_notFoldable_isPortrait`, `_closed_isPortrait`, `_partiallyOpen_allowsLandscape`, `_fullyOpen_allowsLandscape`; `test_monitor_update_changesPose`.
- [ ] Implement; `SceneDelegate` attaches `UIHingeInteraction` to the scene's first window on activation, maps status to `DuoPose`, updates the monitor, and calls `setNeedsUpdateOfSupportedInterfaceOrientations()` on the root view controller. `AppDelegate` returns a scene configuration naming `SceneDelegate`.
- [ ] Run tests, build, commit `feat(duo): pose monitor and Duo-only landscape`.

### Task 2: Layout mode resolver

**Files:** Create `Vibecast/Vibecast/Duo/StageLayoutMode.swift`; test `VibecastTests/StageLayoutModeTests.swift`.

**Produces:** `enum StageLayoutMode: Equatable { case single, sideBySide, stacked }` and
`static func resolve(pose: DuoPose, size: CGSize, isRegularWidth: Bool, foldDividesView: Bool) -> StageLayoutMode`

Rules: `notFoldable`/`closed` → `single`. Wider than tall and regular width → `sideBySide`. `partiallyOpen`, taller than wide, fold divides the view → `stacked`. Everything else → `single`.

- [ ] Tests, one per rule plus: `test_resolve_fullyOpenPortrait_isSingle`, `test_resolve_openLandscapeCompactWidth_isSingle` (Split View), `test_resolve_partiallyOpenPortrait_foldElsewhere_isSingle`.
- [ ] Implement, run, commit `feat(duo): stage layout mode resolver`.

### Task 3: Stage model

**Files:** Create `Vibecast/Vibecast/ViewModels/StageModel.swift`; test `VibecastTests/StageModelTests.swift`.

**Produces:** `@Observable @MainActor final class StageModel` with
- `private(set) var shownPodcast: Podcast?`, `var isPlayerSheetPresented: Bool`, `private(set) var isTwoPane: Bool`
- `var pushedPodcast: Podcast?` (get/set; non-nil only when single pane — bound to `navigationDestination`)
- `func openShow(_:)`, `func closeShow()`, `func showNowPlaying()` (two-pane: clears the show; single: presents the sheet), `func setTwoPane(_:)` (entering two-pane dismisses the sheet), `func podcastsDidChange(existing: Set<PersistentIdentifier>)`
- `enum StageContent { case empty, nowPlaying, show(Podcast) }` and `func content(hasLoadedEpisode: Bool) -> StageContent`
- `func showsMiniPlayer(hasLoadedEpisode: Bool) -> Bool` — false only when two-pane and content is `nowPlaying`.

- [ ] Tests covering each Review Focus line above plus the mini-player rule.
- [ ] Implement, run, commit `feat(duo): stage model`.

### Task 4: Closed pose — side bar, band, adaptive Now Playing

**Files:** Create `Views/NowPlayingPanel.swift`, `Duo/DuoToolbar.swift`; modify `SubscriptionsListView.swift`, `VibeMasthead.swift`, `FullScreenPlayerView.swift`.

- [ ] `NowPlayingPanel(player:)`: tall and wide arrangements, artwork sized from available space (clamp 140–360). `FullScreenPlayerView` becomes handle + panel.
- [ ] `VibeMasthead` gains `showsCornerButtons: Bool` and `isTight: Bool`.
- [ ] On 27.1 when `toolbarVerticalEdge != nil`: toolbar items (Add / Vibes / Settings), navigation bar not hidden, masthead buttons hidden. Band ignores horizontal safe area.
- [ ] Verify on the Duo simulator (closed): screenshot main screen and player sheet. Run tests on iPhone 17 and screenshot to confirm no change. Commit `feat(duo): side bar toolbar and adaptive now playing`.

### Task 5: Library + Stage

**Files:** Create `Views/StageView.swift`, `Duo/StageSplitContainer.swift`; modify `SubscriptionsListView.swift`, `PodcastDetailView.swift`.

- [ ] `PodcastDetailView(podcast:embedsInNavigationStack:)` so the Stage can host it without a nested stack.
- [ ] `StageView` renders `StageContent`; empty state uses splash stripes + "Pick your vibe."
- [ ] `StageSplitContainer(mode:primary:secondary:)`: on 27.1 an `ArrangementView` with `.split.axes(...)` from the mode (`[]`, `.horizontal`, `.vertical`); otherwise primary only. DEBUG launch argument `-duoForceLayout sideBySide|stacked` substitutes a plain HStack/VStack so the panes can be checked without a foldable.
- [ ] Wire `StageModel` into `SubscriptionsListView`: row detail → `openShow`, mini-player tap → `showNowPlaying`, Close toolbar item (`cancellationAction`) when a show is on the Stage, mini-player visibility from the model, `setTwoPane` from the resolved mode.
- [ ] Verify with the debug argument (both layouts) on a simulator; run tests; commit `feat(duo): library and stage two-pane layout`.

### Task 6: Polish

- [ ] Tight masthead when the Library pane is shorter than 500 pt.
- [ ] Sheets (Add Podcast, Manage Vibes, Download Settings) use `.presentationPlacement(.trailing)` in `sideBySide`.
- [ ] Splash keeps the wordmark off an active fold.
- [ ] CI: `testflight.yml` selects the newest Xcode 27.x, falling back to 26.x.
- [ ] Full test run, closed-pose and iPhone 17 screenshots, commit.
