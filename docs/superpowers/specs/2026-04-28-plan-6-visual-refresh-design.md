# Plan 6: Visual Refresh Design Spec

## Goal

Translate the locked Editorial direction from the design handoff into the existing Vibecast app — paper-warm surface, ink text, Fraunces + Inter + JetBrains Mono type pairing, refined row vocabulary — without introducing any data model changes. Phase 1 of the three-phase iterative adoption from the design handoff.

## Background

The current app is functional but stylistically generic — system fonts, dark mode, blue accent, `mic.fill` artwork fallback. The Claude Design handoff (committed at `docs/design/vibecast-visual-prototypes/`) locked Direction B (Editorial) after a comparative study of three visual directions, then layered on a vibes/pinning model that's explicitly Phase 2/3 territory.

This plan delivers Phase 1 only: visual tokens + screen refresh + library wordmark. Net-new screens (vibe filter, pin sheet, etc.), data model changes (Vibe entity, QueueItem), and queue-dependent row vocabulary (position numbers, UP NEXT pills, tinted card backgrounds) are all out of scope.

## Scope

### In scope

- Bundle Fraunces (roman + italic), Inter, JetBrains Mono TTF files; register via `UIAppFonts`; expose typed `Font` API.
- Define color tokens in code (no Asset Catalog Color Sets needed for light-only).
- Force light mode via `.preferredColorScheme(.light)` at app root.
- Library header: replace `.navigationTitle("Subscriptions")` with custom Fraunces "Vibecast" wordmark + accent dot.
- Row visual refresh: all view files (`SubscriptionsListView`, `PodcastRowView`, `PlayControlView`, `PodcastDetailView`, `EpisodeRowView`, `SearchResultRow`, `AddPodcastSheet`, `MiniPlayerBar`, `FullScreenPlayerView`).
- **Four row states** with distinct visual hierarchies (unplayed / started / now-playing / played) — see `PodcastRowView` section for the full vocabulary.
- **Started state** (Episode `listenedStatus == .inProgress`): Fraunces 300 italic title at 78% ink, inline progress ring + "M LEFT · Show" eyebrow, "PAUSED AT N M · TOTAL MIN" footnote, dimmed position number, accent-outlined resume button.
- **Now-playing row card decoration**: 2pt accent border, accent-tinted halo box-shadow, 3pt top progress bar pinned to the row card's top edge, 20×20 accent circle replacing the position-number slot containing the 3-bar VU indicator, accent-filled right-side pause/play.
- **Left-edge sliver attractor on unplayed rows**: 3pt vertical bar at the row's leading edge. Color in Phase 1 = `Brand.fallbackColor(for: title)` (per-show deterministic — gives the "chromatic column" effect the design intends for All Vibes view, which is functionally identical to the Phase 1 library list since vibes don't exist yet).
- **Position numbers** (mono, 2-digit zero-padded) on every row, driven by `Podcast.sortPosition`. Dimmed to 30% on started/played rows so unplayed rows still win attention.
- **Fixed row height** with `min-height: 2.44em` on the title slot so single-line and two-line titles share the same row height.
- Played-state treatment: opacity 0.55 + `✓ PLAYED` mono text replacing duration on row.
- Cover artwork fallback: serif-initials on a colored square (replaces `mic.fill` in `PodcastRowView` and detail view).
- Hairline separators replacing system list dividers.

### Out of scope (explicit)

- Vibes (data model, screens, filter pills) — Plan 7.
- Pinning (data model, sheet, expiration, drag handles) — Plan 8.
- UP NEXT pills, tinted card backgrounds, multi-vibe gradients, swipe-between-vibes, "Start the vibe" CTA — all queue/vibe-dependent, ship with Plan 7.
- App icon (`v + period` letterform) — Plan 6.5.
- Splash screen (animated or static) — Plan 6.5.
- TestFlight pipeline setup — Plan 6.5.
- Dark mode adaptive variant — deferred indefinitely; user will iterate with Claude Design separately if and when desired.
- Reorder-mode visual changes — keeps system `EditButton` + iOS reorder handles.
- Any text/copy changes — UI strings remain identical.
- Onboarding flows — none exist today, none added.

