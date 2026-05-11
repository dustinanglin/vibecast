import SwiftUI
import SwiftData

/// Swipeable masthead. The wordmark slides horizontally between slots (All
/// plus one per vibe) on an infinite carousel — swiping past either end
/// loops cleanly back to the other side. The eyebrow, subtitle, pagination
/// dots, and CTA pill stay pinned and cross-fade on state change. The
/// background color band fades implicitly on `activeIndex` change.
///
/// **Infinite carousel mechanics.** The wordmark HStack contains `slotCount + 2`
/// panels — a phantom of the last real slot at position 0, the real slots at
/// positions 1..slotCount, and a phantom of the first real slot at position
/// slotCount+1. The visible offset uses `displayIndex` (the position in the
/// padded array). Logical state (`activeVibe`, dot color, subtitle, CTA) is
/// derived from `logicalIndex(for: displayIndex)`. When a swipe lands on a
/// phantom, we let the slide animation play through, then jump displayIndex
/// to the mirror position without animation. The user never sees the seam.
struct VibeMasthead: View {
    let vibes: [Vibe]
    @Binding var activeVibe: Vibe?
    /// The vibe currently driving the player's queue, if any. Used so the
    /// masthead's CTA can morph into a pause/resume control when the
    /// currently-viewed vibe is also the one playing.
    let queueSourceVibe: Vibe?
    /// Whether the player is currently playing right now.
    let isPlaying: Bool
    let onStartVibe: (Vibe) -> Void
    let onStartAll: () -> Void
    /// Tap action when the CTA is in pause/resume mode (queue source matches
    /// the currently-displayed vibe). Caller wires this to togglePlayPause.
    let onToggleVibe: () -> Void
    let onTapStack: () -> Void
    let onTapAdd: () -> Void

    /// 1-based index into the padded HStack. Real range is 1...slotCount;
    /// 0 and slotCount+1 are phantoms used during wrap animations.
    @State private var displayIndex: Int = 1
    /// Width of one slot, measured at first layout via PreferenceKey.
    /// Seeded with a sane iPhone default so first render isn't collapsed.
    @State private var slotWidth: CGFloat = 320
    @GestureState private var dragOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 50

    private var slotCount: Int { vibes.count + 1 } // All + N vibes

    /// Logical slot index (0...slotCount-1) for a given padded position.
    private func logicalIndex(for display: Int) -> Int {
        if display == 0 { return slotCount - 1 }       // left phantom mirrors last real
        if display == slotCount + 1 { return 0 }       // right phantom mirrors first real
        return display - 1
    }

    /// Wordmark for a padded slot. Position 0 mirrors the last real slot;
    /// position slotCount+1 mirrors the first real slot.
    private func paddedWordmark(at paddedIndex: Int) -> String {
        wordmark(at: logicalIndex(for: paddedIndex))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: eyebrow + corner buttons. Eyebrow fade-transitions on
            // state change; corner buttons stay pinned right.
            ZStack(alignment: .topTrailing) {
                eyebrow
                    .id("eyebrow-\(activeIndex)")
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    StackIcon(action: onTapStack)
                    AddIconButton(action: onTapAdd)
                }
                .offset(y: -8) // center 44pt buttons against the 22pt eyebrow
            }

