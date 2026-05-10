import SwiftUI

struct AddShowGhostRow: View {
    let vibeColorKey: VibeColorKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(vibeColorKey.band)
                Text("Add a show to this vibe")
                    .font(Brand.Font.uiBody(size: 14))
                    .foregroundStyle(vibeColorKey.ink)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .strokeBorder(
                        vibeColorKey.band,
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
