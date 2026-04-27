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
        VStack(spacing: 0) {
            Text("Now Playing")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Spacer(minLength: 24)

            artwork

            Spacer(minLength: 20)

            VStack(spacing: 4) {
                Text(player.currentEpisode?.title ?? "")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(player.currentEpisode?.podcast?.title ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)

            scrubber
                .padding(.horizontal, 32)

            Spacer(minLength: 20)

            transportControls

            Spacer(minLength: 28)

            SystemVolumeView()
                .frame(height: 44)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 280, height: 280)
            .overlay {
                if let urlString = player.currentEpisode?.podcast?.artworkURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)
                }
            }
            .shadow(radius: 12, y: 6)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
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

            HStack {
                Text(format(scrubValue ?? player.elapsed))
                Spacer()
                Text("-" + format(max(0, player.duration - (scrubValue ?? player.elapsed))))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button {
                player.skipBack()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 32))
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .buttonStyle(.plain)

            Button {
                player.skipForward()
            } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 32))
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
        let mgr = PlayerManager(engine: engine, modelContext: context)
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
