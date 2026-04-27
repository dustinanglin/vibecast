import SwiftUI
import SwiftData

struct MiniPlayerBar: View {
    let player: PlayerManager
    let onTapBar: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            artwork
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentEpisode?.title ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                progressRow
            }

            playPauseButton

            skipForwardButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTapBar)
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.25))
            .overlay {
                if let urlString = player.currentEpisode?.podcast?.artworkURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.tertiary)
                }
            }
    }

    private var progressRow: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 2)

            HStack {
                Text(format(player.elapsed))
                Spacer()
                Text("-" + format(max(0, player.duration - player.elapsed)))
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
    }

    private var playPauseButton: some View {
        Button {
            player.togglePlayPause()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 22))
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
    }

    private var skipForwardButton: some View {
        Button {
            player.skipForward()
        } label: {
            Image(systemName: "goforward.30")
                .font(.system(size: 22))
        }
        .buttonStyle(.plain)
        .frame(width: 32, height: 32)
    }

    private var progressFraction: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.elapsed / player.duration, 0), 1)
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
            engine.simulateTime(120)
        }
        return mgr
    }()

    return VStack {
        Spacer()
        MiniPlayerBar(player: player, onTapBar: {})
    }
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
