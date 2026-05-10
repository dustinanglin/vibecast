// Vibecast/Vibecast/Views/VibeMasthead.swift
import SwiftUI
import SwiftData

/// Swipeable masthead carousel. Index 0 = All; indices 1...N map to the
/// vibes ordered by sortPosition. A change in `activeIndex` updates the
/// caller-bound `activeVibe` (nil for All, otherwise the vibe at index-1).
struct VibeMasthead: View {
    let vibes: [Vibe]
    @Binding var activeVibe: Vibe?
    let onStartVibe: (Vibe) -> Void
    let onTapStack: () -> Void
    let onTapAdd: () -> Void

    @State private var activeIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 50

    private var maxIndex: Int { vibes.count } // 0 (All) + N vibes

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow row + corner buttons.
            HStack(alignment: .center) {
                Text(eyebrowText)
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(eyebrowColor)
                    .id("eyebrow-\(activeIndex)")
                    .transition(.opacity)
                Spacer()
                StackIcon(action: onTapStack)
                    .padding(.trailing, 4)
                AddIconButton(action: onTapAdd)
            }

            Text("Vibecast")
                .font(Brand.Font.display(size: 56))
                .tracking(-1.4)
                .foregroundStyle(Brand.Color.ink)
                .padding(.top, 10)

            // Subtitle row: italic on All, CTA on a vibe.
            ZStack(alignment: .leading) {
                if let vibe = currentVibe {
                    Button {
                        onStartVibe(vibe)
                    } label: {
                        Text("Start the vibe")
                            .font(Brand.Font.uiButton(size: 14))
                            .foregroundStyle(vibe.colorKey.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(vibe.colorKey.chip))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Your shows, in your order")
                        .font(Brand.Font.serifItalic(size: 18))
                        .foregroundStyle(Brand.Color.inkSecondary)
                }
            }
            .padding(.top, 8)

            // Pagination dots.
            HStack(spacing: 6) {
                ForEach(0...maxIndex, id: \.self) { idx in
                    Circle()
                        .fill(idx == activeIndex ? dotActiveColor : Brand.Color.inkHairline)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 14)
        .background(
            // Color band: vibe.chip at top fading to bg at bottom.
            currentVibe.map { vibe in
                LinearGradient(
                    colors: [vibe.colorKey.chip, Brand.Color.bg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let dx = value.translation.width
                    guard abs(dx) > swipeThreshold else { return }
                    let target = dx < 0 ? activeIndex + 1 : activeIndex - 1
                    let clamped = max(0, min(maxIndex, target))
                    withAnimation(.easeInOut(duration: 0.22)) {
                        activeIndex = clamped
                        activeVibe = currentVibe
                    }
                }
        )
        .animation(.easeInOut(duration: 0.18), value: activeIndex)
    }

    private var currentVibe: Vibe? {
        guard activeIndex > 0 else { return nil }
        let i = activeIndex - 1
        return i < vibes.count ? vibes[i] : nil
    }

    private var eyebrowText: String {
        if let vibe = currentVibe { return vibe.name.uppercased() }
        return "SUBSCRIPTIONS"
    }

    private var eyebrowColor: Color {
        if let vibe = currentVibe { return vibe.colorKey.ink }
        return Brand.Color.inkMuted
    }

    private var dotActiveColor: Color {
        currentVibe?.colorKey.band ?? Brand.Color.ink
    }
}

// Existing add button styling pulled out so VibeMasthead can reuse it.
private struct AddIconButton: View {
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
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Brand.Color.ink)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add podcast")
    }
}

// NOTE: A #Preview block is welcome but not required if SampleData.container
// doesn't ship with vibes seeded. The masthead will be visually verified
// once SubscriptionsListView wires it in (Task 9). Leaving a #Preview in
// the file is fine if it builds.
