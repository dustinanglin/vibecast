# Plan 6: Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Translate the locked Editorial direction from the design handoff into Vibecast — paper-warm surface, ink text, Fraunces + Inter + JetBrains Mono type pairing, refined row vocabulary, library wordmark, currently-playing indicator, played-state treatment, serif-initials cover artwork fallback. Phase 1 of the design handoff's three-phase iterative adoption. No data model changes; vibes/pinning explicitly deferred to Plans 7/8.

**Architecture:** All visual tokens centralized in `Brand.swift` as static constants (no env keys). TTF fonts bundled in `Resources/Fonts/`, registered via `UIAppFonts`. `CoverArtwork` and `NowPlayingIndicator` as small helper views shared across screens. Light mode forced at app root.

**Tech Stack:** SwiftUI, custom `Font` registration, sRGB hex `Color` constants, no third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-04-28-plan-6-visual-refresh-design.md` (commit `61f44ff`).

**Current baseline:** 90 tests passing on `iPhone 17 Pro` simulator.

**Visual verification model:** Each task confirms (a) build still passes and (b) full test suite still green. No automated visual regression — manual device verification at end of branch (Task 13).

---

## Task 1: Foundation — bundle fonts, register, write `Brand.swift`

**Why this task:** Every subsequent task references either a `Brand.Color.*`, `Brand.Font.*`, `Brand.Layout.*`, or `Brand.Radius.*` value. The fonts must be registered before any view can use them. Landing this in one commit means the foundation is verifiable in isolation (Brand constants compile, fonts register, baseline test suite still passes — no visual change yet because no view consumes the tokens).

**Files:**
- Add: `Vibecast/Vibecast/Resources/Fonts/Fraunces[opsz,wght].ttf` (variable font)
- Add: `Vibecast/Vibecast/Resources/Fonts/InterVariable.ttf` (variable font)
- Add: `Vibecast/Vibecast/Resources/Fonts/JetBrainsMono[wght].ttf` (variable font)
- Modify: `Vibecast/Info.plist` (add `UIAppFonts` array)
- Add: `Vibecast/Vibecast/Brand/Brand.swift`

- [ ] **Step 1.1: Download the three variable font TTFs**

The fonts are SIL Open Font License (OFL). Download the variable versions from the canonical font-author repos (these URLs are stable as of 2026):

```bash
mkdir -p /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast/Resources/Fonts

cd /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast/Resources/Fonts

# Fraunces variable (opsz + wght axes)
curl -sL -o "Fraunces[opsz,wght].ttf" \
  "https://github.com/undercase/fraunces/raw/main/fonts/variable/Fraunces%5Bopsz%2Cwght%5D.ttf"

# Inter variable (single weight axis)
curl -sL -o "InterVariable.ttf" \
  "https://github.com/rsms/inter/raw/master/docs/font-files/InterVariable.ttf"

# JetBrains Mono variable (single weight axis)
curl -sL -o "JetBrainsMono[wght].ttf" \
  "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/variable/JetBrainsMono%5Bwght%5D.ttf"

# Verify all three exist and are non-trivial size
ls -lh
```

Expected output: three TTF files, each between 200KB and 1MB. If any URL 404s, search Google Fonts (`fonts.google.com/specimen/Fraunces`, etc.) for the current download URL and adapt. Variable-font filenames may include additional axes (e.g., `Fraunces[SOFT,WONK,opsz,wght].ttf`); rename to a stable canonical filename before placing in the project.

- [ ] **Step 1.2: Register fonts in `Info.plist`**

Open `Vibecast/Info.plist`. Add a `UIAppFonts` array entry:

```xml
<key>UIAppFonts</key>
<array>
    <string>Resources/Fonts/Fraunces[opsz,wght].ttf</string>
    <string>Resources/Fonts/InterVariable.ttf</string>
    <string>Resources/Fonts/JetBrainsMono[wght].ttf</string>
</array>
```

Place it alphabetically among the existing `U*` keys (between `UIApplicationSupportsIndirectInputEvents` and `UIBackgroundModes` makes sense).

The font files live in `Vibecast/Vibecast/Resources/Fonts/` but the bundle path resolves to `Resources/Fonts/...` because the Resources directory is auto-discovered by `PBXFileSystemSynchronizedRootGroup` and flattens at the bundle root.

**However**, `PBXFileSystemSynchronizedRootGroup` may treat `.ttf` files as build resources (copy phase) rather than auto-discoverable assets. If `UIFont.familyNames` doesn't list "Fraunces" / "Inter" / "JetBrains Mono" after launching, fall back to inspecting the built bundle (`ls /tmp/.../Vibecast.app/`) and adjusting the `Info.plist` entries to use the file names without the `Resources/Fonts/` prefix.

- [ ] **Step 1.3: Create `Vibecast/Vibecast/Brand/Brand.swift`**

Make the directory and file:

```bash
mkdir -p /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast/Brand
```

Then create `Vibecast/Vibecast/Brand/Brand.swift`:

```swift
import SwiftUI

/// Visual tokens for Vibecast's editorial style. Static constants only —
/// no env keys, no observation. See spec: 2026-04-28-plan-6-visual-refresh-design.md.
enum Brand {

    // MARK: - Colors

    enum Color {
        static let bg          = SwiftUI.Color(red: 0xF4 / 255.0, green: 0xEF / 255.0, blue: 0xE6 / 255.0)
        static let paper       = SwiftUI.Color(red: 0xFB / 255.0, green: 0xF7 / 255.0, blue: 0xEE / 255.0)
        static let paperDeep   = SwiftUI.Color(red: 0xEF / 255.0, green: 0xE9 / 255.0, blue: 0xDD / 255.0)
        static let ink         = SwiftUI.Color(red: 0x1A / 255.0, green: 0x17 / 255.0, blue: 0x14 / 255.0)
        static let inkSecondary = ink.opacity(0.62)
        static let inkMuted    = ink.opacity(0.40)
        static let inkFaint    = ink.opacity(0.22)
        static let inkHairline = ink.opacity(0.10)

        /// Phase 1 accent. oklch(0.62 0.13 200) ≈ teal. Becomes vibe-tinted in Plan 7.
        /// Implementer: replace the rgb values below with the precise oklch → sRGB
        /// conversion from a reference converter (oklch.com or equivalent).
        static let accent = SwiftUI.Color(red: 0x2E / 255.0, green: 0x94 / 255.0, blue: 0xA8 / 255.0)
    }

    // MARK: - Fonts

    enum Font {
        // Family names match what UIFont.familyNames returns after registration.
        // Verify with `print(UIFont.familyNames.filter { $0.contains("Fraunces") })`
        // if needed.
        private static let fraunces = "Fraunces"
        private static let inter = "Inter"
        private static let mono = "JetBrains Mono"

        /// Library header wordmark. Fraunces 500, 28pt, tracking -0.025em.
        static func display(size: CGFloat = 28) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        /// Detail view podcast title, large screen titles.
        static func serifTitle(size: CGFloat = 28) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        /// Section headers (h3).
        static func serifSubtitle(size: CGFloat = 22) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        /// Episode title in row.
        static func serifBody(size: CGFloat = 14) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        /// Lede captions, editorial flavor text.
        static func serifItalic(size: CGFloat = 19) -> SwiftUI.Font {
            .custom("\(fraunces)-Italic", size: size).weight(.medium)
        }

