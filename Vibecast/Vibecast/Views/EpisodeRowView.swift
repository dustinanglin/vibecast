import SwiftUI
import SwiftData

struct EpisodeRowView: View {
    let episode: Episode
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    let onPlay: () -> Void

    private enum RowState { case unplayed, started, nowPlaying, played }

    /// State precedence: now-playing wins; otherwise listenedStatus drives.
    private var rowState: RowState {
        if isCurrent { return .nowPlaying }
        switch episode.listenedStatus {
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

    /// Wraps the row content with the appropriate decoration.
    /// - now-playing → 2pt accent border + halo + top progress bar (NowPlayingCard). No sliver.
    /// - unplayed / started / played → paper card + hairline border. No sliver (sliver is
    ///   library-list-only; inside a single podcast's detail view all episodes share one show).
    @ViewBuilder
    private var cardWrapper: some View {
        switch rowState {
        case .nowPlaying:
            cardContent
                .nowPlayingCard(progressFraction: episode.progressFraction)
        case .unplayed, .started, .played:
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
            if rowState == .nowPlaying {
                nowPlayingLeftSlot
                    .frame(width: 28)
            }
            metadata
                .frame(maxWidth: .infinity, alignment: .leading)
            rightControl
        }
        .padding(Brand.Layout.rowPadding)
    }

    /// 20×20 accent circle with VU bars — only shown in now-playing state.
    private var nowPlayingLeftSlot: some View {
        ZStack {
            Circle()
                .fill(Brand.Color.accent)
                .frame(width: 20, height: 20)
            NowPlayingIndicator(isPlaying: isPlaying, color: Brand.Color.paper)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 3) {
            dateEyebrow
            titleText
                .frame(minHeight: 16 * 1.22 * 2, alignment: .topLeading)  // 2-line reservation
            footnote
        }
    }

    /// Eyebrow: relative publish date + optional explicit "E" badge.
    /// Started state: prepend progress ring + M LEFT.
    @ViewBuilder
    private var dateEyebrow: some View {
        switch rowState {
        case .started:
            HStack(spacing: 6) {
                ProgressRing(
                    fraction: episode.progressFraction,
                    size: 11,
                    color: Brand.Color.accent
                )
                Text("\(minutesLeft)M LEFT")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.accent)
                Text("·")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkFaint)
                Text(relativeDate)
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.inkMuted)
                    .lineLimit(1)
                if episode.isExplicit {
                    Text("E")
                        .font(Brand.Font.monoEyebrow())
                        .tracking(Brand.Layout.monoTracking)
                        .padding(.horizontal, 3)
                        .background(Brand.Color.inkHairline, in: RoundedRectangle(cornerRadius: 2))
                        .foregroundStyle(Brand.Color.inkSecondary)
                }
            }
        default:
            HStack(spacing: 6) {
                Text(relativeDate)
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

    /// Title typography differs in started state (Fraunces-Italic 300 at 78% ink).
    @ViewBuilder
    private var titleText: some View {
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

    /// Footnote: unplayed → TOTAL MIN; started → PAUSED AT NM · TOTAL MIN TOTAL;
    /// now-playing → TOTAL MIN · NM IN (elapsed in accent); played → ✓ PLAYED.
    @ViewBuilder
    private var footnote: some View {
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
            Text("PAUSED AT \(episode.formattedElapsed.uppercased()) · \(episode.formattedDuration.uppercased()) TOTAL")
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
        case .nowPlaying:
            HStack(spacing: 6) {
                Text(episode.formattedDuration.uppercased())
                    .foregroundStyle(Brand.Color.inkMuted)
                Text("·")
                    .foregroundStyle(Brand.Color.inkFaint)
                Text("\(episode.formattedElapsed.uppercased()) IN")
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

    /// Right-side control. now-playing → 38×38 accent-filled circle with pause/play.
    /// started → paper + accent border + arrow.clockwise.
    /// unplayed / played → delegate to PlayControlView.
    @ViewBuilder
    private var rightControl: some View {
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
            .accessibilityLabel(isPlaying ? "Pause \(episode.title)" : "Resume \(episode.title)")
        case .started:
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
            .accessibilityLabel("Resume \(episode.title)")
        case .unplayed, .played:
            PlayControlView(
                episode: EpisodeRowSnapshot(episode),
                isCurrent: false,
                isPlaying: false,
                onTap: onPlay
            )
        }
    }

    // MARK: - Helpers

    private var minutesLeft: Int {
        let remaining = max(0, Double(episode.durationSeconds) - episode.playbackPosition)
        return Int(remaining / 60)
    }

    private var relativeDate: String {
        Self.relativeDateFormatter.localizedString(for: episode.publishDate, relativeTo: .now)
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
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
    let episodes = try! ModelContext(container).fetch(
        FetchDescriptor<Episode>(sortBy: [SortDescriptor(\.publishDate, order: .reverse)])
    )
    return List {
        ForEach(episodes.prefix(6)) { ep in
            EpisodeRowView(episode: ep, onPlay: {})
                .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                .listRowSeparator(.hidden)
                .listRowBackground(Brand.Color.bg)
        }
    }
    .listStyle(.plain)
    .background(Brand.Color.bg)
    .modelContainer(container)
}
