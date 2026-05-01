import SwiftUI
import SwiftData

struct MiniPlayerBar: View {
    let player: PlayerManager
    let onTapBar: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main card content
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Left: 44×44 cover artwork
                    CoverArtwork(
                        urlString: player.currentEpisode?.podcast?.artworkURL,
                        title: player.currentEpisode?.podcast?.title ?? "",
                        size: 44,
                        radius: Brand.Radius.coverSmall
                    )

                    // Center: podcast title + episode title
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.currentEpisode?.podcast?.title ?? "")
                            .font(Brand.Font.monoEyebrow())
                            .tracking(Brand.Layout.monoTracking)
                            .textCase(.uppercase)
                            .foregroundStyle(Brand.Color.inkSecondary)
                            .lineLimit(1)
                        Text(player.currentEpisode?.title ?? "")
                            .font(Brand.Font.serifBody())
                            .foregroundStyle(Brand.Color.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Right: skip-back + play/pause + skip-forward
                    HStack(spacing: 0) {
                        Button {
                            player.skipBack()
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Brand.Color.ink)
                                .frame(width: Brand.HitTarget.min, height: Brand.HitTarget.min)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            player.togglePlayPause()
                        } label: {
                            ZStack {
                                if player.isPlaying {
                                    Circle()
                                        .fill(Brand.Color.accent)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "pause.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Brand.Color.paper)
                                } else {
                                    Circle()
                                        .fill(Brand.Color.paper)
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Brand.Color.ink)
                                }
                            }
                            .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            player.skipForward()
                        } label: {
                            Image(systemName: "goforward.30")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Brand.Color.ink)
                                .frame(width: Brand.HitTarget.min, height: Brand.HitTarget.min)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                // Reserve 2pt for the progress sliver at the bottom
                .padding(.bottom, 2)
            }

            // Bottom edge: 2pt accent progress sliver across full width
            GeometryReader { geo in
                Rectangle()
                    .fill(Brand.Color.accent)
                    .frame(width: max(0, geo.size.width * progressFraction), height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 2)
        }
        .background(Brand.Color.paper.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.card)
                .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
        )
        .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapBar)
    }

    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.elapsed / player.duration, 0), 1)
    }
}

#Preview {
    @Previewable @State var player: PlayerManager = {
        let container = SampleData.container
        let context = ModelContext(container)
        let episodes = try! context.fetch(FetchDescriptor<Episode>())
        let engine = PreviewAudioEngine()
        let mgr = PlayerManager(engine: engine, modelContext: context, nowPlaying: NowPlayingService())
        if let ep = episodes.first {
            mgr.play(ep)
            engine.simulateTime(120)
        }
        return mgr
    }()

    return VStack {
        Spacer()
        MiniPlayerBar(player: player, onTapBar: {})
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
    }
    .background(Brand.Color.bg)
}

/// Preview-only engine so the mini-player renders with a non-zero elapsed/duration.
@MainActor
private final class PreviewAudioEngine: AudioEngine {
    var isPlaying: Bool = true
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 1800
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onPlaybackEnd: (() -> Void)?
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEndedShouldResume: (() -> Void)?
    var onRouteOldDeviceUnavailable: (() -> Void)?
    func load(url: URL, startAt: TimeInterval) { currentTime = startAt }
    func play() { isPlaying = true }
    func pause() { isPlaying = false }
    func seek(to: TimeInterval) { currentTime = to }
    func simulateTime(_ t: TimeInterval) { currentTime = t; onTimeUpdate?(t) }
}
