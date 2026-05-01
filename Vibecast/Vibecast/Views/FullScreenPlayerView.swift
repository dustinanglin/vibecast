import SwiftUI
import SwiftData

struct FullScreenPlayerView: View {
    let player: PlayerManager

    /// Non-nil while the user is dragging the scrubber.
    @State private var scrubValue: Double?

    init(player: PlayerManager) {
        self.player = player
    }

    var body: some View {
        ZStack {
            Brand.Color.bg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag-down handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Brand.Color.inkHairline)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // "Now Playing" eyebrow
                Text("Now Playing")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(Brand.Color.inkSecondary)
                    .padding(.bottom, 20)

                // 280×280 cover artwork with shadow
                CoverArtwork(
                    urlString: player.currentEpisode?.podcast?.artworkURL,
                    title: player.currentEpisode?.podcast?.title ?? "",
                    size: 280,
                    radius: Brand.Radius.coverLarge
                )
                .shadow(color: .black.opacity(0.10), radius: 20, y: 8)
                .padding(.bottom, 24)

                // Podcast name + episode title
                VStack(spacing: 6) {
                    Text(player.currentEpisode?.podcast?.title ?? "")
                        .font(Brand.Font.monoEyebrowLarge())
                        .tracking(Brand.Layout.monoTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Brand.Color.inkSecondary)
                        .lineLimit(1)

                    Text(player.currentEpisode?.title ?? "")
                        .font(Brand.Font.serifTitle(size: 28))
                        .foregroundStyle(Brand.Color.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                // Scrubber
                scrubber
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                // Transport controls
                transportControls
                    .padding(.bottom, 32)

                // System volume
                SystemVolumeView()
                    .frame(height: 44)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Subviews

    private var scrubber: some View {
        VStack(spacing: 6) {
            // Native Slider provides drag-to-seek behavior; rendered nearly transparent
            // and layered behind a custom hairline+thumb visual that mirrors its value.
            // The Slider intercepts touches; the custom visual is purely cosmetic.
            ZStack {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Hairline track
                        Rectangle()
                            .fill(Brand.Color.inkHairline)
                            .frame(height: Brand.Layout.hairlineWidth)
                        // Accent-filled progress
                        Rectangle()
                            .fill(Brand.Color.accent)
                            .frame(width: max(0, geo.size.width * scrubFraction), height: Brand.Layout.hairlineWidth)
                        // Visual thumb (no hit testing — Slider handles touches)
                        Circle()
                            .fill(Brand.Color.accent)
                            .frame(width: 14, height: 14)
                            .offset(x: max(0, min(geo.size.width * scrubFraction - 7, geo.size.width - 14)))
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .allowsHitTesting(false)

                Slider(
                    value: Binding(
                        get: { scrubValue ?? player.elapsed },
                        set: { scrubValue = $0 }
                    ),
                    in: 0...(max(player.duration, 1)),
                    onEditingChanged: { isEditing in
                        if !isEditing, let v = scrubValue {
                            player.seek(to: v)
                            scrubValue = nil
                        }
                    }
                )
                .opacity(0.001)
            }
            .frame(height: 32)

            // Time labels
            HStack {
                Text(format(scrubValue ?? player.elapsed))
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkSecondary)
                Spacer()
                Text("-" + format(max(0, player.duration - (scrubValue ?? player.elapsed))))
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkSecondary)
            }
        }
    }

    private var scrubFraction: Double {
        let value = scrubValue ?? player.elapsed
        guard player.duration > 0 else { return 0 }
        return min(max(value / player.duration, 0), 1)
    }

    private var transportControls: some View {
        HStack(spacing: 24) {
            // Skip-back-15 (56×56)
            Button {
                player.skipBack()
            } label: {
                ZStack {
                    Circle()
                        .fill(Brand.Color.paper)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Brand.Color.ink)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Primary play/pause (70×70)
            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    if player.isPlaying {
                        Circle()
                            .fill(Brand.Color.accent)
                            .frame(width: 56, height: 56)
                        Image(systemName: "pause.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Brand.Color.paper)
                    } else {
                        Circle()
                            .fill(Brand.Color.paper)
                            .frame(width: 56, height: 56)
                            .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Brand.Color.ink)
                    }
                }
                .frame(width: Brand.HitTarget.primaryPlay, height: Brand.HitTarget.primaryPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Skip-forward-30 (56×56)
            Button {
                player.skipForward()
            } label: {
                ZStack {
                    Circle()
                        .fill(Brand.Color.paper)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                    Image(systemName: "goforward.30")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Brand.Color.ink)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
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
            engine.simulateTime(300)
        }
        return mgr
    }()

    return FullScreenPlayerView(player: player)
}

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
