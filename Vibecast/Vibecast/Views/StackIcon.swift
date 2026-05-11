import SwiftUI

/// Stack glyph used to open Manage Vibes from the home masthead. Matches the
/// StackIcon2 SVG in `docs/design/vibecast-visual-prototypes/project/
/// vibes-entry-v2.jsx`: a top-down view of three layered plates — top is a
/// closed diamond, the two below are open V-shapes that peek out from
/// underneath. Drawn in pure black so the icon reads as the primary
/// affordance for "manage vibes" without competing with the masthead's
/// vibe-tinted color band.
struct StackIcon: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            StackedPlatesShape()
                .stroke(
                    Color.black,
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 22, height: 22)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Manage vibes")
    }
}

/// SwiftUI translation of the StackIcon2 SVG path in vibes-entry-v2.jsx:
/// `M4 8 L12 4 L20 8 L12 12 Z` + `M4 13 L12 17 L20 13` + `M4 17 L12 21 L20 17`.
/// Scales the 24×24 viewBox into whatever rect SwiftUI hands us.
private struct StackedPlatesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 24
        let dx = rect.minX + (rect.width - scale * 24) / 2
        let dy = rect.minY + (rect.height - scale * 24) / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: dx + x * scale, y: dy + y * scale)
        }

        // Top closed diamond.
        path.move(to: pt(4, 8))
        path.addLine(to: pt(12, 4))
        path.addLine(to: pt(20, 8))
        path.addLine(to: pt(12, 12))
        path.closeSubpath()

        // Middle V — peek of the layer below the top.
        path.move(to: pt(4, 13))
        path.addLine(to: pt(12, 17))
        path.addLine(to: pt(20, 13))

        // Bottom V — peek of the bottom layer.
        path.move(to: pt(4, 17))
        path.addLine(to: pt(12, 21))
        path.addLine(to: pt(20, 17))

        return path
    }
}
