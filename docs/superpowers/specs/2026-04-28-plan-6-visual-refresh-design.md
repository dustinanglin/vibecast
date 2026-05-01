# Plan 6: Visual Refresh Design Spec

## Goal

Translate the locked Editorial direction from the design handoff into the existing Vibecast app — paper-warm surface, ink text, Fraunces + Inter + JetBrains Mono type pairing, refined row vocabulary — without introducing any data model changes. Phase 1 of the three-phase iterative adoption from the design handoff.

## Background

The current app is functional but stylistically generic — system fonts, dark mode, blue accent, `mic.fill` artwork fallback. The Claude Design handoff (committed at `docs/design/vibecast-visual-prototypes/`) locked Direction B (Editorial) after a comparative study of three visual directions, then layered on a vibes/pinning model that's explicitly Phase 2/3 territory.

This plan delivers Phase 1 only: visual tokens + screen refresh + library wordmark. Net-new screens (vibe filter, pin sheet, etc.), data model changes (Vibe entity, QueueItem), and queue-dependent row vocabulary (position numbers, UP NEXT pills, tinted card backgrounds) are all out of scope.

## Scope

### In scope

- Bundle Fraunces, Inter, JetBrains Mono TTF files; register via `UIAppFonts`; expose typed `Font` API.
- Define color tokens in code (no Asset Catalog Color Sets needed for light-only).
- Force light mode via `.preferredColorScheme(.light)` at app root.
- Library header: replace `.navigationTitle("Subscriptions")` with custom Fraunces "Vibecast" wordmark + accent dot.
- Row visual refresh: all 8 view files (`SubscriptionsListView`, `PodcastRowView`, `PlayControlView`, `PodcastDetailView`, `EpisodeRowView`, `SearchResultRow`, `AddPodcastSheet`, `MiniPlayerBar`, `FullScreenPlayerView`).
- Played-state treatment: opacity 0.55 + `✓ PLAYED` mono text replacing duration on row.
- Currently-playing indicator: 3-bar animated VU on the row that's playing.
- Cover artwork fallback: serif-initials on a colored square (replaces `mic.fill` in `PodcastRowView` and detail view).
- Hairline separators replacing system list dividers.

### Out of scope (explicit)

- Vibes (data model, screens, filter pills) — Plan 7.
- Pinning (data model, sheet, expiration) — Plan 8.
- Position numbers, UP NEXT/NOW pills, tinted card backgrounds, multi-vibe gradients — all queue-dependent, ship with Plan 7.
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
| `serifBody` | Fraunces | 500 | 14pt | normal | — | Episode title in row |
| `serifItalic` | Fraunces | 500 | 19pt (default) | normal | italic | Lede captions, editorial flavor text (sparingly used in Phase 1) |
| `uiBody` | Inter | 400 | 14pt (default) | normal | — | Body UI text, search input |
| `uiButtonLabel` | Inter | 600 | 14pt | -0.005em | — | Button labels |
| `monoEyebrow` | JetBrains Mono | 600 | 9pt (rows) / 11pt (section eyebrows) | +0.10em | uppercase | Show name eyebrow, durations, listening progress, played-state text |

Italic Fraunces is rarely used in Phase 1 — the design handoff uses it for editorial flavor in the marketing-style surfaces. Library + row + detail screens stay roman.

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

```
┌───────────────────────────────────────────────────┐  ← cardRadius 14pt
│ ┌─────┐                                           │
│ │ Cov │   SHOW NAME · 9pt MONO · ink/0.62         │  ← row inner padding 12pt
│ │ 44  │                                           │
│ │ ×44 │   Episode Title (Fraunces 14pt 500)       │
│ │ 4pt │                                           │
│ └─────┘   62 MIN · 24M IN  (mono 9pt ink/0.40)    │
│                                                   │
│                                       ┌──────┐    │
│                                       │  ▶/⏸  │   │  ← right control,
│                                       └──────┘    │     56pt hit target
└───────────────────────────────────────────────────┘
        ↓ 8pt gap to next row
─────────────────────────────────────────────────────  ← 1pt hairline ink/0.10
```