## Visual tokens

### Surface palette

| Token | Value | Use |
|---|---|---|
| `bg` | `#F4EFE6` | Root view background |
| `paper` | `#FBF7EE` | Card / row surface |
| `paperDeep` | `#EFE9DD` | Subtle inset variant (not heavily used in Phase 1; reserved) |
| `ink` | `#1A1714` | Body text |
| `inkSecondary` | `ink @ 0.62` | Caption / metadata text |
| `inkMuted` | `ink @ 0.40` | Tertiary text, played-state copy |
| `inkFaint` | `ink @ 0.22` | Disabled / placeholder |
| `inkHairline` | `ink @ 0.10` | 1px separators, card borders |

### Accent

| Token | Value | Use |
|---|---|---|
| `accent` | `oklch(0.62 0.13 200)` ≈ `#2E94A8` (teal-blue) | Wordmark dot, in-flight states, primary play button fill, currently-playing indicator |

The exact sRGB conversion for the accent is computed at implementation time using a reference oklch → sRGB converter (e.g., `oklch.com`). The Phase 1 accent is a single fixed color since vibes don't exist yet; in Plan 7 the same role becomes vibe-tinted.

### Type roles

All sizes in Apple-points (SwiftUI default unit). Tracking values converted from CSS `em` to point spacing at the implementer's discretion (rough rule: tracking ≈ size × em-value).

| Role | Family | Weight | Size | Tracking | Style | Use |
|---|---|---|---|---|---|---|
| `display` | Fraunces | 500 | 28pt | -0.025em | — | Library header wordmark "Vibecast" |
| `serifTitle` | Fraunces | 500 | 28pt | -0.02em | — | Detail view podcast title, large screen titles |
| `serifSubtitle` | Fraunces | 500 | 22pt | -0.02em | — | Section headers (h3) |
| `serifBody` | Fraunces | 500 | 14pt | normal | — | Episode title in row (default / unplayed / now-playing) |
| `serifBodyLight` | Fraunces | 300 | 14pt | normal | — | Episode title for **started** rows (paired with italic; see below) |
| `serifLightItalic` | Fraunces-Italic | 300 | 14pt | normal | italic | Episode title for **started** rows. Light + italic = "still here, not done" |
| `uiBody` | Inter | 400 | 14pt (default) | normal | — | Body UI text, search input |
| `uiButtonLabel` | Inter | 600 | 14pt | -0.005em | — | Button labels |
| `monoEyebrow` | JetBrains Mono | 600 | 9pt (rows) / 11pt (section eyebrows) | +0.10em | uppercase | Show name eyebrow, durations, listening progress, played-state text |

Italic + light Fraunces is the carrier of the started-row treatment per the row-state iteration design pass — see Per-screen treatment §`PodcastRowView`. Roman Fraunces 500 carries everything else (default rows, now-playing, played, detail title, wordmark, sheet titles). Requires bundling **two** variable Fraunces files: `Fraunces[opsz,wght].ttf` (roman) and `Fraunces-Italic[opsz,wght].ttf` (italic).

### Spacing & radius

| Token | Value | Use |
|---|---|---|
| `rowPadding` | 12pt | Inset of row content (all sides) |
| `rowGap` | 8pt | Vertical space between rows in list |
| `cardRadius` | 14pt | Row container, card shapes |
| `inlineRadius` | 10-12pt | Smaller inline tiles (use 10pt as default) |
| `pillRadius` | 999pt | Pills, transport buttons |
| `coverRadiusSmall` | 4pt | Row cover (44×44) |
| `coverRadiusMedium` | 6pt | Detail-view cover (~120×120) |
| `coverRadiusLarge` | 8pt | Now-playing cover (~280×280) |
| `hairlineWidth` | 1pt | Borders, separators |
| `hitTargetMin` | 38pt | Minimum icon control hit target |
| `hitTargetRowPlay` | 56pt | Row's right-side play button container |
| `hitTargetPrimaryPlay` | 70pt | Full-screen player's primary play button |

