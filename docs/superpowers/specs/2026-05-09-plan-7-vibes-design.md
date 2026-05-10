# Plan 7: Vibes Design Spec

## Goal

Introduce **Vibes** — user-managed, multi-tag groupings of subscribed podcasts that double as sequential listening queues — without disturbing Plan 6's editorial language or breaking the existing single-episode-tap behavior. Phase 2 of the three-phase iterative adoption from the design handoff.

## Background

Plan 6 shipped the editorial visual layer (paper-warm surface, Fraunces type, four-state row vocabulary) but explicitly deferred the queue-dependent treatments (UP NEXT pills, tinted card backgrounds, multi-vibe gradients, swipe-between-vibes, "Start the vibe" CTA) until vibes existed in the data model. This plan supplies the data model, the queue concept, and the editorial UI that builds on top.

The design references for this plan live at `docs/design/vibecast-visual-prototypes/project/`:

- `Vibecast Vibes Entry v2.html` / `vibes-entry-v2.jsx` — primary reference. Defines `HomeFinal` (swipeable masthead), `FilterBar2/Pill2`, `PodcastRowDots`, `VibeScreenAddShow`, `AddShowSheet`, `PodcastDetailVibes`, `YourVibesManage`.
- `vibes-shared.jsx` — the seeded 5-vibe palette: morning / around / workout / winddown / deepwork, each with `color` (band), `chip` (tinted bg), `ink` (text-on-chip) in oklch.
- `vibes-rows.jsx` — row treatment study. **Dots** is the chosen variant for v1.

The vibe set is **seeded + editable**: 5 vibes ship with the app on first launch, and the user has full CRUD on them — rename, delete, reorder, add new vibes. New user-created vibes pick from the same fixed 5-color palette.

## Scope

### In scope

- **Data model**: `Vibe`, `VibeMembership` (join with `position`), `QueueState` (singleton).
- **Vibe seeding**: insert the 5 palette vibes on first launch when `Vibe.count == 0` and `UserDefaults.vibesSeeded == false`. Idempotent: deleting all vibes after seeding does not re-seed.
- **Player queue layer**: `PlayerManager.startVibe(_:from:)`, `advanceQueue()`, `queueSourceVibe`. Auto-advance on `AVPlayerItem` ended. "Skip played" semantics in queue resolution.
- **Queue persistence**: `QueueState` is restored on `PlayerManager` init so the active vibe queue survives app restart.
- **Swipeable masthead** on `SubscriptionsListView` — cycles through `[All] + [Vibe in sortPosition order]`. Fades the vibe color band, shows pagination dots, presents the "Start the vibe" CTA on non-All states.
- **List filtering** below the masthead — when a vibe is active, the list shows only that vibe's members in per-vibe `position` order. Empty vibes show only the dashed `AddShowGhostRow`.
- **Dots row variant** (`PodcastRowDots`) replacing `PodcastRowView` everywhere. On All view: dots show every vibe the show is in (up to 3, then "+N"). On a filtered vibe view: dots are hidden (redundant).
- **`AddShowSheet`** — modal opened from the in-vibe ghost row. Search field over the user's library, checkbox circles in the vibe color, "ADDED" pill on already-tagged shows. Submitting batch-creates memberships at the end of the vibe's order.
- **`PodcastDetailVibes` section** — between description and episodes. Pill chips for every existing vibe, filled when tagged, outline when not. Tapping toggles membership. Trailing "New vibe" dashed pill opens the vibe-create flow.
- **`ManageVibesView`** — opened via a stack icon next to the existing search/add button on the home masthead. List of `vibe.chip`-tinted cards (name, show count, queued time, cover stack of up to 3). Edit mode toggles red-minus + drag handle, scale+rotate transform on drag. Tap a card outside edit mode opens `VibeEditSheet` (rename + 5-color picker). Add affordance: dashed ghost card at end of list.
- **Now-playing indicator** appears wherever the playing episode is shown, regardless of source vibe — same rule as today, no per-vibe filtering of the indicator.
- **Tests** for vibe CRUD, multi-tag membership, per-vibe ordering, queue start/advance/exhaustion, queue persistence round-trip.

### Out of scope (explicit)

