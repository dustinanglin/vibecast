import SwiftUI
import SwiftData

struct PlayControlView: View {
    let episode: Episode
    let onTap: () -> Void

    private var ringColor: Color {
        switch episode.listenedStatus {
        case .unplayed:   return .clear
        case .inProgress: return .accentColor
        case .played:     return .accentColor.opacity(0.35)
        }
    }

    private var iconName: String {
        episode.listenedStatus == .played ? "arrow.clockwise" : "play.fill"
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
            }
            .buttonStyle(.plain)

            Text(durationLabel)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let container = SampleData.container
    let episodes = try! ModelContext(container).fetch(FetchDescriptor<Episode>())
    let unplayed = episodes.first { $0.listenedStatus == .unplayed } ?? episodes[0]
    let inProgress = episodes.first { $0.listenedStatus == .inProgress } ?? episodes[0]
    let played = episodes.first { $0.listenedStatus == .played } ?? episodes[0]
    return HStack(spacing: 24) {
        PlayControlView(episode: unplayed, onTap: {})
        PlayControlView(episode: inProgress, onTap: {})
        PlayControlView(episode: played, onTap: {})
    }
    .modelContainer(container)
    .padding()
}