### Motion

| Property | Value |
|---|---|
| Now-playing VU bars | 3 bars, 0.6-0.95s ease-in-out alternate, randomized per bar |
| Skip 15/30 button press | Rotate 30° for direction (forward CW, back CCW), snap back, light haptic impact |
| Sheet | Slide from bottom, 45% black scrim, 36×4 drag handle |

## Per-screen treatment

### `SubscriptionsListView`

- Replace `NavigationStack` `.navigationTitle("Subscriptions")` with a custom large-title view: Fraunces 28pt "Vibecast" + 6.5×6.5pt accent dot trailing the final `t`, baseline-aligned. Position: top-left of safe area, inset 16pt from leading edge, 12pt below safe-area top.
- Toolbar `+` and `EditButton` retained, restyled with Inter 14pt 600 ink-color labels.
- Background: `Color.bg`.
- List style: `.plain` with custom row backgrounds (`.listRowBackground(Color.paper)`) and `.listRowSeparator(.hidden)` — replace separators with custom 1px hairlines drawn inside `PodcastRowView`.
- Empty state (`ContentUnavailableView`): Fraunces title, Inter description, accent-tinted icon.

### `PodcastRowView`

Four states share the same card template (cover + meta + control on the right) and a fixed row height (`min-height: 2.44em` on the title slot reserves space for two lines so 1-line and 2-line titles produce uniform row heights). The **left slot** is a small column to the left of the cover that holds a position number (mono, 2-digit zero-padded) — its weight changes with state. State is derived from `Episode.listenedStatus` plus the player's current-episode/isPlaying flags:

| Episode state | Player state | Row state |
|---|---|---|
| `.unplayed` | not current OR current+!playing | `unplayed` |
| `.inProgress` | not current | `started` |
| `.played` | not current | `played` |
| any | current+playing | `now-playing` |
| any | current+!playing (i.e., loaded but paused) | `now-playing` (paused variant — same card decoration, glyph swap) |

State precedence: `now-playing` wins over everything else; otherwise listenedStatus drives.

#### Common template

```
┌─ leading edge ──────────────────────────────────────────────────┐
│ │       ┌────┐                                                  │  ← cardRadius 14pt
│ │  01   │Cov │   SHOW NAME · 9pt MONO · ink/0.62                │  ← rowPadding 12pt
│s│       │ 44 │                                                  │
│l│       │×44 │   Episode Title (Fraunces 14pt — weight/style    │
│i│       │ 4pt│   varies by state)                               │
│v│       └────┘                                                  │
│e│            DURATION FOOTNOTE (mono 9pt ink/0.40)              │
│r│                                                  ┌──────┐    │
│ │                                                  │ ▶/⏸ │    │  ← right control,
│ │                                                  └──────┘    │     56pt hit target
└─────────────────────────────────────────────────────────────────┘
```

The `sliver` channel (3pt wide, leading edge) is present only on **unplayed** rows. The position-number column is always present (with state-specific opacity).

#### State details

**`unplayed` (default attention-attractor)**
- Background: `paper`
- Border: 1pt `inkHairline`
- **Left sliver**: 3pt × full row height, color = `Brand.fallbackColor(for: podcast.title)` (per-show deterministic from the existing 8-color palette; produces a chromatic column down the list — the design intends "primary vibe" but Phase 1 has no vibes, so per-show deterministic is the closest equivalent and behaves identically in this view)
- Position number: mono 9pt, `inkSecondary` (62%)
- Cover: 44×44, `coverRadiusSmall` (4pt), via `CoverArtwork` helper
- Show name eyebrow: `monoEyebrow` 9pt uppercase, `inkSecondary`
- Title: **`serifBody` Fraunces 500 14pt**, `ink` (full)
- Footnote: `{TOTAL} MIN` in `monoEyebrow` 9pt, `inkMuted`
- Right control: `paper` ring + `inkHairline` border + `play.fill` glyph in `ink`

