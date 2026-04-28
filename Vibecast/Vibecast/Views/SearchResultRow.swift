import SwiftUI

struct SearchResultRow: View {
    let result: PodcastSearchResult
    let isSubscribed: Bool
    let isInFlight: Bool
    var isFailed: Bool = false
    let onTapSubscribe: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                Text(result.author)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if isFailed {
                    Text("Couldn't add — try again")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 8)
            subscribeButton
        }
        .padding(.vertical, 4)
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.25))
            .frame(width: 52, height: 52)
            .overlay {
                if let url = result.artworkURL {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "mic.fill").foregroundStyle(.tertiary)
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
            ProgressView()
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(subscribeAccessibilityLabel)
                .accessibilityHint(subscribeAccessibilityHint)
        } else if isSubscribed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(subscribeAccessibilityLabel)
                .accessibilityHint(subscribeAccessibilityHint)
        } else {
            Button(action: onTapSubscribe) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 44, minHeight: 44)
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
    return List {
        SearchResultRow(result: example, isSubscribed: false, isInFlight: false, onTapSubscribe: {})
        SearchResultRow(result: example, isSubscribed: false, isInFlight: true, onTapSubscribe: {})
        SearchResultRow(result: example, isSubscribed: true, isInFlight: false, onTapSubscribe: {})
    }
}
