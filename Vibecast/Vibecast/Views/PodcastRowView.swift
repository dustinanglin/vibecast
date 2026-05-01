import SwiftUI
import SwiftData

struct PodcastRowView: View {
    let snapshot: PodcastRowSnapshot
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    let onPlay: () -> Void
    let onOpenDetail: () -> Void

    private enum RowState { case unplayed, started, nowPlaying, played }

    /// State precedence: now-playing wins; otherwise listenedStatus drives.
    private var rowState: RowState {
        if isCurrent { return .nowPlaying }
        guard let ep = snapshot.latestEpisode else { return .unplayed }
        switch ep.listenedStatus {
        case .unplayed:   return .unplayed
        case .inProgress: return .started
        case .played:     return .played
        }
    }

    var body: some View {
        cardWrapper
            .padding(.vertical, Brand.Layout.rowGap / 2)
            .opacity(rowState == .played ? 0.55 : 1.0)
    }

    /// Wraps the row content with the appropriate decoration:
    /// - now-playing → 2pt accent border + halo + top progress bar (NowPlayingCard)
    /// - unplayed → 3pt fallback-color sliver at leading edge + paper card + hairline border
    /// - started, played → paper card + hairline border (no sliver)
    @ViewBuilder
    private var cardWrapper: some View {
        switch rowState {
        case .nowPlaying:
            cardContent
                .nowPlayingCard(progressFraction: progressFraction)
        case .unplayed:
            HStack(spacing: 0) {
                RowSliver(color: Brand.fallbackColor(for: snapshot.title))
                cardContent
                    .frame(maxWidth: .infinity)
            }
            .background(Brand.Color.paper)
            .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
            )
        case .started, .played:
            cardContent
                .background(Brand.Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.Radius.card)
                        .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                )
        }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 12) {
            leftSlot
                .frame(width: 28)
            CoverArtwork(
                urlString: snapshot.artworkURL,
                title: snapshot.title,
                size: 44,
                radius: Brand.Radius.coverSmall
            )
            .onTapGesture { onOpenDetail() }

            if let episode = snapshot.latestEpisode {
                metadata(episode: episode)
                    .contentShape(Rectangle())
                    .onTapGesture { onOpenDetail() }

                rightControl(episode: episode)
            } else {
                Text("No episodes")
                    .font(Brand.Font.serifLightItalic(size: 13))
                    .foregroundStyle(Brand.Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Brand.Layout.rowPadding)
    }

    /// Position number, OR (for now-playing) a 20×20 accent circle with VU bars.
    @ViewBuilder
    private var leftSlot: some View {
        switch rowState {
        case .nowPlaying:
            ZStack {
                Circle()
                    .fill(Brand.Color.accent)
                    .frame(width: 20, height: 20)
                NowPlayingIndicator(isPlaying: isPlaying, color: Brand.Color.paper)
            }
        case .unplayed:
            Text(String(format: "%02d", snapshot.position))
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkSecondary)
        case .started, .played:
            Text(String(format: "%02d", snapshot.position))
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.ink.opacity(0.30))  // dimmed
        }
    }

    private func metadata(episode: EpisodeRowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            eyebrow(episode: episode)
            titleText(episode: episode)
                .frame(minHeight: 14 * 1.22 * 2, alignment: .topLeading)  // 2-line reservation
            footnote(episode: episode)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Eyebrow varies by state. Started includes inline progress ring + M LEFT.
    @ViewBuilder
    private func eyebrow(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .started:
            HStack(spacing: 6) {
                ProgressRing(fraction: episode.progressFraction, size: 11, color: Brand.Color.accent)
                Text("\(minutesLeft(episode))M LEFT")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.accent)
                Text("· \(snapshot.title)")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.inkMuted)
                    .lineLimit(1)
            }
        default:
            HStack(spacing: 6) {
                Text(snapshot.title)
                    .foregroundStyle(Brand.Color.inkSecondary)
                    .lineLimit(1)
                Text("·")
                    .foregroundStyle(Brand.Color.inkFaint)
                Text(relativeDate(episode.publishDate))
                    .foregroundStyle(Brand.Color.inkSecondary)
                if episode.isExplicit {
                    Text("E")
                        .padding(.horizontal, 3)
                        .background(Brand.Color.inkHairline, in: RoundedRectangle(cornerRadius: 2))
                        .foregroundStyle(Brand.Color.inkSecondary)
                }
            }
            .font(Brand.Font.monoEyebrow())
            .tracking(Brand.Layout.monoTracking)
            .textCase(.uppercase)
        }
    }

    /// Title typography differs in started state.
    @ViewBuilder
    private func titleText(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .started:
            Text(episode.title)
                .font(Brand.Font.serifLightItalic())
                .foregroundStyle(Brand.Color.ink.opacity(0.78))
                .lineLimit(2)
        default:
            Text(episode.title)
                .font(Brand.Font.serifBody())
                .foregroundStyle(Brand.Color.ink)
                .lineLimit(2)
        }
    }

    /// Footnote varies by state.
    @ViewBuilder
    private func footnote(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .played:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .semibold))
                Text("Played")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Brand.Color.inkMuted)
        case .started:
            Text("PAUSED AT \(episode.formattedElapsed) · \(episode.formattedDuration.uppercased()) TOTAL")
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
        case .nowPlaying:
            HStack(spacing: 6) {
                Text(episode.formattedDuration.uppercased())
                    .foregroundStyle(Brand.Color.inkMuted)
                Text("·")
                    .foregroundStyle(Brand.Color.inkFaint)
                Text("\(episode.formattedElapsed) IN")
                    .foregroundStyle(Brand.Color.accent)
            }
            .font(Brand.Font.monoEyebrow())
            .tracking(Brand.Layout.monoTracking)
        case .unplayed:
            Text(episode.formattedDuration.uppercased())
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
        }
    }

    /// Right-side button. now-playing & started have specialized treatments;
    /// otherwise delegate to PlayControlView.
    @ViewBuilder
    private func rightControl(episode: EpisodeRowSnapshot) -> some View {
        switch rowState {
        case .nowPlaying:
            Button(action: onPlay) {
                ZStack {
                    Circle().fill(Brand.Color.accent).frame(width: 38, height: 38)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.Color.paper)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .started:
            // Accent-outlined resume (distinct from unplayed's paper-ring play and played's transparent replay)
            Button(action: onPlay) {
                ZStack {
                    Circle().fill(Brand.Color.paper)
                        .overlay(Circle().strokeBorder(Brand.Color.accent, lineWidth: 1.5))
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.Color.accent)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .unplayed, .played:
            PlayControlView(
                episode: episode,
                isCurrent: false,
                isPlaying: false,
                onTap: onPlay
            )
        }
    }

    private var progressFraction: Double {
        snapshot.latestEpisode?.progressFraction ?? 0
    }

    private func minutesLeft(_ episode: EpisodeRowSnapshot) -> Int {
        let remaining = max(0, episode.totalDuration - episode.playbackPosition)
        return Int(remaining / 60)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// Small inline progress ring used in the started-row eyebrow.
private struct ProgressRing: View {
    let fraction: Double
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 1.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    let container = SampleData.container
    let podcasts = try! ModelContext(container).fetch(
        FetchDescriptor<Podcast>(sortBy: [SortDescriptor(\.sortPosition)])
    )
    return List {
        ForEach(podcasts) { podcast in
            PodcastRowView(snapshot: PodcastRowSnapshot(podcast), onPlay: {}, onOpenDetail: {})
                .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                .listRowSeparator(.hidden)
        }
    }
    .listStyle(.plain)
    .background(Brand.Color.bg)
    .modelContainer(container)
}
