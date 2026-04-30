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
                .overlay(Circle().stroke(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
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