        /// Body UI text, search input.
        static func uiBody(size: CGFloat = 14, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom(inter, size: size).weight(weight)
        }

        /// Button labels.
        static func uiButton(size: CGFloat = 14) -> SwiftUI.Font {
            .custom(inter, size: size).weight(.semibold)
        }

        /// Eyebrows, durations, listening progress, played-state text.
        /// Always rendered uppercase by the call site (`.textCase(.uppercase)`).
        static func monoEyebrow(size: CGFloat = 9) -> SwiftUI.Font {
            .custom(mono, size: size).weight(.semibold)
        }

        /// Larger mono for section eyebrows in detail view.
        static func monoEyebrowLarge(size: CGFloat = 11) -> SwiftUI.Font {
            .custom(mono, size: size).weight(.semibold)
        }
    }

    // MARK: - Layout

    enum Layout {
        static let rowPadding: CGFloat = 12
        static let rowGap: CGFloat = 8
        static let monoTracking: CGFloat = 0.9   // ≈ +0.10em at 9pt
        static let serifTracking: CGFloat = -0.35 // ≈ -0.025em at 14pt
    }

    // MARK: - Radius

    enum Radius {
        static let card: CGFloat = 14
        static let inline: CGFloat = 10
        static let pill: CGFloat = 999
        static let coverSmall: CGFloat = 4
        static let coverMedium: CGFloat = 6
        static let coverLarge: CGFloat = 8
    }

    // MARK: - Hit targets

    enum HitTarget {
        static let min: CGFloat = 38
        static let rowPlay: CGFloat = 56
        static let primaryPlay: CGFloat = 70
    }

    // MARK: - Hairline

    static let hairlineWidth: CGFloat = 1

    // MARK: - Cover artwork fallback palette

    /// Pre-defined palette for cover-fallback colored squares.
    /// Implementer: replace approximated hex values below with precise oklch → sRGB.
    enum FallbackPalette {
        static let colors: [SwiftUI.Color] = [
            Self.hex(0x6E3A1C), // rust       oklch(0.42 0.13 18)
            Self.hex(0x2A4F6E), // steel blue oklch(0.42 0.13 220)
            Self.hex(0x2C5A3D), // forest     oklch(0.42 0.13 145)
            Self.hex(0x4A3C6B), // plum       oklch(0.42 0.13 280)
            Self.hex(0x6E4A1C), // amber      oklch(0.42 0.13 38)
            Self.hex(0x1F546E), // teal       oklch(0.42 0.13 200)
            Self.hex(0x6E2E5A), // magenta    oklch(0.42 0.13 320)
            Self.hex(0x6E5A1C), // ochre      oklch(0.42 0.13 60)
        ]

        private static func hex(_ rgb: UInt32) -> SwiftUI.Color {
            SwiftUI.Color(
                red: Double((rgb >> 16) & 0xFF) / 255.0,
                green: Double((rgb >> 8) & 0xFF) / 255.0,
                blue: Double(rgb & 0xFF) / 255.0
            )
        }
    }

    // MARK: - Initials helper

    /// Computes 1-2 letter initials from a podcast title.
    /// Examples:
    ///   "Hard Fork" → "HF"
    ///   "The Daily" → "D"
    ///   "Radiolab" → "R"
    ///   "99% Invisible" → "9I"
    static func initials(for title: String) -> String {
        let stopWords: Set<String> = ["the", "a", "an", "of", "and", "with", "&"]
        let words = title
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).lowercased() }
            .filter { !$0.isEmpty && !stopWords.contains($0) }

        guard let first = words.first?.first.map(String.init)?.uppercased() else {
            return "?"
        }

        if words.count >= 2, let last = words.last?.first.map(String.init)?.uppercased() {
            return first + last
        }
        return first
    }

    /// Stable color from the FallbackPalette for a podcast title.
    /// Uses djb2 hash for cross-launch stability (Swift's String.hashValue is per-process seeded).
    static func fallbackColor(for title: String) -> SwiftUI.Color {
        var hash: UInt64 = 5381
        for byte in title.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(FallbackPalette.colors.count))
        return FallbackPalette.colors[index]
    }
}
```

- [ ] **Step 1.4: Build to verify font registration + Brand.swift compiles**

Run from worktree:

```bash
xcodebuild build -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

Expected: `** BUILD SUCCEEDED **`. If a font reference fails compile, the family name in `Brand.Font` doesn't match the TTF's internal name. Verify by:

```bash
# After a successful build, inspect the bundle
ls /tmp/vibecast-plan6-build/Build/Products/Debug-iphonesimulator/Vibecast.app/Resources/Fonts/ 2>/dev/null
# OR the simulator-installed app
```

Or temporarily print `UIFont.familyNames` from a SwiftUI Preview and adjust `private static let fraunces = "..."` etc. accordingly. (Common gotcha: PostScript name ≠ family name.)

- [ ] **Step 1.5: Run full test suite — expect 90 tests still passing**

```bash
xcodebuild test -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|Executed [0-9]+ tests" | tail -3
```

Expected: `** TEST SUCCEEDED **`. No new tests yet; this just confirms the foundation didn't break the existing 90.

- [ ] **Step 1.6: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Resources/Fonts Vibecast/Vibecast/Brand Vibecast/Info.plist Vibecast/Vibecast.xcodeproj/project.pbxproj
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat: bundle Fraunces/Inter/JetBrains Mono and add Brand token surface

Plan 6 foundation. Three variable TTFs in Resources/Fonts/, registered
via Info.plist UIAppFonts. Brand enum exposes Color, Font, Layout,
Radius, HitTarget, FallbackPalette tokens plus initials() and
fallbackColor() helpers for the cover artwork fallback. No view yet
consumes these — verifying foundation in isolation."
```

---

## Task 2: `CoverArtwork` helper view

**Why this task:** Replaces every ad-hoc `AsyncImage { ... } placeholder { mic.fill }` block in the codebase with a single component. Renders the artwork URL when available, falls back to colored square + serif initials when nil/failed. Used by 5 view files later.

**Files:**
- Add: `Vibecast/Vibecast/Views/CoverArtwork.swift`

- [ ] **Step 2.1: Create `CoverArtwork.swift`**

```swift
import SwiftUI