States:
- **Default** — paper bg, ink text, accent dot in cover fallback if no artwork.
- **Currently playing** — 3-bar animated VU indicator (~14×14pt) drawn as a top-right badge on the cover (small inset, accent color), right control shows pause icon in accent-filled circle. Bar heights animate independently 0.6-0.95s ease-in-out alternate. When the player is paused but this is the loaded episode, freeze the bar heights.
- **Played** — entire row at opacity 0.55, duration text replaced with `✓ PLAYED` (mono 9pt, ink/0.40), right control shows replay glyph (transparent, muted).
- **No latest episode** — fallback "No episodes" italic text where the title would be.

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

Re-styled to match the episode-row vocabulary in `PodcastDetailView`. Uses same date/title/duration layout.

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
  - `Fraunces[opsz,wght].ttf` (variable, opsz 9-144, wght 100-900)
  - `Inter[wght].ttf` (variable, wght 100-900)
  - `JetBrainsMono[wght].ttf` (variable, wght 100-800)
- `Info.plist` `UIAppFonts` array adds the three filenames.

Bundle size impact: ~1.5 MB total (variable fonts include all weights).

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

### Now-playing VU indicator

New tiny view `Vibecast/Vibecast/Views/NowPlayingIndicator.swift`. 3 thin vertical bars, randomized 0.6-0.95s ease-in-out alternating heights via `withAnimation`. Tinted `accent`. Visible only when this row's episode is currently playing AND the player is in `isPlaying = true` state. When player is paused, freeze the bars at their current heights (visual hint that this is the loaded episode).

## Verification

This is a visual refresh — there are no behavioral assertions for unit tests to make. Existing tests should continue passing (84 baseline).

**Manual verification on real device:**

1. Library: Fraunces "Vibecast" wordmark renders correctly with accent dot. Paper bg. Empty state styled.
2. Subscribe to a few podcasts; rows show correct typography, 44×44 covers with initials fallback (or real artwork). Played episode rows are dimmed with `✓ PLAYED`.
3. Currently-playing row shows VU bars; right control shows pause icon when playing.
4. Open podcast detail: Fraunces 28pt title, mono publisher eyebrow, episode list styled correctly.
5. Open Now Playing (full-screen): cover at 280, Fraunces title, accent-filled primary play button at 70×70.
6. Mini player: paper bg, accent progress sliver, transport buttons at correct sizes.
7. Open Search: subscribe states render correctly, in-flight spinner uses accent.
8. Light-mode test: switch device to dark mode → app should still render in light editorial palette (no dark variant).
9. Font test: rotate device, change Dynamic Type size — verify no layout breakage.

**No automated visual regression tests** — too brittle for this scope. Re-run the existing 84-test suite to confirm no behavioral regressions.

## Migration & commit strategy

One branch (`feature/plan-6-visual-refresh`). Sequenced commits:

1. **Foundation** — bundle TTFs, register in Info.plist, write `Brand.swift` (constants only, not yet used).
2. **CoverArtwork + NowPlayingIndicator helpers** — new view files, not yet wired into existing screens.
3. **Per-screen migrations** — one commit per view file, bottom-up so each migration's dependencies are already refreshed: `PlayControlView` → `PodcastRowView` → `EpisodeRowView` → `PodcastDetailView` → `SearchResultRow` → `AddPodcastSheet` → `MiniPlayerBar` → `FullScreenPlayerView` → `SubscriptionsListView`. The list view is last because it's the visible parent that integrates the wordmark and the new row vocabulary.
4. **App-root finishing** — `.preferredColorScheme(.light)` + any remaining loose ends.
5. **Manual verification on device** — gate before merge.

Each per-screen commit independently builds + passes existing tests. Branch ships as a unit so the user never sees a half-refreshed app.

## Open questions

None at design-spec time. Implementation will surface a few oklch → sRGB conversions and font-metric tuning calls that the implementer makes per spec values.

## Deferred to later plans

**Plan 8 (Pinning) revises the podcast detail page beyond Plan 6's scope.**
Plan 6's detail-page work is purely a typography/palette refresh — same hero,
same episode list, same affordances, just brought into the editorial language.

The richer detail layout in `docs/design/vibecast-visual-prototypes/project/Vibecast Podcast & Pinning.html`
(vibe membership chips, Play / Pin / Subscribed action triad, pin-to-vibe
action sheet, pinned-episode pill states with expiry-on-play, queue position
chrome, the "on a plane" pinning use case) lands with Plan 8. When Plan 8
brainstorming begins, treat that design file as a primary source.
