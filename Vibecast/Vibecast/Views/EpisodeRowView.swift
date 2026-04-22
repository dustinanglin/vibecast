import SwiftUI
import SwiftData

struct EpisodeRowView: View {
    let episode: Episode
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    let onPlay: () -> Void

    private var titleWeight: Font.Weight {
        episode.listenedStatus == .unplayed ? .bold : .regular
    }

    private var titleColor: Color {
        episode.listenedStatus == .unplayed ? .primary : .secondary
    }

    private var relativeDate: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: episode.publishDate, relativeTo: .now)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: 3) {
                    dateLabel
                    titleLabel
                    descriptionLabel
                }
                VStack(alignment: .leading, spacing: 3) {
                    dateLabel
                    titleLabel
                }
            }

            Spacer(minLength: 8)

            PlayControlView(
                episode: episode,
                isCurrent: isCurrent,
                isPlaying: isPlaying,
                onTap: onPlay
            )
        }
        .frame(minHeight: 72)
    }

    private var dateLabel: some View {
        HStack(spacing: 4) {
            Text(relativeDate)
            if episode.isExplicit {
                Text("E")
                    .padding(.horizontal, 3)
                    .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 2))
            }
            if episode.listenedStatus == .played {
                Image(systemName: "checkmark")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
    }

    private var titleLabel: some View {
        Text(episode.title)
            .font(.system(size: 14, weight: titleWeight))
            .foregroundStyle(titleColor)
            .lineLimit(2)
    }

    private var descriptionLabel: some View {
        Text(episode.descriptionText)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}

#Preview {
    let container = SampleData.container
    let episodes = try! ModelContext(container).fetch(
        FetchDescriptor<Episode>(sortBy: [SortDescriptor(\.publishDate, order: .reverse)])
    )
    return List {
        ForEach(episodes.prefix(6)) { ep in
            EpisodeRowView(episode: ep, onPlay: {})
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
        }
    }
    .modelContainer(container)
}
