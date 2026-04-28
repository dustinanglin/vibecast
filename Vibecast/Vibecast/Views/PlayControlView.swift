import SwiftUI
import SwiftData

struct PlayControlView: View {
    let episode: EpisodeRowSnapshot
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    let onTap: () -> Void

    private var ringColor: Color {
        switch episode.listenedStatus {
        case .unplayed:   return .clear
        case .inProgress: return .accentColor
        case .played:     return .accentColor.opacity(0.35)
        }
    }

    private var iconName: String {
        if isCurrent && isPlaying { return "pause.fill" }
        return episode.listenedStatus == .played ? "arrow.clockwise" : "play.fill"
    }

    private var playButtonAccessibilityLabel: String {
        if isCurrent && isPlaying  { return "Pause \(episode.title)" }
        if isCurrent && !isPlaying { return "Resume \(episode.title)" }
        if episode.listenedStatus == .played { return "Replay \(episode.title)" }
        return "Play \(episode.title)"
    }

    private var durationLabel: String {
        switch episode.listenedStatus {
        case .unplayed:   return episode.formattedDuration
        case .inProgress: return episode.formattedRemaining
        case .played:     return episode.formattedDuration
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 36, height: 36)

                    if episode.progressFraction > 0 {
                        Circle()
                            .trim(from: 0, to: episode.progressFraction)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                    }

                    Image(systemName: iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playButtonAccessibilityLabel)

            Text(durationLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let container = SampleData.container
    let episodes = try! ModelContext(container).fetch(FetchDescriptor<Episode>())
    let unplayed = EpisodeRowSnapshot(episodes.first { $0.listenedStatus == .unplayed } ?? episodes[0])
    let inProgress = EpisodeRowSnapshot(episodes.first { $0.listenedStatus == .inProgress } ?? episodes[0])
    let played = EpisodeRowSnapshot(episodes.first { $0.listenedStatus == .played } ?? episodes[0])
    HStack(spacing: 24) {
        PlayControlView(episode: unplayed, onTap: {})
        PlayControlView(episode: inProgress, onTap: {})
        PlayControlView(episode: played, onTap: {})
    }
    .modelContainer(container)
    .padding()
}