/// Renders a podcast's cover artwork. Falls back to colored square with
/// serif initials when the URL is missing or fails to load.
struct CoverArtwork: View {
    let urlString: String?
    let title: String
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        InitialsTile(title: title, size: size, radius: radius)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        InitialsTile(title: title, size: size, radius: radius)
                    @unknown default:
                        InitialsTile(title: title, size: size, radius: radius)
                    }
                }
            } else {
                InitialsTile(title: title, size: size, radius: radius)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

private struct InitialsTile: View {
    let title: String
    let size: CGFloat
    let radius: CGFloat

    /// Initial size scales: 16pt at 44, 38pt at 120, 80pt at 280.
    private var initialFontSize: CGFloat { size * 0.36 }

    var body: some View {
        ZStack {
            Brand.fallbackColor(for: title)
            Text(Brand.initials(for: title))
                .font(Brand.Font.serifTitle(size: initialFontSize))
                .foregroundStyle(Brand.Color.paper)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

#Preview {
    VStack(spacing: 16) {
        CoverArtwork(urlString: nil, title: "Hard Fork", size: 44, radius: 4)
        CoverArtwork(urlString: nil, title: "The Daily", size: 120, radius: 6)
        CoverArtwork(urlString: nil, title: "99% Invisible", size: 280, radius: 8)
    }
    .padding()
    .background(Brand.Color.bg)
}
```

- [ ] **Step 2.2: Build — expect green**

```bash
xcodebuild build -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -5
```

- [ ] **Step 2.3: Run tests — expect 90 passing**

```bash
xcodebuild test -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED" | tail -3
```

- [ ] **Step 2.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/CoverArtwork.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat: CoverArtwork view with serif-initials fallback

Wraps AsyncImage with a colored-square + serif-initials fallback when
the URL is nil or fails to load. Uses Brand.initials() and
Brand.fallbackColor() helpers. Replaces ad-hoc mic.fill placeholders
across 5 call sites in subsequent tasks."
```

---

## Task 3: `NowPlayingIndicator` helper view

**Why this task:** Visual signal that this row is currently loaded in the player. 3-bar VU animation when `isPlaying`, frozen bars when paused. Used in `PodcastRowView` (and possibly `EpisodeRowView`).

**Files:**
- Add: `Vibecast/Vibecast/Views/NowPlayingIndicator.swift`

- [ ] **Step 3.1: Create `NowPlayingIndicator.swift`**

```swift
import SwiftUI

/// 3-bar animated VU indicator. Animates while `isPlaying`; freezes
/// otherwise. Visible only when this row's episode is currently loaded
/// in the player.
struct NowPlayingIndicator: View {
    let isPlaying: Bool
    var color: Color = Brand.Color.accent

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            Bar(isPlaying: isPlaying, durationSeconds: 0.62, phase: 0)
            Bar(isPlaying: isPlaying, durationSeconds: 0.78, phase: 0.18)
            Bar(isPlaying: isPlaying, durationSeconds: 0.94, phase: 0.32)
        }
        .frame(width: 14, height: 14)
        .padding(2)
    }

    private struct Bar: View {
        let isPlaying: Bool
        let durationSeconds: Double
        let phase: Double

        @State private var atTop = false

        var body: some View {
            RoundedRectangle(cornerRadius: 1)
                .fill(Brand.Color.accent)
                .frame(width: 2.5, height: atTop ? 12 : 4)
                .animation(
                    isPlaying
                        ? .easeInOut(duration: durationSeconds)
                            .repeatForever(autoreverses: true)
                            .delay(phase)
                        : .default,
                    value: atTop
                )
                .onAppear { if isPlaying { atTop.toggle() } }
                .onChange(of: isPlaying) { _, newValue in
                    if newValue { atTop.toggle() }
                    // Freezes at current height when paused (no further toggle).
                }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        NowPlayingIndicator(isPlaying: true)
        NowPlayingIndicator(isPlaying: false)
    }
    .padding()
    .background(Brand.Color.bg)
}
```

- [ ] **Step 3.2: Build + test**

```bash
xcodebuild test -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED" | tail -3
```

- [ ] **Step 3.3: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/NowPlayingIndicator.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat: NowPlayingIndicator 3-bar VU animation

Tiny indicator for the row that's currently loaded in the player. Bars
animate with phase-shifted ease-in-out while isPlaying; freeze in place
when paused. Tinted with Brand.Color.accent."
```

---

## Task 3.5: Backfill — Fraunces italic + RowSliver + NowPlayingCard

**Why this task:** A row-state iteration design pass after Tasks 1-3 landed introduced new vocabulary (started state, left-edge sliver attractor, now-playing card decoration with border + halo + top progress bar). Three additions needed before the per-screen migrations consume them in Task 5: (a) bundle the italic Fraunces variable so `Brand.Font.serifLightItalic` actually resolves; (b) `RowSliver` view for the unplayed attractor; (c) `NowPlayingCard` ViewModifier for the active-row card framing. Spec at `docs/superpowers/specs/2026-04-28-plan-6-visual-refresh-design.md` (commit `3e33a01` on main — read on main, not the worktree).

**Files:**
- Add: `Vibecast/Vibecast/Resources/Fonts/Fraunces-Italic[opsz,wght].ttf`
- Modify: `Vibecast/Info.plist` (add italic to `UIAppFonts`)
- Modify: `Vibecast/Vibecast/Brand/Brand.swift` (add `serifBodyLight` + `serifLightItalic`)
- Add: `Vibecast/Vibecast/Views/RowSliver.swift`
- Add: `Vibecast/Vibecast/Views/NowPlayingCard.swift`

- [ ] **Step 3.5.1: Download the italic Fraunces variable**

```bash
cd /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast/Resources/Fonts

curl -sL -o "Fraunces-Italic[opsz,wght].ttf" \
  "https://github.com/undercase/fraunces/raw/main/fonts/variable/Fraunces-Italic%5Bopsz%2Cwght%5D.ttf"

ls -lh "Fraunces-Italic[opsz,wght].ttf"
```

Expected: a TTF ~300-400KB. If the URL 404s, search Google Fonts (`fonts.google.com/specimen/Fraunces`) and grab the italic variant.

- [ ] **Step 3.5.2: Register italic in Info.plist**

Open `Vibecast/Info.plist`. Find the existing `UIAppFonts` array (set in Task 1) and add a fourth entry — bare filename per Task 1's discovered pattern:

```xml
<string>Fraunces-Italic[opsz,wght].ttf</string>
```

Place it next to the existing `Fraunces[opsz,wght].ttf` line.

- [ ] **Step 3.5.3: Extend `Brand.Font` with light + light-italic roles**

Open `Vibecast/Vibecast/Brand/Brand.swift`. In the `enum Font` block, add two new private static-let identifiers and two new static funcs. Family-name string for the italic — match what `UIFont.familyNames` returns; typically the italic registers under the same family `"Fraunces"` and is selected via the italic attribute. If `.custom("Fraunces", size:).italic()` doesn't engage the bundled italic file, try `"Fraunces-Italic"` as a separate family name.

```swift
enum Font {
    private static let fraunces = "Fraunces"
    private static let fraunces_italic = "Fraunces-Italic"  // adjust if the italic registers under "Fraunces"
    private static let inter = "Inter"
    private static let mono = "JetBrains Mono"

    // ... existing static funcs unchanged ...

    /// Started-row title: Fraunces 300 (Light), upright. Pairs with serifLightItalic
    /// for the started state per spec § PodcastRowView.
    static func serifBodyLight(size: CGFloat = 14) -> SwiftUI.Font {
        .custom(fraunces, size: size).weight(.light)
    }

    /// Started-row title: Fraunces-Italic 300, italic. The carrier of the
    /// "still here, not done" treatment per spec.
    static func serifLightItalic(size: CGFloat = 14) -> SwiftUI.Font {
        .custom(fraunces_italic, size: size).weight(.light)
    }
}
```

The variable Fraunces font's `wght` axis covers 100-900, so `.weight(.light)` (300) should drive the axis correctly. If the italic ships under family `"Fraunces"` (single family, italic-axis-flagged) rather than separate `"Fraunces-Italic"` family, adjust accordingly. The variable-font weight engagement caveat from Task 1 applies — verify on device at Task 13 manual verification.

- [ ] **Step 3.5.4: Create `Vibecast/Vibecast/Views/RowSliver.swift`**

```swift
import SwiftUI

/// A 3pt-wide vertical bar drawn at the leading edge of an unplayed row.
/// Color in Phase 1 = Brand.fallbackColor(for: podcast.title) — per-show
/// deterministic; produces a chromatic column down the library list.
/// In Plan 7 (Vibes), color becomes the show's primary vibe color.
struct RowSliver: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 3)
    }
}