**`started` (downplayed — "still here, not done")**
- Background: `paper`
- Border: 1pt `inkHairline`
- **No left sliver** (the sliver is reserved as the unplayed attractor — leaving it off makes started rows visibly quieter)
- Position number: mono 9pt at **30% ink** (so unplayed rows still win attention)
- Cover: same as unplayed (44×44, 4pt radius)
- Show name eyebrow: includes a small inline progress ring (~11pt circle, `accent`-stroked, fill clockwise to `playbackPosition / duration`), then `{N}M LEFT` in `accent` ink color (Phase 1 single-color), then `· {Show name}` in `inkMuted`
- Title: **`serifLightItalic` Fraunces-Italic 300 14pt at 78% ink**. Light + italic together is the carrier of the started state.
- Footnote: `PAUSED AT {N}M · {TOTAL} MIN TOTAL` in `monoEyebrow` 9pt, `inkMuted`
- Right control: `paper` ring + `accent` border + `arrow.clockwise` glyph in `accent` (resume — distinct from unplayed's `play.fill` and played's transparent-replay)

**`now-playing` (active card — the only filled, framed row)**
- Background: `paper`
- **Border**: 2pt `accent` (vs 1pt hairline for inactive — doubles the edge weight)
- **Halo**: `box-shadow` equivalent — 0pt offset Y +8pt blur 24pt color = `accent.opacity(0.20)`. SwiftUI uses `.shadow(color:radius:y:)` modifier.
- **Top progress bar**: 3pt tall, pinned flush to the row card's top inner edge (clipped by the card's rounded corners — set `.clipShape(RoundedRectangle(cornerRadius: cardRadius))` on the card). Track: `ink.opacity(0.08)`, fill: `accent`, width: `playbackPosition / duration` of the row.
- **Left slot**: position number is replaced by a 20×20pt `accent`-filled circle. **`now` (playing)**: contains `NowPlayingIndicator` (3-bar VU animation in `paper` color). **`now-paused`**: contains a static 2-bar pause glyph in `paper` color.
- Cover: same as unplayed (44×44, 4pt radius). **No** VU badge on the cover — the card decoration is the dominant signal; the cover stays clean.
- Show name eyebrow: `monoEyebrow` 9pt, `inkSecondary`
- Title: **`serifBody` Fraunces 500 14pt**, `ink` (full)
- Footnote: `{TOTAL} MIN · {N}M IN` — the `{N}M IN` half is rendered in `accent` ink so live progress reads twice (top progress bar visually + footnote numerically)
- Right control: 38×38pt **`accent`-filled circle** with `paper`-color glyph. Playing → `pause.fill`. Paused → `play.fill`. The only filled-circle right-control in the row stack — everything else is outlined.

**`played` (consumed — fades back)**
- Background: `paper`
- Border: 1pt `inkHairline`
- **No left sliver**
- Position number: mono 9pt at **30% ink**
- Whole row: `opacity 0.55`
- Cover: same (44×44, 4pt radius)
- Show name eyebrow: same as unplayed but inheriting the row's 0.55 opacity
- Title: `serifBody` Fraunces 500 14pt, `ink` (full — but inheriting row opacity)
- Footnote: `✓ PLAYED` (with `checkmark` SF Symbol prefix) in `monoEyebrow` 9pt, `inkMuted`
- Right control: transparent + `arrow.clockwise` glyph in `inkMuted`

