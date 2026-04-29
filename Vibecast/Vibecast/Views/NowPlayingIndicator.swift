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
