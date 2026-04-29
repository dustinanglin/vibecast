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

        static func display(size: CGFloat = 28) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        static func serifTitle(size: CGFloat = 28) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        static func serifSubtitle(size: CGFloat = 22) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        static func serifBody(size: CGFloat = 14) -> SwiftUI.Font {
            .custom(fraunces, size: size).weight(.medium)
        }

        // Note: serifItalic deliberately omitted from Phase 1. The bundled Fraunces
        // variable TTF doesn't include an italic axis (would require bundling a
        // separate Fraunces-Italic[opsz,wght].ttf). Italics are barely used in
        // Phase 1 per spec; add back when needed.

        static func uiBody(size: CGFloat = 14, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .custom(inter, size: size).weight(weight)
        }

        static func uiButton(size: CGFloat = 14) -> SwiftUI.Font {
            .custom(inter, size: size).weight(.semibold)
        }

        static func monoEyebrow(size: CGFloat = 9) -> SwiftUI.Font {
            .custom(mono, size: size).weight(.semibold)
        }

        static func monoEyebrowLarge(size: CGFloat = 11) -> SwiftUI.Font {
            .custom(mono, size: size).weight(.semibold)
        }
    }

    // MARK: - Layout

    enum Layout {
        static let rowPadding: CGFloat = 12
        static let rowGap: CGFloat = 8
        static let hairlineWidth: CGFloat = 1
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
    /// Uses djb2 hash for cross-launch stability.
    static func fallbackColor(for title: String) -> SwiftUI.Color {
        var hash: UInt64 = 5381
        for byte in title.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(FallbackPalette.colors.count))
        return FallbackPalette.colors[index]
    }
}
