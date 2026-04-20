import SwiftUI
import SwiftData

struct PodcastRowView: View {
    let podcast: Podcast
    let onPlay: () -> Void
    let onOpenDetail: () -> Void

    private var latestEpisode: Episode? {
        podcast.episodes.sorted { $0.publishDate > $1.publishDate }.first
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            artworkView
                .onTapGesture { onOpenDetail() }

            if let episode = latestEpisode {
                episodeMetadata(episode: episode)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenDetail() }

                PlayControlView(episode: episode, onTap: onPlay)
            } else {
                Text("No episodes")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var artworkView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 52, height: 52)
            .overlay {
                if let urlString = podcast.artworkURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private func episodeMetadata(episode: Episode) -> some View {
        ViewThatFits(in: .vertical) {
            VStack(alignment: .leading, spacing: 3) {
                dateLabel(episode: episode)
                titleLabel(episode: episode)
                descriptionLabel(episode: episode)
            }
            VStack(alignment: .leading, spacing: 3) {
                dateLabel(episode: episode)
                titleLabel(episode: episode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateLabel(episode: Episode) -> some View {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        let relative = f.localizedString(for: episode.publishDate, relativeTo: .now)
        return HStack(spacing: 4) {
            Text(relative)
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

    private func titleLabel(episode: Episode) -> some View {
        Text(episode.title)
            .font(.system(size: 14, weight: episode.listenedStatus == .unplayed ? .bold : .regular))
            .foregroundStyle(episode.listenedStatus == .unplayed ? Color.primary : Color.secondary)
            .lineLimit(2)
    }

    private func descriptionLabel(episode: Episode) -> some View {
        Text(episode.descriptionText)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }
}

#Preview {
    let container = SampleData.container
    let podcasts = try! ModelContext(container).fetch(
        FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
    )
    return List {
        ForEach(podcasts) { podcast in
            PodcastRowView(podcast: podcast, onPlay: {}, onOpenDetail: {})
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
        }
    }
    .modelContainer(container)
}
