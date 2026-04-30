import SwiftUI

/// A 3pt-wide vertical bar drawn at the leading edge of an unplayed row.
/// Color in Phase 1 = Brand.fallbackColor(for: podcast.title) — per-show
/// deterministic; produces a chromatic column down the library list.
/// In Plan 7 (Vibes), color becomes the show's primary vibe color.
struct RowSliver: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 3)
    }
}

#Preview {
    HStack(spacing: 0) {
        RowSliver(color: Brand.fallbackColor(for: "Hard Fork"))
        Rectangle().fill(Brand.Color.paper).frame(height: 76).overlay(Text("row content").foregroundStyle(Brand.Color.ink))
    }
    .frame(height: 76)
    .background(Brand.Color.bg)
}
