# iPhone Duo support — design

Status: **approved 2026-11-19**. Plan: `docs/superpowers/plans/2026-11-19-iphone-duo.md`.
Visual mockups: `docs/design/iphone-duo/duo-proposal.html` (also published as an artifact).

## Intent

Vibecast 1.0.2 runs on iPhone Duo but was designed for one tall screen. On the
closed Duo the reserved strip beside the camera sits empty and the app looks
left-shifted; on the open Duo the second half of the display is unused. This
work makes Vibecast feel native in every Duo pose, using the side bar for the
masthead buttons and the second screen-half for the player and show detail.

## Sources

- HIG, "Designing for iPhone Duo" (page dated 2026-09-09, unchanged as of 2026-11-19).
- Apple developer docs: "Preparing your app for iPhone Duo", `ArrangementView`,
  `SplitArrangementViewStyle`, `OverlayArrangementViewStyle`, `ReservedRegion`,
  `toolbarVerticalEdge`, `toolbarVerticalBehavior(_:)`, `axisBehavior(_:)`,
  `ToolbarItemVisibilityPriority`, `presentationPlacement(_:)`,
  `backgroundExtensionEffect()`.

Everything below about iOS 27 API behaviour comes from reading those docs. None
of it has been run yet. Phase 0 exists to check it.

## Rules from the HIG that shape this design

- Do not design a layout per pose. Compact width for the outer display and
  regular width for the inner display cover every pose; let the layout expand.
- Keep function and state the same on both displays; show one more level of
  hierarchy on the inner display (Mail: list, or list + message).
- Toolbars move to a vertical bar on the side on the outer display and on the
  inner display in landscape. Inner display in portrait keeps horizontal bars.
- Do not override bar placement. Give every toolbar item a title and a symbol.
  Text-only and custom-view items are not shown vertically.
- Top of the vertical bar: Back/Close, then prominent actions. Items overflow
  from the bottom; set visibility priority to control which go first.
- Backgrounds may span the full width under the bar; scrolling content stays inset.
- Prefer system containers that handle the fold. Avoid large rearrangements when
  the device folds. Keep navigation outside an arrangement view, and do not put an
  arrangement view inside a split view, list or scroll view.

## Current state (1.0.2, `a6d4467`)

- `SubscriptionsListView` is the whole shell: `NavigationStack` > `ZStack` > `List`,
  with `.toolbar(.hidden, for: .navigationBar)`. Masthead buttons (gear, stack, +)
  are custom views in `VibeMasthead` row 1.
- Show detail is pushed with `navigationDestination(item: $selectedPodcast)`;
  `PodcastDetailView` wraps itself in a second `NavigationStack`.
- Player: `MiniPlayerBar` as a bottom overlay; `FullScreenPlayerView` as a sheet
  with fixed 280 pt artwork. Its content is about 730 pt tall, more than the
  678 pt outer display.
- Vibe gradient band: fixed 380 pt, ignores only the top safe area.
- Sheets (`AddPodcastSheet`, `ManageVibesView`, `DownloadSettingsView`,
  `VibeEditSheet`, `AddShowSheet`, import wizard) use `NavigationStack` + `.toolbar`
  with semantic placements; several items are text-only ("Cancel", "Done").
- `Info.plist`: portrait only on iPhone. Deployment target iOS 26.4.
  `TARGETED_DEVICE_FAMILY = 1`. CI (`.github/workflows/testflight.yml`) selects
  the newest Xcode 26.x.
- Duo canvases: outer 466 × 678 pt (measured in simulator). Inner assumed
  626 × 890 pt portrait / 890 × 626 landscape (1878 × 2670 px at 3x, unverified).

## Design: Library + Stage

Two regions:

- **Library** — today's main screen: masthead + show list (+ mini-player).
- **Stage** — where the two things that currently cover the Library live when a
  second screen-half exists. Content is one of:
  - `nowPlaying` (default when an episode is loaded)
  - `show(Podcast)` (after tapping a show's row)
  - `empty` (nothing loaded: splash stripes motif + "Pick your vibe.")

| Pose | Layout | Gear / Vibes / + | Player |
|---|---|---|---|
| Closed (outer, 466 × 678) | Library | Vertical bar | Mini-player → sheet |
| Open landscape (inner) | Library │ Stage | Vertical bar | Stage |
| Part-folded landscape (book) | Library │ Stage, divided at fold | Vertical bar | Stage |
| Open portrait (inner) | Library, larger | Masthead (as today) | Mini-player → sheet |
| Part-folded portrait (laptop) | Library over Stage | Masthead (as today) | Stage |
| Split View with another app | Library (compact) | Vertical bar on our outer edge | Mini-player → sheet |
| Any other iPhone | unchanged | Masthead (as today) | unchanged |

### Side bar

- When the environment reports a vertical bar edge, the Library shows system
  toolbar items and hides the masthead's row-1 buttons. Otherwise the masthead
  buttons stay and the navigation bar stays hidden, exactly as today.
- Items, top to bottom: Close (only when Stage shows a show; `cancellationAction`),
  **Add podcast** (`plus`, high priority), **Vibes** (stack symbol), **Download
  settings** (`gearshape`, low priority, first to overflow).
- Each item is a `Label` with title and SF Symbol. The custom `StackIcon` view
  cannot be used in the bar; use the matching SF Symbol.
- "Edit order" stays in the section label (text-only; belongs to the list).

### Closed pose

- Vibe band spans full width under the bar (ignore horizontal safe area on the
  band only, or `backgroundExtensionEffect()`); list content stays inset.
- Band height becomes proportional to the pane height, capped at 380 pt.
- Now Playing sheet uses the adaptive panel below so it fits 678 pt.

### Now Playing panel (shared by sheet and Stage)

Extract the body of `FullScreenPlayerView` into a panel with two arrangements
chosen by available space (`ViewThatFits` per project convention):

- **Tall**: artwork above title, scrubber, transport, volume. Artwork size is
  what remains after the controls, clamped to about 160–360 pt.
- **Wide** (short panes, e.g. 626 × 437 laptop deck): artwork left, title +
  scrubber + transport right.

(An Up Next list on the Stage is parked; see Decisions.)

### Two-pane behaviour

- Mini-player: hidden while the Stage shows `nowPlaying`; shown at the bottom
  of the Library pane while the Stage shows a show. Tapping it sets the Stage
  back to `nowPlaying`.
- Tapping a row's detail affordance sets `show(podcast)` on the Stage instead
  of pushing.
- Toasts stay over the Library pane.
- Add Podcast, Manage Vibes and Download Settings sheets request trailing
  placement so they cover the Stage half and leave the Library visible.

### Pose transitions (one source of truth)

`selectedPodcast`, `showFullScreenPlayer` and Stage content must be one piece of
state so nothing is lost when the device opens or closes:

- One pane → two panes: a pushed show becomes `show(podcast)`; an open player
  sheet is dismissed and the Stage shows `nowPlaying`.
- Two panes → one pane: `show(podcast)` becomes the push; `nowPlaying` collapses
  to the mini-player (do not auto-present the sheet).

### Laptop pose

- Library on top, Stage below (split arrangement, vertical axis, enabled only
  while a fold division is active; in flat portrait the Stage is not shown).
- In a half-height pane the masthead tightens: wordmark about 40 pt, CTA pill
  moves to the trailing side of the subtitle row. Target: four rows visible.
- Stage uses the wide Now Playing arrangement.

### Splash

Keep the wordmark off the fold: when a division region intersects the splash,
centre the wordmark block within one half.

## Suggested structure (builder may change)

- `StageModel` (`@Observable`, in `ViewModels/`): holds Stage content and the
  one-pane/two-pane flag; owns the transition rules above. Pure logic, unit
  tested (`test_stage_opensShow_whenTwoPane_setsShowContent`, etc.).
- `SubscriptionsListView` splits into `LibraryView` (the List) and `StageView`;
  `PodcastDetailView`'s content is extracted so it can render without its own
  `NavigationStack` on the Stage.
- iOS 27 path: inside the existing `NavigationStack`,
  `ArrangementView { LibraryView } secondary: { StageView }` with
  `.arrangementViewStyle(.split.axes(foldActive ? [.horizontal, .vertical] : .horizontal))`.
  `foldActive` comes from `reservedRegions(kind: .division)` on a `GeometryProxy`.
- iOS 26 path: `LibraryView` alone, as today.
- All iOS 27 symbols behind `if #available(iOS 27.0, *)`, isolated in a small
  number of wrapper views/modifiers so the rest of the code does not branch.

## Phases

0. **Verify assumptions** (spike, throwaway): inner display point size; value of
   `toolbarVerticalEdge` in each pose; whether toolbar items show in the vertical
   bar with the navigation bar title hidden; how a portrait-only app behaves on
   the landscape inner display and whether landscape can be enabled for the Duo
   without enabling it on other iPhones; whether `.split.axes(...)` can change
   with fold state; how to tell that the secondary view is displayed. Move CI to
   Xcode 27 (apps built with Xcode 26 do not extend under the Duo's status bar
   and camera).
1. **Closed pose** — side bar items, full-width band, adaptive Now Playing
   panel, sheet toolbar labels. Shippable alone.
2. **Library + Stage in landscape** — arrangement view, `StageModel`, pose
   transitions, mini-player rules.
3. **Laptop pose and polish** — vertical split on fold, tight masthead, wide Now
   Playing, trailing sheet placement, splash.

## Goals

- Every pose is usable with the same functions available.
- Controls keep their relative positions across poses.
- Other iPhones and iOS 26 see no change.

## Non-goals

- iPad support. Landscape on non-Duo iPhones. A dedicated Split View design.
- Camera/outer-display features. CarPlay. New navigation model on one screen.

## Anti-goals

- A bespoke layout per pose keyed off device model or screen size.
- Controls that disappear or jump when the device folds.
- Custom-drawn vertical bars instead of the system one.

## Decisions (owner review, 2026-11-19)

1. Laptop pose is Library over Stage. Revisit if it does not feel right in use.
2. **Up Next is parked** for a later update (interaction model undecided). The
   Stage's Now Playing has no Up Next list in this work.
3. Masthead buttons stay on non-Duo iPhones and move to the side bar only on
   the Duo. Owner's note: the top of the side bar is reserved for the combined
   battery/Wi-Fi indicator, so buttons are expected lower in the bar. The
   system places the items; we do not position them ourselves.
4. Non-Duo iPhones stay portrait-only.
5. Side bar order Add, Vibes, Settings; Settings overflows first.

## Phase 0 findings (2026-11-19, Xcode 27.1 SDK)

- All Duo APIs exist but are gated **iOS 27.1** (`ArrangementView`,
  `toolbarVerticalEdge`, `ReservedRegion`, `axisBehavior`, hinge APIs).
  `visibilityPriority` and `presentationPlacement` are iOS 27.0.
- Hinge state is public: SwiftUI `onHingeChange` / `DeviceHinge`
  (`closed`, `partiallyOpen`, `fullyOpen`; `nil` hinge on other devices) and
  UIKit `UIHingeInteraction` (calls its handler with the initial state).
- Orientation: Info.plist stays portrait-only and
  `AppDelegate.application(_:supportedInterfaceOrientationsFor:)` widens it
  while the Duo is open. The hinge is observed from a view in the SwiftUI
  hierarchy (`HingeObserver`), not a scene delegate: a scene delegate added in
  an update is not attached to an already-persisted scene session.
- The simulator's pose cannot be changed from the command line (no `simctl`
  control; DeviceHub is not scriptable), so only the closed pose was verified
  during implementation. Open and part-folded poses need a manual pass.