            // Row 2: wordmark — infinite-carousel sliding HStack.
            HStack(spacing: 0) {
                ForEach(0..<(slotCount + 2), id: \.self) { paddedIdx in
                    Text(paddedWordmark(at: paddedIdx))
                        .font(Brand.Font.display(size: 56))
                        .tracking(-1.4)
                        .foregroundStyle(Brand.Color.ink)
                        .lineLimit(1)
                        // Allow longer vibe names (e.g. "Around town") to
                        // auto-shrink to fit the slot rather than ellipsis-
                        // truncating. Slot width and slide distance stay
                        // unchanged so carousel mechanics are unaffected.
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: slotWidth, alignment: .leading)
                }
            }
            .offset(x: -CGFloat(displayIndex) * slotWidth + dragOffset)
            .frame(width: slotWidth, alignment: .leading)
            .clipped()
            .padding(.top, 10)

            // Row 3: subtitle — pinned, fade on state change.
            Text(subtitleText)
                .font(Brand.Font.serifItalic(size: 18))
                .foregroundStyle(Brand.Color.inkSecondary)
                .lineLimit(1)
                .id("subtitle-\(activeIndex)")
                .transition(.opacity)
                .padding(.top, 8)

            // Row 4: pagination dots — pinned, active dot tinted by state.
            // Hidden when there are no vibes; a single dot is just noise.
            if slotCount > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<slotCount, id: \.self) { idx in
                        Circle()
                            .fill(idx == activeIndex ? dotActiveColor : Brand.Color.inkHairline)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 14)
            }

            // Row 5: Start / Vibing / Resume pill — color, icon, and copy
            // adapt based on whether the displayed vibe is also the queue's
            // source and whether the player is currently playing.
            Button {
                if let vibe = currentVibe {
                    if isCurrentVibePlayingSource {
                        onToggleVibe()
                    } else {
                        onStartVibe(vibe)
                    }
                } else {
                    onStartAll()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: ctaIcon)
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
            // Re-mount on state changes so the icon swap + text swap fade
            // together rather than snapping mid-press.
            .id("cta-\(activeIndex)-\(ctaStateKey)")
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 14)
        // The vibe-color band is rendered as a parent-level backdrop on
        // SubscriptionsListView so it bleeds past the top safe area into
        // the status-bar / camera-pill region. The masthead row itself
        // stays transparent.
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
        .onChange(of: vibes.map(\.persistentModelID)) { _, _ in
            // Vibe list changed (delete / create / reorder). Clamp the
            // carousel into the new real range and resync activeVibe to
            // whatever lives at the current slot — so deleting the vibe
            // you're looking at lands you on the *next* vibe at that slot
            // (rather than collapsing back to All or leaving a stale
            // pointer to a deleted Vibe).
            let realRange = 1...max(1, slotCount)
            if !realRange.contains(displayIndex) {
                displayIndex = max(realRange.lowerBound, min(realRange.upperBound, displayIndex))
            }
            let synced = currentVibe(at: logicalIndex(for: displayIndex))
            if synced?.persistentModelID != activeVibe?.persistentModelID {
                activeVibe = synced
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    // No carousel = no live drag offset. dragOffset stays at
                    // its @GestureState default (0) so the wordmark doesn't
                    // visually slide for a gesture that can't commit.
                    guard slotCount > 1 else { return }
                    state = value.translation.width
                }
                .onEnded { value in
                    let dx = value.translation.width
                    guard abs(dx) > swipeThreshold else { return }
                    let step = dx < 0 ? 1 : -1
                    advance(by: step)
                }
        )
        .animation(.easeInOut(duration: 0.28), value: activeIndex)
    }

    // MARK: - Carousel mechanics

    private var activeIndex: Int {
        logicalIndex(for: displayIndex)
    }

    private func advance(by step: Int) {
        // No vibes → no carousel. Swipe is a no-op so the wordmark doesn't
        // animate "Vibecast" out and back in for no reason.
        guard slotCount > 1 else { return }

        // Rapid-swipe guard: if a prior swipe landed on a phantom slot and
        // the deferred mirror-snap hasn't fired yet (completion handler is
        // still pending its 0.28s wait), normalize off the phantom first.
        // Otherwise `displayIndex + step` can leave the HStack range
        // (e.g. -1 or slotCount+2) and the clipped offset shows nothing.
        var from = displayIndex
        if from == 0 {
            snapWithoutAnimation(to: slotCount)
            from = slotCount
        } else if from == slotCount + 1 {
            snapWithoutAnimation(to: 1)
            from = 1
        }

        let nextDisplay = from + step
        let nextLogical = logicalIndex(for: nextDisplay)

        // Animate the wordmark slide AND the logical-state change together.
        withAnimation(.easeInOut(duration: 0.28)) {
            displayIndex = nextDisplay
            activeVibe = currentVibe(at: nextLogical)
        } completion: {
            // If we landed on a phantom, jump to its mirror position so the
            // next swipe in either direction has real slots to either side.
            // Read the *current* displayIndex (not the captured nextDisplay)
            // so a subsequent rapid swipe that already moved us off the
            // phantom doesn't get yanked back here.
            if displayIndex == 0 {
                snapWithoutAnimation(to: slotCount)
            } else if displayIndex == slotCount + 1 {
                snapWithoutAnimation(to: 1)
            }
        }
    }

    private func snapWithoutAnimation(to display: Int) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            displayIndex = display
        }
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

    // MARK: - Derived state

    private func wordmark(at logical: Int) -> String {
        currentVibe(at: logical)?.name ?? "Vibecast"
    }

    private var subtitleText: String {
        if let vibe = currentVibe {
            return vibeSubtitle(for: vibe)
        }
        return vibes.isEmpty ? "Add a podcast to get started" : "Your shows, in your order"
    }

    /// True when the masthead is showing the same vibe that's driving the
    /// player's queue. Determines whether the CTA acts as a Start button
    /// or a Pause/Resume toggle.
    private var isCurrentVibePlayingSource: Bool {
        guard let vibe = currentVibe, let source = queueSourceVibe else { return false }
        return vibe.persistentModelID == source.persistentModelID
    }

    private var ctaText: String {
        guard let _ = currentVibe else { return "Start listening" }
        if isCurrentVibePlayingSource {
            return isPlaying ? "Vibing" : "Resume"
        }
        return "Start the vibe"
    }

    private var ctaIcon: String {
        if isCurrentVibePlayingSource && isPlaying {
            return "pause.fill"
        }
        return "play.fill"
    }

    private var ctaBackgroundColor: Color {
        currentVibe?.colorKey.band ?? Brand.Color.ink
    }

    /// Compact key encoding the CTA's visual state — drives the `.id` swap so
    /// the pill cross-fades when transitioning between Start ↔ Vibing ↔ Resume.
    private var ctaStateKey: String {
        if currentVibe == nil { return "all" }
        if isCurrentVibePlayingSource { return isPlaying ? "vibing" : "resume" }
        return "idle"
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
            .compactMap { VibeQueueResolver.latestEpisodeIfUnplayed(in: $0) }
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

    private func currentVibe(at logical: Int) -> Vibe? {
        guard logical > 0 else { return nil }
        let i = logical - 1
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
