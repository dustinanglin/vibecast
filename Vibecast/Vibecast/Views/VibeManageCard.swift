import SwiftUI

struct VibeManageCard: View {
    let vibe: Vibe
    let isEditing: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if isEditing {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            coverStack

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(vibe.colorKey.ink.opacity(0.7))
                Text(vibe.name)
                    .font(Brand.Font.serifTitle(size: 24))
                    .foregroundStyle(vibe.colorKey.ink)
            }
            Spacer()
            // System EditMode draws its own drag handle on the trailing edge
            // when the parent's editMode is .active and the ForEach has
            // .onMove, so we don't render a decorative one ourselves.
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.card).fill(vibe.colorKey.chip)
        )
        .contentShape(Rectangle())
        .onTapGesture { if !isEditing { onTap() } }
    }

    private var eyebrow: String {
        let count = vibe.memberships.count
        return count == 1 ? "1 SHOW" : "\(count) SHOWS"
    }

    private var coverStack: some View {
        let podcasts = vibe.memberships
            .sorted(by: { $0.position < $1.position })
            .prefix(3)
            .compactMap { $0.podcast }

        return ZStack {
            ForEach(Array(podcasts.enumerated()), id: \.offset) { idx, podcast in
                CoverArtwork(
                    urlString: podcast.artworkURL,
                    title: podcast.title,
                    size: 44,
                    radius: 4
                )
                .rotationEffect(.degrees(Double(idx - 1) * 6))
                .offset(x: CGFloat(idx) * 6)
            }
        }
        .frame(width: 64, height: 44)
    }
}
