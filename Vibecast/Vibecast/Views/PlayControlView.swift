import SwiftUI
import SwiftData

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
    let container = SampleData.container
    let episodes = try! ModelContext(container).fetch(FetchDescriptor<Episode>())
    let unplayed = EpisodeRowSnapshot(episodes.first { $0.listenedStatus == .unplayed } ?? episodes[0])
    let inProgress = EpisodeRowSnapshot(episodes.first { $0.listenedStatus == .inProgress } ?? episodes[0])
    let played = EpisodeRowSnapshot(episodes.first { $0.listenedStatus == .played } ?? episodes[0])
    VStack(spacing: 18) {
        HStack(spacing: 16) {
            PlayControlView(episode: unplayed, isCurrent: false, isPlaying: false, onTap: {})
            Text("Unplayed · paper ring + ink play").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        HStack(spacing: 16) {
            PlayControlView(episode: inProgress, isCurrent: true, isPlaying: true, onTap: {})
            Text("Current + playing · accent fill + paper pause").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        HStack(spacing: 16) {
            PlayControlView(episode: inProgress, isCurrent: true, isPlaying: false, onTap: {})
            Text("Current + paused · accent fill + paper play").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        HStack(spacing: 16) {
            PlayControlView(episode: played, isCurrent: false, isPlaying: false, onTap: {})
            Text("Played · transparent + muted replay").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
    .modelContainer(container)
    .padding(24)
    .background(Brand.Color.bg)
}
