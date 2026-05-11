import SwiftUI

/// One of the five seeded vibe color identities. New user-created vibes
/// pick from the same palette; there's no free-form color picker.
///
/// Pre-converted sRGB approximations of the oklch values defined in
/// docs/design/vibecast-visual-prototypes/project/vibes-shared.jsx.
enum VibeColorKey: String, CaseIterable, Codable, Sendable {
    case morning
    case around
    case workout
    case winddown
    case deepwork

    /// Saturated band color (used for masthead band, dot indicators, CTA fill).
    var bandHex: UInt32 {
        switch self {
        case .morning:  return 0xD89A4F
        case .around:   return 0x2E94A8
        case .workout:  return 0xC75641
        case .winddown: return 0x7066B0
        case .deepwork: return 0x3F8B5C
        }
    }

    /// Light tinted background (used for vibe.chip surfaces — Manage Vibes
    /// cards, filled detail-pill bg).
    var chipHex: UInt32 {
        switch self {
        case .morning:  return 0xF4DDB3
        case .around:   return 0xB7DCE3
        case .workout:  return 0xEDC1B6
        case .winddown: return 0xCFC9E7
        case .deepwork: return 0xBCD8C5
        }
    }

    /// Dark text for placement on chip surfaces.
    var inkHex: UInt32 {
        switch self {
        case .morning:  return 0x5C3A0E
        case .around:   return 0x163E47
        case .workout:  return 0x562018
        case .winddown: return 0x26214B
        case .deepwork: return 0x173A22
        }
    }

    var band: Color { Self.color(bandHex) }
    var chip: Color { Self.color(chipHex) }
    var ink: Color  { Self.color(inkHex) }

    /// Default human-readable name used at seeding time.
    var defaultName: String {
        switch self {
        case .morning:  return "Morning"
        case .around:   return "Around"
        case .workout:  return "Workout"
        case .winddown: return "Wind down"
        case .deepwork: return "Deep work"
        }
    }

    private static func color(_ rgb: UInt32) -> Color {
        Color(
            red:   Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >>  8) & 0xFF) / 255.0,
            blue:  Double( rgb        & 0xFF) / 255.0
        )
    }
}
