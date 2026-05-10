import SwiftUI
import SwiftData

/// Swipeable masthead. The wordmark slides horizontally between slots (All
/// plus one per vibe); the rest of the masthead (subtitle, pagination dots,
/// CTA pill) stays pinned and updates with quick cross-fades on state change.
/// Swiping wraps circularly past either end. Background color band fades
/// implicitly on `activeIndex` change.
struct VibeMasthead: View {
    let vibes: [Vibe]
    @Binding var activeVibe: Vibe?
    let onStartVibe: (Vibe) -> Void
    let onStartAll: () -> Void
    let onTapStack: () -> Void
    let onTapAdd: () -> Void

    @State private var activeIndex: Int = 0
    /// Width of one slot, measured at first layout via PreferenceKey.
    /// Seeded with a sane iPhone default so first-render shows the wordmark
    /// at correct position rather than collapsed to zero-width.
    @State private var slotWidth: CGFloat = 320
    @GestureState private var dragOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 50

    private var slotCount: Int { vibes.count + 1 } // All + N vibes

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: corner buttons pinned right (no eyebrow text — moved to
            // the section label above the list).
            HStack {
                Spacer()
                StackIcon(action: onTapStack)
                    .padding(.trailing, 4)
                AddIconButton(action: onTapAdd)
            }
            .frame(height: 44)

            // Row 2: wordmark — the only thing that slides on swipe.
            HStack(spacing: 0) {
                ForEach(0..<slotCount, id: \.self) { idx in
                    Text(wordmark(at: idx))
                        .font(Brand.Font.display(size: 56))
                        .tracking(-1.4)
                        .foregroundStyle(Brand.Color.ink)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: slotWidth, alignment: .leading)
                }
            }
            .offset(x: -CGFloat(activeIndex) * slotWidth + dragOffset)
            .frame(width: slotWidth, alignment: .leading)
            .clipped()

            // Row 3: subtitle — fades on state change.
            Text(subtitleText)
                .font(Brand.Font.serifItalic(size: 18))
                .foregroundStyle(Brand.Color.inkSecondary)
                .lineLimit(1)
                .id("subtitle-\(activeIndex)")
                .transition(.opacity)
                .padding(.top, 8)

            // Row 4: pagination dots — pinned, active dot tinted by state.
            HStack(spacing: 6) {
                ForEach(0..<slotCount, id: \.self) { idx in
                    Circle()
                        .fill(idx == activeIndex ? dotActiveColor : Brand.Color.inkHairline)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 14)

            // Row 5: Start pill — always present so the masthead height
            // doesn't change between states. Color and copy adapt.
            Button {
                if let vibe = currentVibe {
                    onStartVibe(vibe)
                } else {
                    onStartAll()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(ctaText)
                        .font(Brand.Font.uiBody(size: 15, weight: .semibold))
                }
                .foregroundStyle(Brand.Color.paper)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(ctaBackgroundColor))
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .id("cta-\(activeIndex)")
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
            // Measure slot width = available content width inside the 22pt padding.
            GeometryReader { proxy in
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: proxy.size.width - 44)
            }
        )
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            guard width > 0 else { return }
            slotWidth = width
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

    // MARK: - Derived state

    private func wordmark(at index: Int) -> String {
        currentVibe(at: index)?.name ?? "Vibecast"
    }

    private var subtitleText: String {
        if let vibe = currentVibe {
            return vibeSubtitle(for: vibe)
        }
        return vibes.isEmpty ? "Add a podcast to get started" : "Your shows, in your order"
    }

    private var ctaText: String {
        currentVibe == nil ? "Start listening" : "Start the vibe"
    }

    private var ctaBackgroundColor: Color {
        currentVibe?.colorKey.band ?? Brand.Color.ink
    }

    private var dotActiveColor: Color {
        currentVibe?.colorKey.band ?? Brand.Color.ink
    }

    /// "N shows, in order. About N.Nhrs" — count of memberships + total
    /// unplayed time across the vibe's queue.
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