#Preview {
    HStack(spacing: 0) {
        RowSliver(color: Brand.fallbackColor(for: "Hard Fork"))
        Rectangle().fill(Brand.Color.paper).frame(height: 76).overlay(Text("row content").foregroundStyle(Brand.Color.ink))
    }
    .frame(height: 76)
    .background(Brand.Color.bg)
}
```

- [ ] **Step 3.5.5: Create `Vibecast/Vibecast/Views/NowPlayingCard.swift`**

```swift
import SwiftUI

/// ViewModifier that wraps row content with the now-playing card decoration:
/// 2pt accent border, halo shadow, 3pt top progress bar across the row's
/// inner top edge. Used on the now-playing row in PodcastRowView (and later
/// EpisodeRowView). Inputs:
///   - progressFraction: 0...1 of how far through the episode we are
///   - isPlaying: drives whether the halo glows; both playing and paused
///     keep the card decoration (the design says "lifts off the list" for
///     either state — only glyphs swap)
struct NowPlayingCard: ViewModifier {
    let progressFraction: Double
    let isPlaying: Bool

    func body(content: Content) -> some View {
        content
            .background(Brand.Color.paper)
            .overlay(alignment: .top) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Brand.Color.ink.opacity(0.08))
                        .frame(height: 3)
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Brand.Color.accent)
                            .frame(width: max(0, min(geo.size.width * progressFraction, geo.size.width)), height: 3)
                    }
                    .frame(height: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .strokeBorder(Brand.Color.accent, lineWidth: 2)
            }
            .shadow(color: Brand.Color.accent.opacity(0.20), radius: 24, y: 8)
    }
}

extension View {
    func nowPlayingCard(progressFraction: Double, isPlaying: Bool) -> some View {
        modifier(NowPlayingCard(progressFraction: progressFraction, isPlaying: isPlaying))
    }
}

#Preview {
    VStack(spacing: 16) {
        Text("Now playing row content")
            .padding()
            .frame(maxWidth: .infinity)
            .nowPlayingCard(progressFraction: 0.4, isPlaying: true)
        Text("Inactive row")
            .padding()
            .frame(maxWidth: .infinity)
            .background(Brand.Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Brand.Radius.card).strokeBorder(Brand.Color.inkHairline, lineWidth: 1))
    }
    .padding()
    .background(Brand.Color.bg)
}
```

- [ ] **Step 3.5.6: Build + test — expect 101 passing**

```bash
xcodebuild test -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED|Executed [0-9]+ tests|error:" | tail -5
```

- [ ] **Step 3.5.7: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Resources/Fonts Vibecast/Info.plist Vibecast/Vibecast/Brand/Brand.swift Vibecast/Vibecast/Views/RowSliver.swift Vibecast/Vibecast/Views/NowPlayingCard.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat: bundle Fraunces italic, add RowSliver + NowPlayingCard helpers

Backfill for the row-state iteration design pass that landed after
Tasks 1-3. Three additions needed before the per-screen migrations
consume them in Task 5:

(1) Bundle Fraunces-Italic[opsz,wght].ttf alongside the roman variable
    file so .custom('Fraunces-Italic', ...) resolves. Add to Info.plist
    UIAppFonts. Add Brand.Font.serifBodyLight (Fraunces 300 upright)
    and Brand.Font.serifLightItalic (Fraunces 300 italic) for the
    started-row title treatment.

(2) RowSliver — 3pt vertical bar at row leading edge. Color is passed
    in (Phase 1: Brand.fallbackColor(for: title) for chromatic column).

(3) NowPlayingCard ViewModifier — wraps row content with 2pt accent
    border + accent-tinted halo shadow + 3pt top progress bar pinned
    flush to the rounded card's inner top edge. Used on the now-playing
    row in PodcastRowView."
```

---

## Task 4: Refresh `PlayControlView`

**Why this task:** The right-side button on every row. 4 visual states per spec.

**Files:**
- Modify: `Vibecast/Vibecast/Views/PlayControlView.swift`

- [ ] **Step 4.1: Read the current file end-to-end**

```bash
cat /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast/Views/PlayControlView.swift
```

Note the current state-derivation logic (`iconName`, `accessibilityLabel`) — preserve it; only restyle the visual layer.

- [ ] **Step 4.2: Apply visual refresh**

Replace the body's button styling. Keep all existing state-derivation logic (especially the accessibility labels added in Plan 5 Task 10). The new look:

```swift
import SwiftUI

struct PlayControlView: View {
    let episode: EpisodeRowSnapshot
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(playButtonAccessibilityLabel)
    }

    @ViewBuilder
    private var background: some View {
        let circleSize: CGFloat = 30
        if isCurrent {
            Circle()
                .fill(Brand.Color.accent)
                .frame(width: circleSize, height: circleSize)
        } else if episode.listenedStatus == .played {
            Circle()
                .fill(Color.clear)
                .frame(width: circleSize, height: circleSize)
        } else {
            Circle()
                .fill(Brand.Color.paper)
                .frame(width: circleSize, height: circleSize)
                .overlay(Circle().stroke(Brand.Color.inkHairline, lineWidth: Brand.hairlineWidth))
        }
    }

    private var iconName: String {
        if isCurrent && isPlaying { return "pause.fill" }
        if isCurrent && !isPlaying { return "play.fill" }
        if episode.listenedStatus == .played { return "arrow.clockwise" }
        return "play.fill"
    }

    private var iconColor: Color {
        if isCurrent { return Brand.Color.paper }
        if episode.listenedStatus == .played { return Brand.Color.inkMuted }
        return Brand.Color.ink
    }

    private var playButtonAccessibilityLabel: String {
        if isCurrent && isPlaying  { return "Pause \(episode.title)" }
        if isCurrent && !isPlaying { return "Resume \(episode.title)" }
        if episode.listenedStatus == .played { return "Replay \(episode.title)" }
        return "Play \(episode.title)"
    }
}

#Preview {
    VStack(spacing: 12) {
        // Add preview cases mirroring the existing #Preview if present.
    }
    .padding()
    .background(Brand.Color.paper)
}
```

Preserve the existing `#Preview` block's intent — adjust as needed if it referenced `SampleData` or specific test fixtures.

- [ ] **Step 4.3: Build + test — expect 90 passing**

```bash
xcodebuild test -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED" | tail -3
```

- [ ] **Step 4.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/PlayControlView.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh PlayControlView with Brand tokens