**Empty fallback** (`snapshot.latestEpisode == nil`)
- Cover: same fallback rendering (CoverArtwork with no URL → initials)
- "No episodes" in `serifLightItalic` 13pt, `inkMuted`, where the title would be
- No footnote, no right control
- No sliver

#### The `RowSliver` and `NowPlayingCard` helper views

To keep `PodcastRowView` readable, two small private helpers in `Vibecast/Vibecast/Views/`:

- **`RowSliver`** — a 3pt-wide `Rectangle().fill(color)` aligned to the row card's leading edge, full row height. Used as a leading-aligned overlay or as the first child of an `HStack(spacing: 0)` ahead of the row content. Color is passed in (Phase 1 = `Brand.fallbackColor(for: title)`).
- **`NowPlayingCard`** — a `ViewModifier` (or wrapping container) that adds the 2pt accent border + halo shadow + 3pt top progress bar overlay to whatever row content is inside. Takes `progressFraction: Double` and `isPlaying: Bool` as input. Encapsulates the "active card framing" so other surfaces can adopt it later.

### `PlayControlView`

The right-side button. 56pt hit target, ~30pt visible glyph circle.

| State | Background | Glyph | Glyph color |
|---|---|---|---|
| Default (paused, not current) | `paper` ring + `inkHairline` border | `play.fill` | `ink` |
| Current + playing | `accent` filled circle | `pause.fill` | `paper` |
| Current + paused | `accent` filled circle | `play.fill` | `paper` |
| Played | transparent | `arrow.clockwise` | `inkMuted` |

### `PodcastDetailView`

- Background `bg`. Custom nav-title with Fraunces 22pt podcast name + small accent dot.
- Hero: cover at ~120×120, `coverRadiusMedium` (6pt). Below cover: publisher in `monoEyebrow`, podcast title in `serifTitle` 28pt with `-0.02em` tracking. Then podcast description in `uiBody`, line-height 1.5.
- Episode list: same row vocabulary as `PodcastRowView` minus the cover (since all episodes share the podcast cover up top). Each row shows date in `monoEyebrow`, title in `serifBody`, duration + listening-progress in `monoEyebrow`. Played state: opacity 0.55 + `✓ PLAYED`.

### `EpisodeRowView`

