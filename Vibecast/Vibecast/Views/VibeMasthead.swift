import SwiftUI
import SwiftData

/// Swipeable masthead carousel. Index 0 = All; indices 1...N map to the
/// vibes ordered by sortPosition. A change in `activeIndex` updates the
/// caller-bound `activeVibe` (nil for All, otherwise the vibe at index-1).
/// Swiping wraps circularly past either end.
struct VibeMasthead: View {
    let vibes: [Vibe]
    @Binding var activeVibe: Vibe?
    let onStartVibe: (Vibe) -> Void
    let onTapStack: () -> Void
    let onTapAdd: () -> Void

    @State private var activeIndex: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 50

    /// One slot per state — All + one per vibe.
    private var slotCount: Int { vibes.count + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow row + corner buttons.
            HStack(alignment: .center, spacing: 0) {
                eyebrow
                    .id("eyebrow-\(activeIndex)")
                    .transition(.opacity)
                Spacer()
                StackIcon(action: onTapStack)
                    .padding(.trailing, 4)
                AddIconButton(action: onTapAdd)
            }

            // Wordmark: "Vibecast" on All; vibe.name on a vibe.
            Text(wordmarkText)
                .font(Brand.Font.display(size: 56))
                .tracking(-1.4)
                .foregroundStyle(Brand.Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 10)
                .id("wordmark-\(activeIndex)")
                .transition(.opacity)

            // Subtitle (italic) — same shape on All and vibe state.
            Text(subtitleText)
                .font(Brand.Font.serifItalic(size: 18))
                .foregroundStyle(Brand.Color.inkSecondary)
                .padding(.top, 8)
                .id("subtitle-\(activeIndex)")
                .transition(.opacity)

            // Pagination dots.
            HStack(spacing: 6) {
                ForEach(0..<slotCount, id: \.self) { idx in
                    Circle()
                        .fill(idx == activeIndex ? dotActiveColor : Brand.Color.inkHairline)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 14)

            // "Start the vibe" CTA — only on a vibe state, sits below the dots.
            if let vibe = currentVibe {
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
                .padding(.top, 14)
                .id("cta-\(activeIndex)")
                .transition(.opacity)
            }
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
                    let step = dx < 0 ? 1 : -1
                    // Wrap circularly so end → beginning and vice versa.
                    let next = ((activeIndex + step) % slotCount + slotCount) % slotCount
                    withAnimation(.easeInOut(duration: 0.22)) {
                        activeIndex = next
                        activeVibe = currentVibe(at: next)
                    }
                }
        )
        .animation(.easeInOut(duration: 0.22), value: activeIndex)
    }

    // MARK: - Eyebrow

    @ViewBuilder
    private var eyebrow: some View {
        if let vibe = currentVibe {
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

    // MARK: - Derived text

    private var wordmarkText: String {
        currentVibe?.name ?? "Vibecast"
    }

    private var subtitleText: String {
        if let vibe = currentVibe {
            return vibeSubtitle(for: vibe)
        }
        return vibes.isEmpty ? "Add a podcast to get started" : "Your shows, in your order"
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
