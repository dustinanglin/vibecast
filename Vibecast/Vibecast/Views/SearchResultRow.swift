import SwiftUI

struct SearchResultRow: View {
    let result: PodcastSearchResult
    let isSubscribed: Bool
    let isInFlight: Bool
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

    @ViewBuilder
    private var subscribeButton: some View {
        if isSubscribed {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
                .frame(width: 36, height: 36)
        } else if isInFlight {
            ProgressView()
                .frame(width: 36, height: 36)
        } else {
            Button(action: onTapSubscribe) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
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