Four visual states: paper ring + ink play (default), accent-filled
circle + paper pause/play (current), transparent + muted replay (played).
56pt hit target. Accessibility labels from Plan 5 preserved."
```

---

## Task 5: Refresh `PodcastRowView` with the four-state vocabulary

**Why this task:** The most visible row in the app, and the centerpiece of Plan 6's visual refresh. Implements the four-state vocabulary from the row-state iteration design pass: **unplayed**, **started**, **now-playing**, **played**. Each state has its own typography, position-number opacity, sliver presence, eyebrow content, footnote, right-control treatment, and (for now-playing) card decoration. See spec § `PodcastRowView` for the full state matrix.

**Files:**
- Modify: `Vibecast/Vibecast/Views/PodcastRowView.swift` (substantial rewrite)
- Modify: `Vibecast/Vibecast/Views/PodcastRowSnapshot.swift` (add `position` field; extend `EpisodeRowSnapshot` with `playbackPosition`, `totalDuration`, and a `formattedElapsed` helper)
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift` (pass `position` when constructing each snapshot in the ForEach)

- [ ] **Step 5.1: Read all three files end-to-end**

Read:
- `Vibecast/Vibecast/Views/PodcastRowView.swift`
- `Vibecast/Vibecast/Views/PodcastRowSnapshot.swift` (or wherever `EpisodeRowSnapshot` lives)
- `Vibecast/Vibecast/Views/SubscriptionsListView.swift` (the ForEach that constructs snapshots)

Note current shapes — particularly what fields `EpisodeRowSnapshot` already has (`progressFraction`, `formattedDuration`, `formattedRemaining` per Plan 5 Task 1 cont.). Verify before adding duplicates.

- [ ] **Step 5.2: Extend snapshots with the missing fields**

`PodcastRowSnapshot`: add `let position: Int`. The init from `Podcast` sets `position = podcast.sortPosition + 1` (1-indexed for human-readable display).

`EpisodeRowSnapshot`: add `let playbackPosition: TimeInterval` and `let totalDuration: TimeInterval`. Add a computed `formattedElapsed: String` that formats `playbackPosition` like the existing `formattedDuration` — minutes only ("14M"). Update the init from `Episode`:

```swift
self.playbackPosition = episode.playbackPosition
self.totalDuration = TimeInterval(episode.durationSeconds)
```

If `progressFraction` exists, leave it. If not, add: `var progressFraction: Double { totalDuration > 0 ? min(playbackPosition / totalDuration, 1) : 0 }`.

- [ ] **Step 5.3: Replace `PodcastRowView` with four-state implementation**

```swift
import SwiftUI

struct PodcastRowView: View {
    let snapshot: PodcastRowSnapshot
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    let onPlay: () -> Void
    let onOpenDetail: () -> Void

    private enum RowState { case unplayed, started, nowPlaying, played }

    /// State precedence: now-playing wins; otherwise listenedStatus drives.
    private var rowState: RowState {
        if isCurrent { return .nowPlaying }
        guard let ep = snapshot.latestEpisode else { return .unplayed }
        switch ep.listenedStatus {
        case .unplayed:   return .unplayed
        case .inProgress: return .started
        case .played:     return .played
        }
    }

    var body: some View {
        cardWrapper
            .padding(.vertical, Brand.Layout.rowGap / 2)
            .opacity(rowState == .played ? 0.55 : 1.0)
    }

    /// Wraps the row content with the appropriate decoration:
    /// - now-playing → 2pt accent border + halo + top progress bar (NowPlayingCard)
    /// - unplayed → 3pt fallback-color sliver at leading edge + paper card + hairline border
    /// - started, played → paper card + hairline border (no sliver)
    @ViewBuilder
    private var cardWrapper: some View {
        switch rowState {
        case .nowPlaying:
            cardContent
                .nowPlayingCard(progressFraction: progressFraction, isPlaying: isPlaying)
        case .unplayed:
            HStack(spacing: 0) {
                RowSliver(color: Brand.fallbackColor(for: snapshot.title))
                cardContent
                    .frame(maxWidth: .infinity)
            }
            .background(Brand.Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
            )
        case .started, .played:
            cardContent
                .background(Brand.Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.card)
                        .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                )
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 12) {
            leftSlot
                .frame(width: 28)
            CoverArtwork(
                urlString: snapshot.artworkURL,
                title: snapshot.title,
                size: 44,
                radius: Brand.Radius.coverSmall
            )
            .onTapGesture { onOpenDetail() }

            if let episode = snapshot.latestEpisode {
                metadata(episode: episode)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenDetail() }

                rightControl(episode: episode)
            } else {
                Text("No episodes")
                    .font(Brand.Font.serifLightItalic(size: 13))
                    .foregroundStyle(Brand.Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Brand.Layout.rowPadding)
    }

    /// Position number, OR (for now-playing) a 20×20 accent circle with VU bars.
    @ViewBuilder
    private var leftSlot: some View {
        switch rowState {
        case .nowPlaying:
            ZStack {
                Circle()
                    .fill(Brand.Color.accent)
                    .frame(width: 20, height: 20)
                NowPlayingIndicator(isPlaying: isPlaying, color: Brand.Color.paper)
            }
        case .unplayed:
            Text(String(format: "%02d", snapshot.position))
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkSecondary)
        case .started, .played:
            Text(String(format: "%02d", snapshot.position))
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.ink.opacity(0.30))  // dimmed
        }
    }

    private func metadata(episode: EpisodeRowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            eyebrow(episode: episode)
            titleText(episode: episode)
                .frame(minHeight: 14 * 1.22 * 2, alignment: .topLeading)  // 2-line reservation
            footnote(episode: episode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Eyebrow varies by state. Started includes inline progress ring + M LEFT.
    /// Now-playing uses standard show eyebrow but with M IN highlighted in accent.
    @ViewBuilder
    private func eyebrow(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .started:
            HStack(spacing: 6) {
                ProgressRing(fraction: episode.progressFraction, size: 11, color: Brand.Color.accent)
                Text("\(minutesLeft(episode))M LEFT")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.accent)
                Text("· \(snapshot.title)")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.inkMuted)
                    .lineLimit(1)
            }
        default:
            HStack(spacing: 6) {
                Text(snapshot.title)
                    .foregroundStyle(Brand.Color.inkSecondary)
                    .lineLimit(1)
                Text("·")
                    .foregroundStyle(Brand.Color.inkFaint)
                Text(relativeDate(episode.publishDate))
                    .foregroundStyle(Brand.Color.inkSecondary)
                if episode.isExplicit {
                    Text("E")
                        .padding(.horizontal, 3)
                        .background(Brand.Color.inkHairline, in: RoundedRectangle(cornerRadius: 2))
                        .foregroundStyle(Brand.Color.inkSecondary)
                }
            }
            .font(Brand.Font.monoEyebrow())
            .tracking(Brand.Layout.monoTracking)
            .textCase(.uppercase)
        }
    }

    /// Title typography differs in started state.
    @ViewBuilder
    private func titleText(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .started:
            Text(episode.title)
                .font(Brand.Font.serifLightItalic())
                .foregroundStyle(Brand.Color.ink.opacity(0.78))
                .lineLimit(2)
        default:
            Text(episode.title)
                .font(Brand.Font.serifBody())
                .foregroundStyle(Brand.Color.ink)
                .lineLimit(2)
        }
    }

    /// Footnote varies: started → "PAUSED AT NM · TOTAL MIN TOTAL"; now-playing → "TOTAL MIN · NM IN"; played → "✓ PLAYED"; unplayed → "TOTAL MIN".
    @ViewBuilder
    private func footnote(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .played:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .semibold))
                Text("Played")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Brand.Color.inkMuted)
        case .started:
            Text("PAUSED AT \(episode.formattedElapsed) · \(episode.formattedDuration.uppercased()) TOTAL")
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
        case .nowPlaying:
            HStack(spacing: 6) {
                Text(episode.formattedDuration.uppercased())
                    .foregroundStyle(Brand.Color.inkMuted)
                Text("·")
                    .foregroundStyle(Brand.Color.inkFaint)
                Text("\(episode.formattedElapsed) IN")
                    .foregroundStyle(Brand.Color.accent)
            }
            .font(Brand.Font.monoEyebrow())
            .tracking(Brand.Layout.monoTracking)
        case .unplayed:
            Text(episode.formattedDuration.uppercased())
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
        }
    }

    /// Right-side button. now-playing & started have specialized treatments;
    /// otherwise delegate to PlayControlView.
    @ViewBuilder
    private func rightControl(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .nowPlaying:
            Button(action: onPlay) {
                ZStack {
                    Circle().fill(Brand.Color.accent).frame(width: 38, height: 38)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.Color.paper)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .started:
            // Accent-outlined resume (distinct from unplayed's paper-ring play and played's transparent replay)
            Button(action: onPlay) {
                ZStack {
                    Circle().fill(Brand.Color.paper)
                        .overlay(Circle().strokeBorder(Brand.Color.accent, lineWidth: 1.5))
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.Color.accent)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .unplayed, .played:
            PlayControlView(
                episode: episode,
                isCurrent: false,
                isPlaying: false,
                onTap: onPlay
            )
        }
    }

    private var progressFraction: Double {
        snapshot.latestEpisode?.progressFraction ?? 0
    }

    private func minutesLeft(_ episode: EpisodeRowSnapshot) -> Int {
        let remaining = max(0, episode.totalDuration - episode.playbackPosition)
        return Int(remaining / 60)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// Small inline progress ring used in the started-row eyebrow.
private struct ProgressRing: View {
    let fraction: Double
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
```

