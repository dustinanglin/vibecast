import SwiftUI
import SwiftData

struct FullScreenPlayerView: View {
    let player: PlayerManager

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
                    .padding(.bottom, 4)

                NowPlayingPanel(player: player)
            }
        }
        .presentationDragIndicator(.hidden)
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
