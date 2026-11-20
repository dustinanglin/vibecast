import SwiftUI
import SwiftData

/// The second pane on an open iPhone Duo: Now Playing by default, a show's
/// episodes when one is opened from the Library.
struct StageView: View {
    let content: StageContent
    let player: PlayerManager?
    /// Shown inside the pane when there is no side bar to hold Close.
    let showsInlineClose: Bool
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Brand.Color.paper
                .ignoresSafeArea()

            switch content {
            case .empty:
                emptyState
            case .nowPlaying:
                if let player {
                    NowPlayingPanel(player: player)
                } else {
                    emptyState
                }
            case .show(let podcast):
                PodcastDetailView(podcast: podcast, embedsInNavigationStack: false)
                    .id(podcast.persistentModelID)
                if showsInlineClose {
                    closeButton
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            HStack(spacing: 5) {
                ForEach(VibeColorKey.allCases, id: \.self) { key in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(key.band)
                        .frame(width: 6, height: 34)
                }
            }
            Text("Pick your vibe.")
                .font(Brand.Font.serifItalic(size: 20))
                .foregroundStyle(Brand.Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Brand.Color.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Brand.Color.bg))
                .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                .frame(width: Brand.HitTarget.min, height: Brand.HitTarget.min)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .padding(.trailing, 10)
        .accessibilityLabel("Close show")
    }
}