Note the `2-line reservation` line `frame(minHeight: 14 * 1.22 * 2, ...)` — this implements the fixed-row-height rule per spec. Title size 14pt × line-height 1.22 × 2 lines.

- [ ] **Step 5.4: Update `SubscriptionsListView` ForEach to pass `position`**

Find the ForEach in `SubscriptionsListView.swift` that builds `PodcastRowSnapshot`. The current init is `PodcastRowSnapshot(podcast)` — that still works because `position = podcast.sortPosition + 1` is set inside the init. No call-site change needed unless the snapshot's init signature changed; verify.

- [ ] **Step 5.5: Build + test — expect 101 passing (unchanged from start of view migrations)**

```bash
xcodebuild test -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED" | tail -3
```

- [ ] **Step 5.6: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/PodcastRowView.swift Vibecast/Vibecast/Views/PodcastRowSnapshot.swift Vibecast/Vibecast/Views/SubscriptionsListView.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh PodcastRowView with four-state vocabulary

unplayed / started / now-playing / played. State precedence: now-playing
wins, otherwise listenedStatus drives. Per-state typography (Fraunces
500 vs Fraunces-Italic 300 at 78% ink for started), position number
opacity (full vs 30%), eyebrow content (show name vs ring + M LEFT),
footnote (TOTAL MIN vs PAUSED AT vs TOTAL MIN · M IN vs ✓ PLAYED), right
control (paper-ring play vs accent-outlined resume vs accent-filled
pause vs transparent replay). Now-playing row gets the NowPlayingCard
decoration (border + halo + top progress bar) and a 20×20 accent circle
with NowPlayingIndicator in the left slot. Unplayed row gets a 3pt
fallback-color sliver on the leading edge."
```

---

## Task 6: Refresh `EpisodeRowView`

**Why this task:** Same vocabulary as podcast row's metadata. Used in `PodcastDetailView`'s episode list. Date eyebrow + Fraunces title + mono duration.

**Files:**
- Modify: `Vibecast/Vibecast/Views/EpisodeRowView.swift`

- [ ] **Step 6.1: Read the current file**

- [ ] **Step 6.2: Apply refresh**

The episode row in detail view doesn't have a podcast-cover slot (the podcast cover is up in the hero). Just metadata + play control.

```swift
import SwiftUI

struct EpisodeRowView: View {
    let episode: Episode
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                metadata
                    .frame(maxWidth: .infinity, alignment: .leading)
                PlayControlView(
                    episode: EpisodeRowSnapshot(episode),
                    isCurrent: isCurrent,
                    isPlaying: isPlaying,
                    onTap: onPlay
                )
            }
            .padding(Brand.Layout.rowPadding)
            .opacity(episode.listenedStatus == .played ? 0.55 : 1.0)
            Rectangle()
                .fill(Brand.Color.inkHairline)
                .frame(height: Brand.hairlineWidth)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            dateEyebrow
            Text(episode.title)
                .font(Brand.Font.serifBody())
                .foregroundStyle(Brand.Color.ink)
                .lineLimit(2)
            durationLabel
        }
    }

    private var dateEyebrow: some View {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let relative = formatter.localizedString(for: episode.publishDate, relativeTo: .now)
        return HStack(spacing: 6) {
            Text(relative)
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .textCase(.uppercase)
                .foregroundStyle(Brand.Color.inkSecondary)
            if episode.isExplicit {
                Text("E")
                    .font(Brand.Font.monoEyebrow())
                    .padding(.horizontal, 3)
                    .background(Brand.Color.inkHairline, in: RoundedRectangle(cornerRadius: 2))
                    .foregroundStyle(Brand.Color.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private var durationLabel: some View {
        if episode.listenedStatus == .played {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .semibold))
                Text("Played")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Brand.Color.inkMuted)
        } else {
            Text(episode.formattedDuration.uppercased())
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
        }
    }
}
```

- [ ] **Step 6.3: Build + test**

- [ ] **Step 6.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/EpisodeRowView.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh EpisodeRowView with Editorial language

Date mono eyebrow + serif title + mono duration. Played opacity 0.55
+ ✓ PLAYED. Reuses PlayControlView for the right-side button."
```

---

## Task 7: Refresh `PodcastDetailView`

**Why this task:** Hero with cover + Fraunces title + mono publisher. Episode list using refreshed `EpisodeRowView`.

**Files:**
- Modify: `Vibecast/Vibecast/Views/PodcastDetailView.swift`

- [ ] **Step 7.1: Read the current file**

Note current navigation-title setup (used `Image(systemName: "mic.fill")` from Plan 1 originally; updated to `AsyncImage` in Plan 3 fixes).

- [ ] **Step 7.2: Apply refresh**