Same four-state vocabulary as `PodcastRowView` minus the cover (the podcast cover is up in the detail view's hero) and minus the show-name eyebrow (every row in the detail view shares the same show). Eyebrow becomes the publish date in `monoEyebrow`. Title weight/style follows the same state rules: roman 500 for unplayed/now-playing/played, light italic 300 at 78% ink for started. Footnote in `monoEyebrow`: `{TOTAL} MIN` (unplayed/now-playing), `PAUSED AT {N}M · {TOTAL} MIN TOTAL` (started), `✓ PLAYED` (played). Now-playing card decoration (border + halo + top progress bar) applies the same way. No left sliver in the detail view's episode list (the sliver lives only on the library list where it picks up the podcast's per-show fallback color; inside a detail view all episodes share one podcast so the sliver carries no information).

### `SearchResultRow`

- 44×44 cover at `coverRadiusSmall`.
- Author/show name in `monoEyebrow` (above title).
- Title in `serifBody`.
- Subscribe button states (right side, 56pt hit target):
  - Idle: `paper` ring + `+` glyph in ink.
  - In-flight: `accent`-filled circle with `ProgressView` (white).
  - Subscribed: `accent`-filled circle with `checkmark` in white.
  - Recently failed: `paper` ring + `+` glyph + inline red text "Couldn't add — try again" below the row.
- Already-existing 4-state accessibility labels (from Plan 5 Task 10) preserved.

### `AddPodcastSheet`

- Sheet bg `bg`. Drag handle 36×4 at top in `inkHairline` color.
- Sheet title "Add Podcast" in `serifSubtitle`.
- Search input: Inter 14pt body, paper-colored capsule with hairline border.
- "Import from File" button: outlined paper ring + ink label, Inter 14pt 600.
- Result rows: `SearchResultRow` (above).

### `MiniPlayerBar`

- Container: paper bg, `cardRadius` 14pt, hairline border, ~64pt tall.
- Left: 44×44 cover at `coverRadiusSmall`.
- Center: episode title in `serifBody`, podcast name in `monoEyebrow` below. Two-line vertical layout.
- Right: skip-back-15 (38×38) + play/pause (56×56, accent-filled when playing) + skip-forward-30 (38×38).
- Bottom edge: 2pt accent-color progress sliver across the entire width, animated.
- Tap container expands to `FullScreenPlayerView`.

### `FullScreenPlayerView`

- Paper bg.
- Top: drag-down handle, "Now Playing" eyebrow in `monoEyebrow`.
- Cover: ~280×280, `coverRadiusLarge` (8pt), centered, drop shadow `0 8 20 rgba(0,0,0,0.10)`.
- Below cover: podcast name in `monoEyebrow`, episode title in `serifTitle` 28pt (centered, two-line max).
- Scrubber: hairline track, accent-filled progress, draggable thumb. Time labels in `monoEyebrow`.
- Transport row: skip-back-15 (56×56), primary play (70×70 accent-filled when playing, paper-ring with ink glyph when paused), skip-forward-30 (56×56). All in pill containers.
- Bottom: existing `SystemVolumeView` (MPVolumeView from Plan 5 Task 3) — keeps current behavior.

## Cover artwork fallback

When `podcast.artworkURL` is nil or fails to load, render a colored square with serif initials in place of the current `mic.fill` SF Symbol.

### Initials algorithm

1. Take `podcast.title`, lowercase, split on whitespace.
2. Filter out stop words: `["the", "a", "an", "of", "and", "with", "&"]`.
3. Take first letter of first remaining word, uppercase.
4. If 2+ words remain after filtering, take first letter of last remaining word, uppercase.
5. Concatenate (1 or 2 letters total).

Examples:
- "Hard Fork" → "HF"
- "The Daily" → "D" (after stripping "the")
- "Radiolab" → "R"
- "99% Invisible" → "9I" (digit retained)
- "Conan O'Brien Needs A Friend" → "CF" (first/last after stripping "a")

### Color algorithm

Pre-defined palette of 8 muted oklch colors. Implementer computes exact sRGB equivalents using a reference oklch → sRGB converter (`oklch.com` or equivalent); the hex values below are approximations for design intent only.

```
oklch(0.42 0.13 18)   ≈ #6E3A1C  rust
oklch(0.42 0.13 220)  ≈ #2A4F6E  steel blue
oklch(0.42 0.13 145)  ≈ #2C5A3D  forest
oklch(0.42 0.13 280)  ≈ #4A3C6B  plum
oklch(0.42 0.13 38)   ≈ #6E4A1C  amber
oklch(0.42 0.13 200)  ≈ #1F546E  teal
oklch(0.42 0.13 320)  ≈ #6E2E5A  magenta
oklch(0.42 0.13 60)   ≈ #6E5A1C  ochre
```

Pick via `abs(podcast.title.hashValue) % 8`. Stable across launches because Swift's `String.hashValue` uses a per-process seed but the result is consistent within a run. For cross-run stability, use a custom djb2 hash on the title's UTF-8 bytes.

Initials rendered in Fraunces 500, color `paper` (`#FBF7EE`), centered. Square sized to fit the cover slot (44×44 in rows, ~120×120 in detail, ~280×280 in full-screen player). Initial size scales: ~16pt at 44×44, ~38pt at 120×120, ~80pt at 280×280.

## Architecture

### `Brand.swift` — central token surface

Single file at `Vibecast/Vibecast/Brand/Brand.swift`. No environment keys (overengineered for static tokens):

```swift
enum Brand {
    enum Color {
        static let bg = SwiftUI.Color(red: 0.957, green: 0.937, blue: 0.902)
        static let paper = SwiftUI.Color(red: 0.984, green: 0.969, blue: 0.933)
        // ... all surface palette + accent
    }
    enum Font {
        static func display(size: CGFloat) -> SwiftUI.Font { ... }
        static func serifTitle(size: CGFloat) -> SwiftUI.Font { ... }
        // ... all roles
    }
    enum Layout {
        static let rowPadding: CGFloat = 12
        static let rowGap: CGFloat = 8
        // ... all spacing tokens
    }
    enum Radius {
        static let card: CGFloat = 14
        static let coverSmall: CGFloat = 4
        // ... all radii
    }
    enum HitTarget {
        static let min: CGFloat = 38
        // ...
    }
    enum FallbackPalette {
        static let colors: [SwiftUI.Color] = [...8 entries]
    }
}
```

Call sites: `.foregroundStyle(Brand.Color.ink)`, `.font(Brand.Font.serifBody())`, `.padding(Brand.Layout.rowPadding)`. Discoverable via `Brand.` autocomplete.

### Resources

- `Vibecast/Vibecast/Resources/Fonts/` — bundled TTF files.
  - `Fraunces[opsz,wght].ttf` (variable, opsz 9-144, wght 100-900) — roman
  - `Fraunces-Italic[opsz,wght].ttf` (variable, opsz 9-144, wght 100-900) — italic. Required for the started-row treatment (Fraunces 300 italic).
  - `Inter[wght].ttf` (variable, wght 100-900)
  - `JetBrainsMono[wght].ttf` (variable, wght 100-800)
- `Info.plist` `UIAppFonts` array registers all four filenames.

Bundle size impact: ~2 MB total (variable fonts include all weights, italic adds ~600 KB).

### Light mode enforcement

In `VibecastApp.swift`:

```swift
WindowGroup {
    ContentView()
        .preferredColorScheme(.light)
}
```

This overrides the system appearance so dark-mode users still see the editorial palette. Adopting iOS dark mode is deferred per design constraints.

### Cover artwork fallback view

New file `Vibecast/Vibecast/Views/CoverArtwork.swift`:

```swift
struct CoverArtwork: View {
    let urlString: String?
    let title: String
    let size: CGFloat
    let radius: CGFloat
    
    var body: some View {
        // AsyncImage with .placeholder → InitialsTile fallback
        // Initials computed via Brand.coverFallback(for: title)
    }
}
```

`CoverArtwork(urlString: podcast.artworkURL, title: podcast.title, size: 44, radius: 4)` replaces the current artwork-rendering blocks in `PodcastRowView`, `PodcastDetailView`, `MiniPlayerBar`, `FullScreenPlayerView`, `SearchResultRow`.

### Now-playing helpers

Three small view files compose the now-playing treatment:

**`Vibecast/Vibecast/Views/NowPlayingIndicator.swift`** — the 3-bar VU element. 3 thin vertical bars, phase-staggered 0.6-0.95s ease-in-out alternating heights. Color parameter (defaults to `Brand.Color.accent`). When `isPlaying = false`, freezes at current heights. **In Phase 1 it lives inside the now-playing row's left-slot 20×20 accent circle** (paper-tinted bars on accent background), not as a badge on the cover. The component is small enough (~14×14pt) to drop into the circle directly.

**`Vibecast/Vibecast/Views/RowSliver.swift`** — a 3pt-wide vertical bar at row leading edge. Single property: `color: Color`. Only rendered for `unplayed` rows in `PodcastRowView`. Phase 1 callers pass `Brand.fallbackColor(for: podcast.title)` (the deterministic per-show palette pick from Task 1's `Brand.fallbackColor`).

**`Vibecast/Vibecast/Views/NowPlayingCard.swift`** — a `ViewModifier` that adds the 2pt accent border + halo shadow + 3pt top progress bar to whatever row content is inside. Inputs: `progressFraction: Double`, `isPlaying: Bool`. Output: a card with `.overlay` shadow, `.shadow(color: accent.opacity(0.20), radius: 24, y: 8)`, and a top-edge progress overlay. The card uses `.clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))` so the top progress bar respects the row's rounded corners. Used as `.modifier(NowPlayingCard(progressFraction: ..., isPlaying: ...))` on the now-playing row's content.

## Verification

This is a visual refresh — there are no behavioral assertions for unit tests to make. Existing tests (101 at the start of Plan 6 view migrations — 90 baseline + 11 BrandTests added in Task 1 cleanup) should continue passing.

**Manual verification on real device:**

1. Library: Fraunces "Vibecast" wordmark renders correctly with accent dot. Paper bg. Empty state styled.
2. Subscribe to a few podcasts; rows show correct typography, 44×44 covers with initials fallback (or real artwork). Position numbers visible on the leading edge.
3. **Unplayed rows** show the left-edge sliver in a per-show fallback color (chromatic column down the list). Title in Fraunces 500 roman.
4. **Played rows** dim to 0.55 opacity with `✓ PLAYED` footnote.
5. **Started rows** (mark a podcast started by playing for a few seconds then switching): no left sliver; position number dimmed to 30%; title in Fraunces 300 italic at 78% ink; footnote shows `PAUSED AT N M · TOTAL MIN TOTAL`; eyebrow has the small inline progress ring + `M LEFT`.
6. **Now-playing row** has the 2pt accent border + halo + 3pt top progress bar across the row card; left slot shows 20×20 accent circle with 3-bar VU; right control is accent-filled. Pause it: the bar animation freezes, glyph swaps to 2 white pause bars in the circle, right control's pause swaps to play.
7. Fixed row height: long titles wrap to 2 lines, short titles still occupy the same row height with breathing room.
8. Open podcast detail: Fraunces 28pt title, mono publisher eyebrow, episode list with the same four-state vocabulary as the library list (no left sliver in the detail view).
9. Open Now Playing (full-screen): cover at 280, Fraunces title, accent-filled primary play button at 70×70.
10. Mini player: paper bg, accent progress sliver, transport buttons at correct sizes.
11. Open Search: subscribe states render correctly, in-flight spinner uses accent.
12. Light-mode test: switch device to dark mode → app should still render in light editorial palette.
13. Font test: rotate device, change Dynamic Type size — verify no layout breakage.

**No automated visual regression tests** — too brittle for this scope. Re-run the existing 101-test suite (or whatever the Plan 6 final count is — adding helpers may grow it) to confirm no behavioral regressions.

## Migration & commit strategy

One branch (`feature/plan-6-visual-refresh`). Sequenced commits:

1. **Foundation** — bundle Fraunces (roman + italic), Inter, JetBrains Mono TTFs, register in Info.plist, write `Brand.swift` with all token constants and the new `serifBodyLight` / `serifLightItalic` font roles.
2. **Helper views** — `CoverArtwork`, `NowPlayingIndicator`, **`RowSliver`**, **`NowPlayingCard` ViewModifier**. New view files, not yet wired into existing screens.
3. **Per-screen migrations** — one commit per view file, bottom-up so each migration's dependencies are already refreshed: `PlayControlView` → `PodcastRowView` → `EpisodeRowView` → `PodcastDetailView` → `SearchResultRow` → `AddPodcastSheet` → `MiniPlayerBar` → `FullScreenPlayerView` → `SubscriptionsListView`. The list view is last because it's the visible parent that integrates the wordmark and the new row vocabulary.
4. **App-root finishing** — `.preferredColorScheme(.light)` + any remaining loose ends.
5. **Manual verification on device** — gate before merge.

Each per-screen commit independently builds + passes existing tests. Branch ships as a unit so the user never sees a half-refreshed app.

## Open questions

None at design-spec time. Implementation will surface a few oklch → sRGB conversions and font-metric tuning calls that the implementer makes per spec values.
