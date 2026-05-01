import SwiftUI

struct SearchResultRow: View {
    let result: PodcastSearchResult
    let isSubscribed: Bool
    let isInFlight: Bool
    var isFailed: Bool = false
    let onTapSubscribe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                CoverArtwork(
                    urlString: result.artworkURL?.absoluteString,
                    title: result.title,
                    size: 44,
                    radius: Brand.Radius.coverSmall
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.author)
                        .font(Brand.Font.monoEyebrow())
                        .tracking(Brand.Layout.monoTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Brand.Color.inkSecondary)
                        .lineLimit(1)
                    Text(result.title)
                        .font(Brand.Font.serifBody())
                        .foregroundStyle(Brand.Color.ink)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                subscribeButton
            }
            .padding(Brand.Layout.rowPadding)

            if isFailed {
                Text("Couldn't subscribe — tap to try again")
                    .font(Brand.Font.uiBody(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, Brand.Layout.rowPadding)
                    .padding(.bottom, 8)
            }
        }
    }

    private var subscribeAccessibilityLabel: String {
        if isSubscribed   { return "Already subscribed to \(result.title)" }
        if isInFlight     { return "Subscribing to \(result.title)" }
        if isFailed       { return "Couldn't subscribe to \(result.title), try again" }
        return "Subscribe to \(result.title)"
    }

    private var subscribeAccessibilityHint: String {
        if isSubscribed   { return "Already in your library" }
        if isInFlight     { return "Working on it" }
        if isFailed       { return "Tap to try again" }
        return "Adds this podcast to your library"
    }

    @ViewBuilder
    private var subscribeButton: some View {
        if isInFlight {
            ZStack {
                Circle()
                    .fill(Brand.Color.accent)
                    .frame(width: 30, height: 30)
                ProgressView()
                    .tint(Brand.Color.paper)
                    .controlSize(.small)
            }
            .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
            .contentShape(Rectangle())
            .accessibilityLabel(subscribeAccessibilityLabel)
            .accessibilityHint(subscribeAccessibilityHint)
        } else if isSubscribed {
            ZStack {
                Circle()
                    .fill(Brand.Color.accent)
                    .frame(width: 30, height: 30)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.Color.paper)
            }
            .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
            .contentShape(Rectangle())
            .accessibilityLabel(subscribeAccessibilityLabel)
            .accessibilityHint(subscribeAccessibilityHint)
        } else {
            // Idle or failed — paper ring + ink plus
            Button(action: onTapSubscribe) {
                ZStack {
                    Circle()
                        .fill(Brand.Color.paper)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                        )
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Brand.Color.ink)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(subscribeAccessibilityLabel)
            .accessibilityHint(subscribeAccessibilityHint)
        }
    }
}

#Preview {
    let example = PodcastSearchResult(
        id: 1,
        title: "Hard Fork",
        author: "The New York Times",
        artworkURL: nil,
        feedURL: URL(string: "https://x/")!
    )
    let failedExample = PodcastSearchResult(
        id: 2,
        title: "Radiolab",
        author: "WNYC Studios",
        artworkURL: nil,
        feedURL: URL(string: "https://y/")!
    )
    return List {
        SearchResultRow(result: example, isSubscribed: false, isInFlight: false, onTapSubscribe: {})
        SearchResultRow(result: example, isSubscribed: false, isInFlight: true, onTapSubscribe: {})
        SearchResultRow(result: example, isSubscribed: true, isInFlight: false, onTapSubscribe: {})
        SearchResultRow(result: failedExample, isSubscribed: false, isInFlight: false, isFailed: true, onTapSubscribe: {})
    }
    .listStyle(.plain)
    .background(Brand.Color.bg)
}
