import SwiftUI

/// 3-bar animated VU indicator. Bar heights are a pure function of the
/// current frame's time when `isPlaying` is true, so the animation
/// survives view reuse across List contexts (e.g., swiping between All
/// and a vibe — the prior `@State`-driven approach got stuck at max
/// height because `repeatForever` doesn't re-attach when SwiftUI reuses
/// the row's view identity). When `isPlaying` is false the bars rest
/// at the quiet height and the `TimelineView` schedule is paused so it
/// doesn't burn CPU.
struct NowPlayingIndicator: View {
    let isPlaying: Bool
    var color: Color = Brand.Color.accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { context in
            HStack(alignment: .bottom, spacing: 1.5) {
                Bar(time: context.date, period: 0.62, phase: 0.00, isPlaying: isPlaying, color: color)
                Bar(time: context.date, period: 0.78, phase: 0.18, isPlaying: isPlaying, color: color)
                Bar(time: context.date, period: 0.94, phase: 0.32, isPlaying: isPlaying, color: color)
            }
            .frame(width: 14, height: 14)
            .padding(2)
        }
    }

    private struct Bar: View {
        let time: Date
        /// Seconds per full down→up→down cycle.
        let period: Double
        /// Seconds offset into the cycle so bars wiggle out-of-sync.
        let phase: Double
        let isPlaying: Bool
        let color: Color

        private let minHeight: CGFloat = 4
        private let maxHeight: CGFloat = 12

        var body: some View {
            let height: CGFloat = {
                guard isPlaying else { return minHeight }
                let t = time.timeIntervalSince1970 + phase
                // (1 - cos(2π · t/period)) / 2 ∈ [0, 1] — smooth bounce.
                let progress = (1.0 - cos(2.0 * .pi * t / period)) / 2.0
                return minHeight + (maxHeight - minHeight) * progress
            }()
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 2.5, height: height)
                .animation(isPlaying ? nil : .easeOut(duration: 0.18), value: isPlaying)
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