Restyle the existing structure. Replace artwork-loading block with `CoverArtwork`. Replace title font/color with Brand tokens. Update episode list rendering.

Key changes:
- Hero `CoverArtwork(urlString: podcast.artworkURL, title: podcast.title, size: 120, radius: Brand.Radius.coverMedium)`
- Publisher: `Text(podcast.author).font(Brand.Font.monoEyebrow(size: 11)).tracking(0.9).textCase(.uppercase).foregroundStyle(Brand.Color.inkSecondary)`
- Title: `Text(podcast.title).font(Brand.Font.serifTitle(size: 28)).foregroundStyle(Brand.Color.ink)`
- Background `Brand.Color.bg`
- List style `.plain` with `.listRowBackground(Brand.Color.bg)` and `.listRowSeparator(.hidden)` so the row hairlines from `EpisodeRowView` carry the visual rhythm.

Preserve all the existing `.task` refresh logic and PodcastDetailViewModel integration from Plan 4 Task 10.

- [ ] **Step 7.3: Build + test**

- [ ] **Step 7.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/PodcastDetailView.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh PodcastDetailView with Editorial hero

CoverArtwork at 120pt with 6pt radius. Publisher mono eyebrow, podcast
title in Fraunces 28pt. Episode list uses refreshed EpisodeRowView.
Preserves Plan 4's .task refresh integration."
```

---

## Task 8: Refresh `SearchResultRow`

**Why this task:** Subscribe-flow row in `AddPodcastSheet`. 4-state subscribe button per spec.

**Files:**
- Modify: `Vibecast/Vibecast/Views/SearchResultRow.swift`

- [ ] **Step 8.1: Read the current file**

Note 4 states (`isSubscribed`, `isInFlight`, `isFailed`, default) and the accessibility labels added in Plan 5 Task 10. Preserve all of these.

- [ ] **Step 8.2: Apply refresh**

```swift
HStack(alignment: .center, spacing: 12) {
    CoverArtwork(
        urlString: result.artworkURL?.absoluteString,
        title: result.title,
        size: 44,
        radius: Brand.Radius.coverSmall
    )
    VStack(alignment: .leading, spacing: 3) {
        Text(result.author)
            .font(Brand.Font.monoEyebrow())
            .tracking(Brand.Layout.monoTracking)
            .textCase(.uppercase)
            .foregroundStyle(Brand.Color.inkSecondary)
            .lineLimit(1)
        Text(result.title)
            .font(Brand.Font.serifBody())
            .foregroundStyle(Brand.Color.ink)
            .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    subscribeButton
}
.padding(Brand.Layout.rowPadding)
```

For the subscribeButton's 4 states:
- Idle: `paper` ring with `inkHairline` border, `+` glyph in `ink`
- In-flight: `accent` filled circle + `ProgressView` tinted `paper`
- Subscribed: `accent` filled circle + `checkmark` in `paper`
- Failed: `paper` ring + `+` glyph in `ink` + inline failure text below as currently

Preserve all `accessibilityLabelForState` / `accessibilityHintForState` / 44pt frame logic.

- [ ] **Step 8.3: Build + test**

- [ ] **Step 8.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/SearchResultRow.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh SearchResultRow with Editorial language

Mono author eyebrow + serif title. CoverArtwork with initials fallback.
Subscribe button: paper ring + ink default, accent-filled spinner/check
for in-flight/subscribed. Plan 5 a11y labels preserved."
```

---

## Task 9: Refresh `AddPodcastSheet`

**Why this task:** Sheet container around the search and OPML import flows.

**Files:**
- Modify: `Vibecast/Vibecast/Views/AddPodcastSheet.swift`

- [ ] **Step 9.1: Read the current file end-to-end**

Note the inner `LoadedSheet` from Plan 5 Task 1 follow-up.

- [ ] **Step 9.2: Apply visual refresh**

Restyle without changing structure:
- Sheet bg: `Brand.Color.bg`
- Custom drag handle: 36×4 rounded rect in `Brand.Color.inkHairline` at top-center
- Sheet title "Add Podcast": `Brand.Font.serifSubtitle()` in `Brand.Color.ink`
- Search input: Inter 14pt, paper-colored capsule with hairline border
- "Import from File" button: `Brand.Color.paper` background + `Brand.Color.inkHairline` border, `Brand.Font.uiButton()` label in `Brand.Color.ink`
- States (idle/searching/error/results): typography matches Brand roles

The "Manager unavailable" fallback view from Plan 5: keep the `ContentUnavailableView` but restyle the title in `Brand.Font.serifSubtitle()` and description in `Brand.Font.uiBody()`.

- [ ] **Step 9.3: Build + test**

- [ ] **Step 9.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/AddPodcastSheet.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh AddPodcastSheet with Editorial chrome

Paper bg, hairline drag handle, Fraunces sheet title, Inter input,
outlined import button. Inner LoadedSheet structure (Plan 5) preserved."
```

---

## Task 10: Refresh `MiniPlayerBar`

**Why this task:** Persistent player bar across the app. Phase 1 = neutral form (no vibe color stripe).

**Files:**
- Modify: `Vibecast/Vibecast/Views/MiniPlayerBar.swift`

- [ ] **Step 10.1: Read the current file**

Preserve the `PreviewAudioEngine` (was scrubbed in Plan 5 Task 4 to add interruption callbacks).

- [ ] **Step 10.2: Apply refresh**

Container shape:
- Background: `Brand.Color.paper`
- Border: 1pt `Brand.Color.inkHairline`
- Card radius: `Brand.Radius.card` (14)
- Height: ~64pt (cover 44 + padding)

Layout:
- Left 44×44 `CoverArtwork` (with 4pt radius)
- Center: `monoEyebrow` podcast title above `serifBody` episode title (lineLimit 1 each)
- Right: skip-back-15 (38×38) + play/pause (56×56, accent-filled when playing) + skip-forward-30 (38×38)
- Bottom edge: 2pt accent-color progress sliver (`Rectangle().fill(accent).frame(width: progressFraction * totalWidth, height: 2)`)

- [ ] **Step 10.3: Build + test**

- [ ] **Step 10.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/MiniPlayerBar.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh MiniPlayerBar with Editorial container

Paper card with hairline border at 14pt radius. Cover, mono podcast +
serif episode title, skip/play/skip transport. Bottom accent-color
progress sliver. Phase 1 neutral form (no vibe stripe)."
```

---

## Task 11: Refresh `FullScreenPlayerView`

**Why this task:** The expanded player. Large cover, Fraunces title, accent primary play, scrubber, transport.

**Files:**
- Modify: `Vibecast/Vibecast/Views/FullScreenPlayerView.swift`

- [ ] **Step 11.1: Read the current file**

Preserve the `SystemVolumeView` (MPVolumeView from Plan 5 Task 3).

- [ ] **Step 11.2: Apply refresh**

Layout top-to-bottom:
- Drag-down handle 36×4 in `inkHairline`
- "Now Playing" `monoEyebrow` (uppercase)
- `CoverArtwork` at 280×280 with 8pt radius and a drop shadow `0 8 20 black/0.10`
- Podcast name: `monoEyebrow(size: 11)`
- Episode title: `serifTitle(size: 28)` centered, lineLimit 2
- Scrubber: hairline track + accent-filled progress + draggable thumb. Time labels in `monoEyebrow`.
- Transport row: skip-back-15 (56×56, paper ring), primary play (70×70 accent-filled when playing, paper ring with ink glyph when paused), skip-forward-30 (56×56)
- Bottom: existing `SystemVolumeView` with appropriate padding

Background: `Brand.Color.bg`.

- [ ] **Step 11.3: Build + test**

- [ ] **Step 11.4: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/FullScreenPlayerView.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh FullScreenPlayerView with Editorial player

Paper bg, 280pt cover with 8pt radius and shadow, Fraunces 28pt title,
accent-filled 70pt primary play. Hairline scrubber track with accent
progress. SystemVolumeView (Plan 5) preserved."
```

---

## Task 12: Refresh `SubscriptionsListView` + light-mode app root

**Why this task:** The library home — most visible surface. Custom Fraunces wordmark with accent dot replaces system nav title. Toolbar restyling. List separators replaced by row hairlines. App root forces `.preferredColorScheme(.light)`.

**Files:**
- Modify: `Vibecast/Vibecast/Views/SubscriptionsListView.swift`
- Modify: `Vibecast/Vibecast/VibecastApp.swift`

- [ ] **Step 12.1: Read both files end-to-end**

Note the `pendingDeletes` set and dispatched-delete pattern from Plan 5 Task 1 follow-up. Preserve.

- [ ] **Step 12.2: Replace `.navigationTitle("Subscriptions")` with custom wordmark**

Inside the `NavigationStack` body, before the `listContent`, add a leading-aligned wordmark:

```swift
NavigationStack {
    listContent
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                wordmark
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
                    .foregroundStyle(Brand.Color.ink)
                    .font(Brand.Font.uiButton())
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Brand.Color.ink)
                }
            }
        }
        // ... existing .sheet, .navigationDestination, .safeAreaInset modifiers
}
```

The wordmark:

```swift
private var wordmark: some View {
    HStack(spacing: 1.8) {
        Text("Vibecast")
            .font(Brand.Font.display(size: 22))
            .tracking(-0.7)  // ≈ -0.035em at 22pt
            .foregroundStyle(Brand.Color.ink)
        Circle()
            .fill(Brand.Color.accent)
            .frame(width: 5.5, height: 5.5)
            .offset(y: 4)  // baseline-align below the t
    }
}
```

- [ ] **Step 12.3: Restyle list and rows**

In `listContent` apply:
- `.background(Brand.Color.bg)` to the List/empty container
- `.listStyle(.plain)`
- `.scrollContentBackground(.hidden)` (so the `bg` shows through)
- Each row: `.listRowBackground(Brand.Color.bg)` + `.listRowSeparator(.hidden)`

The empty state: replace `ContentUnavailableView` styling — title in `serifSubtitle`, description in `uiBody`, icon `accent`-tinted.

- [ ] **Step 12.4: Force light mode at app root**

Open `Vibecast/Vibecast/VibecastApp.swift`. In the `WindowGroup` body, append `.preferredColorScheme(.light)`:

```swift
WindowGroup {
    SubscriptionsListView()
        .modelContainer(container)
        .environment(\.playerManager, playerManager)
        .environment(\.subscriptionManager, subscriptionManager)
        .preferredColorScheme(.light)
}
```

- [ ] **Step 12.5: Build + test**

- [ ] **Step 12.6: Commit**

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh add Vibecast/Vibecast/Views/SubscriptionsListView.swift Vibecast/Vibecast/VibecastApp.swift
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh commit -m "feat(visual): refresh SubscriptionsListView; force light mode

Custom Fraunces 'Vibecast' wordmark + accent dot in topBarLeading slot,
replacing the system navigationTitle. EditButton + plus button restyled
with Brand tokens. List separators hidden (rows carry their own
hairlines). Empty state uses Brand typography. App root forces
.preferredColorScheme(.light) so dark-mode users still get the
editorial palette."
```

