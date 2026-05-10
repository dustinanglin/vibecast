import SwiftUI
import SwiftData

/// Swipeable masthead carousel. Index 0 = All; indices 1...N map to the
/// vibes ordered by sortPosition. A change in `activeIndex` updates the
/// caller-bound `activeVibe` (nil for All, otherwise the vibe at index-1).
/// Swiping wraps circularly past either end.
///
/// Layout: the editorial column (eyebrow / wordmark / subtitle / CTA) lives
/// in horizontally-stacked per-slot panels that slide as a unit so the
/// transition feels like a carousel rather than a cross-fade. The corner
/// buttons and pagination dots are pinned. The background color band fades
/// implicitly on activeIndex change.
struct VibeMasthead: View {
    let vibes: [Vibe]
    @Binding var activeVibe: Vibe?
    let onStartVibe: (Vibe) -> Void
    let onTapStack: () -> Void
    let onTapAdd: () -> Void

    @State private var activeIndex: Int = 0
    @State private var contentWidth: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 50

    private var slotCount: Int { vibes.count + 1 } // All + N vibes

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: eyebrow (sliding) with pinned corner buttons overlaid right.
            ZStack(alignment: .topTrailing) {
                slidingRow { idx in
                    eyebrowContent(at: idx)
                }
                .frame(height: 22, alignment: .leading)

                HStack(spacing: 4) {
                    StackIcon(action: onTapStack)
                    AddIconButton(action: onTapAdd)
                }
                .offset(y: -8) // re-center 44pt buttons against the 22pt eyebrow
            }

            // Row 2: wordmark (sliding).
            slidingRow { idx in
                wordmarkContent(at: idx)
            }
            .frame(height: 64, alignment: .leading)
            .padding(.top, 10)

            // Row 3: subtitle (sliding).
            slidingRow { idx in
                subtitleContent(at: idx)
            }
            .frame(height: 24, alignment: .leading)
            .padding(.top, 8)

            // Row 4: pagination dots (pinned).
            HStack(spacing: 6) {
                ForEach(0..<slotCount, id: \.self) { idx in
                    Circle()
                        .fill(idx == activeIndex ? dotActiveColor : Brand.Color.inkHairline)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 14)

            // Row 5: CTA (sliding; empty space reserved for All so masthead height is stable).
            slidingRow { idx in
                ctaContent(at: idx)
            }
            .frame(height: 40, alignment: .leading)
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
        .background(
            // Measure the column's available width so slot widths line up.
            GeometryReader { proxy in
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: proxy.size.width - 44)
            }
        )
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            contentWidth = width
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let dx = value.translation.width
                    guard abs(dx) > swipeThreshold else { return }
                    let step = dx < 0 ? 1 : -1
                    let next = ((activeIndex + step) % slotCount + slotCount) % slotCount
                    withAnimation(.easeInOut(duration: 0.28)) {
                        activeIndex = next
                        activeVibe = currentVibe(at: next)
                    }
                }
        )
        .animation(.easeInOut(duration: 0.28), value: activeIndex)
    }

    // MARK: - Sliding row helper

    @ViewBuilder
    private func slidingRow<Content: View>(
        @ViewBuilder content: @escaping (Int) -> Content
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<slotCount, id: \.self) { idx in
                content(idx)
                    .frame(width: contentWidth, alignment: .leading)
            }
        }
        .offset(x: -CGFloat(activeIndex) * contentWidth + dragOffset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    // MARK: - Per-slot content

    @ViewBuilder
    private func eyebrowContent(at index: Int) -> some View {
        if let vibe = currentVibe(at: index) {
            HStack(spacing: 7) {
                Circle()
                    .fill(vibe.colorKey.band)
                    .frame(width: 8, height: 8)
                Text("VIBE")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(vibe.colorKey.ink)
            }
        } else {
            Text("SUBSCRIPTIONS")
                .font(Brand.Font.monoEyebrow())
                .tracking(Brand.Layout.monoTracking)
                .foregroundStyle(Brand.Color.inkMuted)
        }
    }

    @ViewBuilder
    private func wordmarkContent(at index: Int) -> some View {
        Text(currentVibe(at: index)?.name ?? "Vibecast")
            .font(Brand.Font.display(size: 56))
            .tracking(-1.4)
            .foregroundStyle(Brand.Color.ink)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func subtitleContent(at index: Int) -> some View {
        Text(subtitleText(at: index))
            .font(Brand.Font.serifItalic(size: 18))
            .foregroundStyle(Brand.Color.inkSecondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private func ctaContent(at index: Int) -> some View {
        if let vibe = currentVibe(at: index) {
            Button {
                onStartVibe(vibe)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Start the vibe")
                        .font(Brand.Font.uiBody(size: 15, weight: .semibold))
                }
                .foregroundStyle(Brand.Color.paper)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(vibe.colorKey.band))
            }
            .buttonStyle(.plain)
        } else {
            // Reserve the row's vertical space so the masthead height stays stable.
            Color.clear
        }
    }

    // MARK: - Derived text

    private func subtitleText(at index: Int) -> String {
        if let vibe = currentVibe(at: index) {
            return vibeSubtitle(for: vibe)
        }
        return vibes.isEmpty ? "Add a podcast to get started" : "Your shows, in your order"
    }

    /// "N shows, in order. About N.Nhrs" — count of memberships + total
    /// unplayed time across the vibe's queue. Falls back to "All caught up."
    /// when nothing remains.
    private func vibeSubtitle(for vibe: Vibe) -> String {
        let count = vibe.memberships.count
        let showCopy = count == 1 ? "1 show, in order." : "\(count) shows, in order."
        let unplayedSeconds = vibe.memberships
            .compactMap { $0.podcast }
            .compactMap { VibeQueueResolver.latestUnplayedEpisode(in: $0) }
            .reduce(0.0) { partial, episode in
                let remaining = Double(episode.durationSeconds) - episode.playbackPosition
                return partial + max(0, remaining)
            }
        guard unplayedSeconds > 0 else { return showCopy + " All caught up." }
        let hours = unplayedSeconds / 3600.0
        let timeCopy: String
        if hours >= 1.0 {
            timeCopy = String(format: "About %.1fhrs", hours)
        } else {
            let minutes = Int((unplayedSeconds / 60).rounded())
            timeCopy = "About \(minutes)m"
        }
        return "\(showCopy) \(timeCopy)"
    }

    private var currentVibe: Vibe? {
        currentVibe(at: activeIndex)
    }

    private func currentVibe(at index: Int) -> Vibe? {
        guard index > 0 else { return nil }
        let i = index - 1
        return i < vibes.count ? vibes[i] : nil
    }

    private var dotActiveColor: Color {
        currentVibe?.colorKey.band ?? Brand.Color.ink
    }
}

// MARK: - Width measurement key

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
