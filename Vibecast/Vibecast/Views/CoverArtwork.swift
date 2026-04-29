import SwiftUI

/// Renders a podcast's cover artwork. Falls back to a colored square with
/// serif initials when the URL is missing or fails to load.
struct CoverArtwork: View {
    let urlString: String?
    let title: String
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        InitialsTile(title: title, size: size, radius: radius)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        InitialsTile(title: title, size: size, radius: radius)
                    @unknown default:
                        InitialsTile(title: title, size: size, radius: radius)
                    }
                }
            } else {
                InitialsTile(title: title, size: size, radius: radius)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

private struct InitialsTile: View {
    let title: String
    let size: CGFloat
    let radius: CGFloat

    /// Initial size scales: 16pt at 44, 38pt at 120, 80pt at 280.
    private var initialFontSize: CGFloat { size * 0.36 }

    var body: some View {
        ZStack {
            Brand.fallbackColor(for: title)
            Text(Brand.initials(for: title))
                .font(Brand.Font.serifTitle(size: initialFontSize))
                .foregroundStyle(Brand.Color.paper)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

#Preview {
    VStack(spacing: 16) {
        CoverArtwork(urlString: nil, title: "Hard Fork", size: 44, radius: 4)
        CoverArtwork(urlString: nil, title: "The Daily", size: 120, radius: 6)
        CoverArtwork(urlString: nil, title: "99% Invisible", size: 280, radius: 8)
    }
    .padding()
    .background(Brand.Color.bg)
}