---

## Task 13: Manual end-to-end verification on device

**Why this task:** Visual refresh ships on device verification. The 90-test suite catches behavioral regressions but cannot verify typography, color, layout, or font registration.

**No code changes.** This task hands back to the user with the verification script below.

- [ ] **Step 13.1: Build a fresh debug install**

```bash
xcodebuild -project /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh/Vibecast/Vibecast.xcodeproj -scheme Vibecast -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/vibecast-plan6-final build
xcrun simctl install booted /tmp/vibecast-plan6-final/Build/Products/Debug-iphonesimulator/Vibecast.app
```

User then deploys to real device via Xcode Cmd+R for the actual verification.

- [ ] **Step 13.2: User verification script**

1. **Fonts loaded.** Custom fonts visible everywhere. If anything renders in San Francisco / Times New Roman, registration failed.
2. **Library wordmark.** "Vibecast" in Fraunces 22pt + small teal accent dot at top-left. Toolbar `+` and Edit button styled.
3. **Library row.** Mono show name eyebrow + Fraunces episode title + mono duration. 44×44 cover with serif initials when no artwork. Played episodes dim with `✓ PLAYED`.
4. **Currently-playing row.** When playing, the row shows the 3-bar VU badge on the cover. Right control shows accent-filled pause.
5. **Detail view.** Hero cover at 120pt with 6pt radius, podcast name in mono eyebrow, podcast title in Fraunces 28pt. Episode list with date eyebrow + serif title + mono duration.
6. **Search.** Add Podcast sheet styled, search results show mono author + serif title. Subscribe button cycles through 4 states with correct visuals.
7. **OPML import.** Import button styled correctly.
8. **Mini player.** Paper card with hairline border, mono + serif text, accent progress sliver across bottom. Tap expands.
9. **Full-screen player.** Paper bg, 280pt cover with shadow, Fraunces title, accent 70pt primary play.
10. **Light mode lock.** Switch device to dark mode → app stays in light editorial palette.
11. **Dynamic Type.** Settings → Display → Text Size, scale up. Verify no text clipping or overlap.
12. **Rotate device.** Layout adapts cleanly.
13. **Existing behavior.** Playback, subscribe, OPML import, refresh, mark-played, auto-advance — all from Plan 5 — still work.

- [ ] **Step 13.3: Push branch after verification passes**

When the user confirms all 13 checkpoints pass:

```bash
git -C /Users/dustinanglin/.config/superpowers/worktrees/Vibecast/plan-6-visual-refresh push -u origin feature/plan-6-visual-refresh
```

---

## Summary

13 tasks. Test count stays at 90 throughout (no behavioral changes — visual-only). Approximate file changes:

- 1 new directory (`Resources/Fonts/`) with 3 TTF files
- 4 new Swift files (`Brand.swift`, `CoverArtwork.swift`, `NowPlayingIndicator.swift`)
- 9 view files modified
- 2 project files modified (`Info.plist`, `project.pbxproj` if synced)
- 1 app entry modified (`VibecastApp.swift`)

Final result: editorial visual language landed across all 9 visible surfaces, with foundation for Plans 7 (Vibes) and 8 (Pinning) to layer vibe-tinted accents on top of the same `Brand` token surface.
