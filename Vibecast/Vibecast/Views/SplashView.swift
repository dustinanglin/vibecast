import SwiftUI

/// Cold-launch animated splash. Side-band variant from
/// `docs/design/vibecast-visual-prototypes/project/Vibecast Animated Splash.html`,
/// section "B · Side band · animated".
///
/// Cycles through the five seeded vibes (morning → around → workout →
/// winddown → deepwork), holds each for ~950ms with a 340ms color
/// crossfade, then settles on `around` with the tagline "Listen with
/// intent."
///
/// **Cold launch only.** Gated upstream by a `@State` flag on
/// `VibecastApp` — once dismissed for the lifetime of the process, the
/// splash never shows again until iOS evicts the process and the user
/// returns.
///
/// **Tap to skip.** Any tap inside the splash dismisses immediately.
///
/// **Reduce Motion.** Honors `\.accessibilityReduceMotion`: skips the
/// cycle and just fades a static "around"-tinted splash in, holds, then
/// dismisses.
struct SplashView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage: Stage = .intro
    @State private var vibeIndex: Int = 0

    private enum Stage {
        case intro    // bg only, fading in
        case cycle    // cycling through vibes
        case settle   // landed on default
    }

    // MARK: - Animation constants

    /// Narrative order. Matches `SWIPE_ORDER` in the design JSX, with
    /// "plane" replaced by "deepwork" so the splash uses the same five
    /// colors the rest of the app does.
    private static let cycleOrder: [VibeColorKey] = [
        .morning, .around, .workout, .winddown, .deepwork
    ]

    /// Settle vibe per the design note — the brand's teal-leaning default.
    private static let settleVibe: VibeColorKey = .around

    private static let introDurationMs: UInt64 = 800
    private static let cycleHoldMs: UInt64 = 950
    private static let settleHoldMs: UInt64 = 1400
    private static let reduceMotionHoldMs: UInt64 = 1200
    private static let crossfadeSeconds: Double = 0.34

    // MARK: - Derived state

    private var activeVibe: VibeColorKey {
        switch stage {
        case .intro, .cycle:
            return Self.cycleOrder[vibeIndex]
        case .settle:
            return Self.settleVibe
        }
    }

    private var bandsVisible: Bool { stage != .intro }
    private var contentVisible: Bool { stage != .intro }
    private var settled: Bool { stage == .settle }

    // MARK: - View

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // Paper background, full bleed.
                Brand.Color.bg
                    .ignoresSafeArea()

                // Saturated band, 14% of the screen width on the left.
                activeVibe.band
                    .frame(width: proxy.size.width * 0.14)
                    .opacity(bandsVisible ? 0.85 : 0)
                    .ignoresSafeArea()

                // Faint adjacent band, 6% wide, starting at 14%.
                activeVibe.band
                    .frame(width: proxy.size.width * 0.06)
                    .opacity(bandsVisible ? 0.32 : 0)
                    .offset(x: proxy.size.width * 0.14)
                    .ignoresSafeArea()

                // Wordmark + accent dot, vertically centered, padded left
                // so the side band has room to breathe.
                VStack {
                    Spacer()
                    wordmark
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, proxy.size.width * 0.10)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 8)

                // Vibe label + tagline (or settle copy) — sits left of
                // center, low in the screen.
                VStack(alignment: .leading, spacing: 2) {
                    if settled {
                        Text("PICK A MOOD · PRESS PLAY")
                            .font(Brand.Font.monoEyebrow())
                            .tracking(Brand.Layout.monoTracking)
                            .foregroundStyle(Brand.Color.inkMuted)
                    } else {
                        Text(activeVibe.defaultName)
                            .font(Brand.Font.serifTitle(size: 22))
                            .foregroundStyle(Brand.Color.ink)
                        Text(tagline(for: activeVibe))
                            .font(Brand.Font.serifItalic(size: 14))
                            .foregroundStyle(Brand.Color.inkSecondary)
                    }
                }
                .id("label-\(stage == .settle ? "settle" : activeVibe.rawValue)")
                .transition(.opacity.combined(with: .offset(y: 6)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, proxy.size.width * 0.26)
                .padding(.trailing, 24)
                .offset(y: proxy.size.height - 130)
                .opacity(contentVisible ? 1 : 0)

                // Tagline at the very bottom — same slot for both the
                // cycle and settle phases. Copy swaps when we settle.
                VStack {
                    Spacer()
                    Text(settled ? "Listen with intent." : "Pick your vibe.")
                        .font(Brand.Font.serifItalic(size: 13))
                        .foregroundStyle(Brand.Color.inkSecondary)
                        .padding(.bottom, 30)
                }
                .frame(maxWidth: .infinity)
                .opacity(contentVisible ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: Self.crossfadeSeconds), value: activeVibe)
        .animation(.easeInOut(duration: 0.5), value: stage)
        .contentShape(Rectangle())
        .onTapGesture { onComplete() }
        .task { await runAnimation() }
    }

    // MARK: - Wordmark

    /// Inline-built wordmark so the accent-dot color can crossfade with
    /// the active vibe without sharing state with another helper view.
    /// Matches `AnimatedWordmark` in the design JSX: Fraunces medium,
    /// 56pt-ish, dot to the right of the "t" with the band color.
    private var wordmark: some View {
        let fontSize: CGFloat = 56
        let dotSize: CGFloat = fontSize * 0.14
        return HStack(alignment: .lastTextBaseline, spacing: fontSize * 0.04) {
            Text("Vibecast")
                .font(Brand.Font.display(size: fontSize))
                .tracking(-1.4)
                .foregroundStyle(Brand.Color.ink)
                .lineLimit(1)
            Circle()
                .fill(activeVibe.band)
                .frame(width: dotSize, height: dotSize)
                .offset(y: -dotSize * 0.45) // hover at descender height
        }
    }

    // MARK: - Copy

    private func tagline(for vibe: VibeColorKey) -> String {
        switch vibe {
        case .morning:  return "ease into it."
        case .around:   return "background, but better."
        case .workout:  return "pulse up."
        case .winddown: return "lights low."
        case .deepwork: return "head down."
        }
    }

    // MARK: - Animation

    @MainActor
    private func runAnimation() async {
        if reduceMotion {
            // Skip the cycle. Fade in the static splash (already on the
            // settle vibe) and hold briefly before dismissing.
            withAnimation { stage = .settle }
            try? await Task.sleep(for: .milliseconds(Self.reduceMotionHoldMs))
            onComplete()
            return
        }

        // intro → cycle
        try? await Task.sleep(for: .milliseconds(Self.introDurationMs))
        withAnimation { stage = .cycle }

        // Advance through the remaining cycle slots.
        for index in 1..<Self.cycleOrder.count {
            try? await Task.sleep(for: .milliseconds(Self.cycleHoldMs))
            withAnimation { vibeIndex = index }
        }

        // Hold the final cycle slot one beat, then settle.
        try? await Task.sleep(for: .milliseconds(Self.cycleHoldMs))
        withAnimation { stage = .settle }

        try? await Task.sleep(for: .milliseconds(Self.settleHoldMs))
        onComplete()
    }
}

#Preview {
    SplashView(onComplete: {})
}
