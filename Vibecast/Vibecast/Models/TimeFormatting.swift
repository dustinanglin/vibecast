import Foundation

/// Voice-friendly time formatting for VoiceOver labels.
///
/// The on-screen mono-eyebrow time pills render durations as compact
/// digits ("1:23:45", "14m", "1h 2m"). Without an `.accessibilityLabel`
/// VoiceOver spells those out character-by-character — "one colon two
/// three colon four five" — which is unintelligible at speech speed.
///
/// `TimeFormatting.spoken(seconds:)` produces a natural-language form
/// ("1 hour, 23 minutes, 45 seconds") suitable for use as a Text's
/// `.accessibilityLabel`. Zero-valued units are dropped, so a 14-minute
/// episode reads as "14 minutes" rather than "0 hours 14 minutes 0
/// seconds".
enum TimeFormatting {
    /// Localized `DateComponentsFormatter` shared across callsites. Cheap
    /// to keep around — the formatter itself isn't expensive but
    /// re-instantiating one per render burns CPU during scroll.
    private static let accessibilityFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .full
        f.zeroFormattingBehavior = .dropAll
        return f
    }()

    /// Returns a voice-friendly string for the given duration. Negative
    /// inputs are clamped to zero — accessibility labels should never
    /// announce nonsense like "negative 5 seconds" from a transient
    /// player state.
    static func spoken(seconds: TimeInterval) -> String {
        let clamped = max(0, seconds)
        if let s = accessibilityFormatter.string(from: clamped) {
            return s
        }
        return "\(Int(clamped)) seconds"
    }

    static func spoken(seconds: Int) -> String {
        spoken(seconds: TimeInterval(seconds))
    }
}