- **Pinning** — Plan 8.
- **App Store launch / metadata / screenshots** — Plan 9.
- **Free-form vibe colors** — palette is fixed (5 colors). Color picker UI accepts only the 5 palette options.
- **Auto-tagging existing subscriptions** — first-launch seeding leaves all shows untagged. Users manually populate.
- **Vibe-aware sort suggestions** — no machine recommendations for which vibes a show should be in.
- **Cross-device sync of vibes** — same on-device-only posture as the rest of the app.
- **Smart vibes (rules-based)** — vibes are explicitly user-curated.
- **Search across vibes** — search remains today's "search results from iTunes" surface; vibe membership is not a search filter.
- **Reorder of episodes within a vibe queue** — queue order = vibe's podcast order, no episode-level queue editing.
- **"Up next" UI on the mini-player** — deferred. Mini-player keeps current behavior; the queue surfaces only via auto-advance + the masthead state on home.
- **Color/theme changes elsewhere** — the existing accent (`#2E94A8`) keeps its role on the All view and any non-vibe surface. Vibe colors only color vibe-scoped surfaces.

## Data model

Three new `@Model` types in `Vibecast/Vibecast/Models/`.

### `Vibe`

```swift
@Model
final class Vibe {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorKey: VibeColorKey  // enum: morning / around / workout / winddown / deepwork
    var sortPosition: Int       // ordering on Manage Vibes screen + masthead carousel
    var isSeeded: Bool          // true for the original 5; false for user-created
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \VibeMembership.vibe)
    var memberships: [VibeMembership] = []
}
```

`VibeColorKey` is a `String`-backed enum mapping to the oklch palette in `vibes-shared.jsx`. Each case carries `band`, `chip`, `ink` SwiftUI `Color` values resolved from oklch → sRGB at compile time (same convention Plan 6 used for the accent).

### `VibeMembership`

```swift
@Model
final class VibeMembership {
    var vibe: Vibe?
    var podcast: Podcast?
    var position: Int           // ordering within this specific vibe
    var taggedAt: Date

    init(vibe: Vibe, podcast: Podcast, position: Int) { ... }
}
```

`Podcast` gains an inverse:

```swift
@Relationship(deleteRule: .cascade, inverse: \VibeMembership.podcast)
var vibeMemberships: [VibeMembership] = []
```

Cascade rules: deleting a `Vibe` deletes all its memberships (the podcasts and their other vibes survive). Deleting a `Podcast` deletes its memberships (the vibes survive, with their other shows intact). Memberships only exist as a join — they have no independent lifetime.

### `QueueState`

```swift
@Model
final class QueueState {
    var sourceVibe: Vibe?
    var currentPodcast: Podcast?
    var currentEpisode: Episode?
    var lastUpdated: Date
}
```

Treated as a singleton: `PlayerManager` lazy-creates the row if none exists, and reads/writes the same row for the lifetime of the app. The "skip played" rule is *not* persisted in `QueueState` — it's recomputed at advance-time from each podcast's episodes, so freshly-arrived feed entries become candidates without any queue surgery.

### Migration

First launch after this plan ships:

1. SwiftData adds the three entities + the `Podcast.vibeMemberships` inverse via standard schema migration (no custom migration plan — additive only).
2. App startup runs a `seedVibesIfNeeded()` step in `VibecastApp` after `modelContainer` boot:
   - If `UserDefaults.vibesSeeded == true`: no-op.
   - Else if `Vibe.count == 0`: insert the 5 palette vibes (`isSeeded = true`, `sortPosition = 0...4`), set the flag.
   - Else (user has vibes already, somehow): set the flag, no insert.

The `UserDefaults` flag is what prevents re-seeding after the user deletes all 5 — a `Vibe.count == 0` check alone would re-seed in that case, which would surprise the user.

## Player & Queue layer

`PlayerManager` gets a queue concept layered on top of single-episode play. The existing `play(_:)` path stays unchanged for the subscriptions list and detail view.

### New surface

```swift
extension PlayerManager {
    func startVibe(_ vibe: Vibe, from podcast: Podcast? = nil)
    var queueSourceVibe: Vibe? { get }
}
```

`advanceQueue()` is private; it's wired to the `AVPlayerItem` end notification.

### `startVibe` semantics

