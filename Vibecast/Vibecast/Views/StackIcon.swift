// Vibecast/Vibecast/Views/StackIcon.swift
import SwiftUI

/// Three-layer plate icon used to enter Manage Vibes from the home masthead.
/// Visual based on `vibes-entry-v2.jsx`'s StackIcon2.
struct StackIcon: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Brand.Color.paper)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth)
                    )
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1).frame(width: 14, height: 2)
                    RoundedRectangle(cornerRadius: 1).frame(width: 16, height: 2)
                    RoundedRectangle(cornerRadius: 1).frame(width: 14, height: 2)
                }
                .foregroundStyle(Brand.Color.ink)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Manage vibes")
    }
}
