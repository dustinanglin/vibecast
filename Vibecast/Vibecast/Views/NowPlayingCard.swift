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