1. Resolve `[(Podcast, Episode)]` for `vibe.memberships.sorted(by: position)`, where the `Episode` is the latest unplayed of each podcast. "Unplayed" = `listenedStatus != .played` AND `playbackPosition < durationSeconds * 0.95` (matches the existing completion threshold).
2. Drop podcasts where no unplayed episode exists.
3. If `from` is non-nil, drop everything before `from` in the resolved list (the rest still follows).
4. If the resulting list is empty: surface a transient toast (`"All caught up on this vibe"`) and no-op.
5. Otherwise: persist `QueueState{ sourceVibe: vibe, currentPodcast: first.podcast, currentEpisode: first.episode }`, then call existing `play(first.episode)`.

### Auto-advance

Wire to the existing `AVPlayerItem.didPlayToEndTimeNotification` observer. When the notification fires:

- If `queueSourceVibe == nil`: existing single-episode behavior (current code path, unchanged).
- If `queueSourceVibe != nil`: recompute `[(Podcast, Episode)]` from the *remaining* memberships (everything after `currentPodcast` in the source vibe's order, freshly resolving "latest unplayed"). Refreshing each lookup means a new episode that arrived during playback becomes a candidate. If the resolved list is non-empty: persist + `play` the next pair. If empty: clear `QueueState.sourceVibe` (queue ends) but keep `currentEpisode` populated so the mini-player still shows what just played. No auto-pause beyond AVPlayer's natural end.

### Queue invalidation

Any call to `play(_:)` outside the queue path clears `QueueState.sourceVibe` before delegating to existing playback. This is the "main subscriptions tap = single episode, not queue" rule. Tapping a row inside a filtered vibe view does *not* go through plain `play(_:)` — it calls `startVibe(activeVibe, from: tappedPodcast)`, which is the queue path.

### Persistence + restart

`PlayerManager.init` reads the singleton `QueueState`. If `currentEpisode != nil` and `sourceVibe != nil`, the queue is alive — auto-advance behavior is restored when the current episode ends. If `currentEpisode != nil` but `sourceVibe == nil`, that's a single-episode resume (existing behavior). The mini-player and full-screen player render either case identically; the queue is invisible UI.

### Delete vibe with active queue

If the user deletes the source vibe (via Manage Vibes red-minus), `QueueState.sourceVibe` becomes a dangling optional reference that SwiftData nils out via the cascade. The current episode keeps playing through to its natural end; auto-advance no longer fires because `sourceVibe` is nil. No confirmation dialog — same posture as deleting a podcast.

## Screens & Components

### `SubscriptionsListView` — masthead carousel

Current static masthead (eyebrow + "Vibecast" wordmark + italic subtitle + add button) becomes a horizontally-swipeable carousel of states:

- **State 0 — All**: today's masthead, unchanged. Subtitle: "Your shows, in your order." List below: all subscribed podcasts in global `sortPosition`.
- **State 1...N — Vibe**: eyebrow becomes the vibe name in mono caps (`MORNING`, `WINDDOWN`, etc.). Title is still "Vibecast" but the masthead background gets a vertical color band in `vibe.chip` fading top-down (full opacity at the top, transparent by the bottom of the masthead). Subtitle is replaced by a "Start the vibe" CTA button (filled with the vibe's primary color treatment, contrast text — implementer matches `vibes-entry-v2.jsx`'s `HomeFinal`). Stack icon and add button stay in their corners. Pagination dots below the subtitle row, one dot per state, active dot in `vibe.color`.

Swipe gesture lives on a new `VibeMasthead` view. The underlying list re-queries based on the active vibe: All view uses `@Query<Podcast>` sorted by global `sortPosition`; vibe view uses `@Query<VibeMembership>` filtered by `vibe == activeVibe` and sorted by per-vibe `position`, then maps to podcasts.

Empty active vibe: list shows only `AddShowGhostRow` (dashed border in `vibe.color`, label "Add a show to this vibe", tap opens `AddShowSheet`).

### `PodcastRowDots`

Replaces `PodcastRowView` at every call site. Same row layout (cover artwork, title, subtitle, position number, play button, separator) plus a row of small dots inside the row, near the title block. Each dot is 6×6, color = `vibe.color` for one vibe the show is in. Up to 3 dots, then `+N` text in `inkMuted` mono. Order of dots = vibe `sortPosition` ascending.

On a filtered vibe view: dots hidden entirely (every row in the list is in this vibe — redundant).

The four-state row vocabulary from Plan 6 (unplayed / started / now-playing / played) layers on top unchanged. Now-playing row card decoration (accent border + halo + top progress bar + accent circle in position slot) keeps using the *accent* color, not the vibe color, since the vibe color is already conveyed by the masthead band and the dots.

### `PodcastDetailView` — IN YOUR VIBES section

New section sits between the description block and the episodes list. Eyebrow `IN YOUR VIBES` (mono caps, `inkMuted`, hairline below). Pill row of every `Vibe` in `sortPosition` order:

- **Tagged**: filled `vibe.chip` background, `vibe.ink` foreground.
- **Untagged**: outlined (`inkHairline` border, `inkSecondary` foreground).
- Trailing **"+ New vibe"**: dashed border, `inkMuted` foreground. Tap opens `VibeEditSheet` in create mode (empty name field + color grid + Save). On Save, the new vibe is auto-tagged on this podcast.

Tapping any pill toggles membership: creates a `VibeMembership(vibe, podcast, position: vibe.memberships.count)` if untagged, deletes the matching membership if tagged. Save errors → toast.

### `AddShowSheet`

Modal presented from the in-vibe `AddShowGhostRow`. Layout:

- Title: "Add to {vibe.name}" in Fraunces serif, with `vibe.chip` underlay behind the sheet header.
- Search field (Inter body) — searches over `Podcast` (the user's library), not iTunes. This sheet is for tagging, not subscribing.
- List of all subscribed podcasts. Each row: cover, title, subtitle, checkbox circle on the right (filled `vibe.color` when checked, outline when unchecked). Already-tagged podcasts show "ADDED" mono pill in `vibe.chip` instead of a checkbox; tapping the row is a no-op.
- "Add {N}" button at the bottom — disabled until N ≥ 1. Submitting batch-creates memberships at the end of the vibe's order, dismisses the sheet.

Distinct from `AddPodcastSheet` (which subscribes to new podcasts via iTunes search). The two sheets share *no* code; their flows are different and trying to factor would muddy both.

### `ManageVibesView`

Opened from a `StackIcon` button on the home masthead, placed to the left of the existing add (`+`) button. The icon is a 3-layer plate per `vibes-entry-v2.jsx`'s `StackIcon2`. (No search button currently exists on the masthead; if future plans add one it sits to the left of the stack icon.)

List of `VibeManageCard` rows, one per vibe in `sortPosition` order. Card visual:

- Background: `vibe.chip` at full opacity.
- Cover stack: up to 3 cover thumbnails from the vibe's first 3 memberships, fanned slightly.
- Name in Fraunces serif, color `vibe.ink`.
- Show count + queued time eyebrow ("4 SHOWS · 2H 30M") in mono, color `vibe.ink @ 0.7`.

Toolbar: standard `EditButton`. Edit mode adds:

- Red minus circle on the leading edge (tap → confirm-less delete; cascade handles memberships).
- Drag handle on the trailing edge.
- Scale 1.04 + rotation 1° on the dragged item (matches `YourVibesManage` design).

End of list: dashed "+ Add vibe" ghost card. Tap opens `VibeEditSheet` in create mode.

Tapping a card outside edit mode opens `VibeEditSheet` in edit mode (current name pre-filled, current color highlighted in the picker).

### `VibeEditSheet`

Modal sheet for create + rename + recolor.

- Name field (Inter body).
- 5-color grid (the palette). Tap to select; selected color shows a ring.
- Save / Cancel.

Same sheet for create (empty initial state) and edit (pre-filled). Save persists the change; in create mode also calls back the parent so the new vibe can be auto-tagged on the originating context (PodcastDetailView's "+ New vibe" pill auto-tags the show).

## Lifecycle, errors, testing

### Vibe lifecycle

- **Seed**: first-launch only, gated by `UserDefaults.vibesSeeded` flag.
- **Create**: user from Manage Vibes ghost card or PodcastDetail "+ New vibe" pill. Auto-assigned `sortPosition = Vibe.count`.
- **Update**: rename and recolor via `VibeEditSheet`. No restrictions on duplicate names.
- **Delete**: user from Manage Vibes red-minus, no confirm. Cascade deletes memberships. If active queue's source: queue ends naturally per the Player section.
- **Reorder**: drag in Manage Vibes edit mode. Persists `sortPosition` for all vibes in the new order.

### Queue lifecycle

- **Start**: `startVibe` from masthead CTA or row tap inside filtered vibe.
- **Advance**: auto on `AVPlayerItem` end.
- **Exhaust**: queue ends silently; mini-player keeps showing the last episode.
- **Invalidate**: any out-of-band `play(_:)` call clears `sourceVibe`.
- **Restore**: on `PlayerManager` init from `QueueState`.

### Failure modes & user-visible messaging

| Failure | Surfacing |
|---|---|
| `startVibe` with all shows fully played | Toast: "All caught up on this vibe" |
| Auto-advance with no remaining unplayed | Silent end (mini-player keeps last episode displayed) |
| SwiftData save failure on membership toggle | Toast: "Couldn't save — try again" |
| SwiftData save failure on vibe rename / reorder / create | Same toast |
| Vibe deletion mid-playback | Queue ends silently; current episode plays through |

Toasts use the existing transient toast surface (whatever Plan 6 / earlier shipped — if no toast surface exists, this plan adds a minimal one in Plan 7's first task).

### Testing

In `Vibecast/VibecastTests/`, expand using the existing **XCTest** + in-memory `ModelContainer` pattern from Plan 3+:

- **`VibeTests`**
  - Seeding inserts 5 vibes when `Vibe.count == 0` and flag is false.
  - Seeding is idempotent: second call with flag set is a no-op.
  - Seeding doesn't re-insert after user deletes all 5 (flag still set).
  - Color key round-trips through SwiftData persistence.

- **`VibeMembershipTests`**
  - One podcast in 3 vibes: `Podcast.vibeMemberships.count == 3`.
  - Per-vibe ordering: same podcast at `position 0` in vibe A, `position 2` in vibe B.
  - Delete vibe → memberships cascade, podcast survives, podcast's other memberships survive.
  - Delete podcast → memberships cascade, vibes survive, vibes' other memberships survive.
  - Position reassignment after delete-from-middle.

- **`PlayerManagerVibeTests`**
  - `startVibe` empty resolved list → no-op + toast signal.
  - `startVibe` with `from:` slices the queue correctly (everything before `from` is dropped).
  - Auto-advance picks the next podcast's latest unplayed.
  - Auto-advance skips podcasts with no unplayed episodes.
  - Auto-advance on exhausted queue clears `sourceVibe`.
  - Out-of-band `play(_:)` clears `sourceVibe`.
  - Auto-advance picks up a freshly-added unplayed episode (re-resolution at advance-time).

- **`QueueStatePersistenceTests`**
  - Round-trip: start vibe → re-init `PlayerManager` → queue restored → auto-advance still works.

No view-layer tests beyond `#Preview`. The swipeable masthead, drag-reorder Manage screen, and AddShowSheet flow are best verified via simulator manual checks (Task N at the end of the plan).

## Open questions

None blocking. The following are deliberate choices to revisit if user feedback warrants:

- **No "up next" mini-player UI.** Could add later as a small queue strip above the mini-player. Out of scope for v1.
- **Manage Vibes uses cards, not rows.** If the list grows past ~10 vibes the cards get tall. Probably fine for v1; revisit if users hit the limit.
- **Now-playing indicator everywhere.** Considered restricting to the source vibe; rejected as harder to explain than "if it's playing, it looks like it's playing." Revisit if users find it confusing.

## Deferred to later plans

(Carried forward from Plan 6's deferred list, plus this plan's new deferrals.)

- Pinning, drag-to-pin sheet, pin expiration — Plan 8.
- Download management (toggleable per podcast in detail view + global manager screen + cap on storage) — Plan 8 or later.
- App Store metadata, screenshots, public-launch checklist — Plan 9.
- Dark mode — indefinite.
- Free-form vibe colors / theme picker — indefinite.
- Smart vibes (rules-based auto-tagging) — indefinite.
