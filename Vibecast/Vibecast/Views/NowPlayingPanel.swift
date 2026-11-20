import SwiftUI

/// The player surface: artwork, titles, scrubber, transport. Shared by the
/// full-screen sheet and the iPhone Duo Stage, so it sizes itself from the
/// space it is given rather than from fixed iPhone dimensions.
struct NowPlayingPanel: View {
    let player: PlayerManager

    /// Non-nil while the user is dragging the scrubber.
    @State private var scrubValue: Double?

    /// Height of everything except the artwork in the tall arrangement.
    private static let tallChromeHeight: CGFloat = 358
    private static let volumeRowHeight: CGFloat = 68

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height * 1.15 {
                wideLayout(in: proxy.size)
            } else {
                tallLayout(in: proxy.size)
            }
        }
    }

    // MARK: - Arrangements

    private func tallLayout(in size: CGSize) -> some View {
        let showsVolume = size.height - Self.tallChromeHeight - Self.volumeRowHeight >= 200
        let chrome = Self.tallChromeHeight + (showsVolume ? Self.volumeRowHeight : 0)
        let artwork = min(max(size.height - chrome, 140), size.width - 64, 360)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            eyebrow
                .padding(.bottom, 20)
            cover(size: artwork)
                .padding(.bottom, 24)
            titles(alignment: .center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            scrubber
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            transportControls
                .padding(.bottom, showsVolume ? 24 : 16)
            if showsVolume {
                SystemVolumeView()
                    .frame(height: 44)
                    .padding(.horizontal, 32)
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
    }

    private func wideLayout(in size: CGSize) -> some View {
        let artwork = min(max(size.height - 72, 120), size.width * 0.38, 300)
        return HStack(alignment: .center, spacing: 28) {
            cover(size: artwork)
            VStack(alignment: .leading, spacing: 0) {
                eyebrow
                    .padding(.bottom, 12)
                titles(alignment: .leading)
                    .padding(.bottom, 18)
                scrubber
                    .padding(.bottom, 14)
                transportControls
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Pieces

    private var eyebrow: some View {
        Text("Now Playing")
            .font(Brand.Font.monoEyebrow())
            .tracking(Brand.Layout.monoTracking)
            .textCase(.uppercase)
            .foregroundStyle(Brand.Color.inkSecondary)
    }

    private func cover(size: CGFloat) -> some View {
        CoverArtwork(
            urlString: player.currentEpisode?.podcast?.artworkURL,
            title: player.currentEpisode?.podcast?.title ?? "",
            size: size,
            radius: Brand.Radius.coverLarge
        )
        .shadow(color: .black.opacity(0.10), radius: 20, y: 8)
    }

    private func titles(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(player.currentEpisode?.podcast?.title ?? "")
                .font(Brand.Font.monoEyebrowLarge())
                .tracking(Brand.Layout.monoTracking)
                .textCase(.uppercase)
                .foregroundStyle(Brand.Color.inkSecondary)
                .lineLimit(1)

            Text(player.currentEpisode?.title ?? "")
                .font(Brand.Font.serifTitle(size: alignment == .center ? 28 : 24))
                .foregroundStyle(Brand.Color.ink)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var scrubber: some View {
        VStack(spacing: 6) {
            // Custom hairline + thumb. A DragGesture with minimumDistance 0
            // on the full-height contentShape gives touch-and-scrub behavior
            // (a tap-down also seeks). Replaced an earlier invisible-Slider
            // approach where .opacity(0.001) caused unreliable hit testing.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Hairline track
                    Rectangle()
                        .fill(Brand.Color.inkHairline)
                        .frame(height: Brand.Layout.hairlineWidth)
                    // Accent-filled progress
                    Rectangle()
                        .fill(Brand.Color.accent)
                        .frame(width: max(0, geo.size.width * scrubFraction), height: Brand.Layout.hairlineWidth)
                    // Visual thumb
                    Circle()
                        .fill(Brand.Color.accent)
                        .frame(width: 14, height: 14)
                        .offset(x: max(0, min(geo.size.width * scrubFraction - 7, geo.size.width - 14)))
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = max(0, min(value.location.x, geo.size.width))
                            let fraction = geo.size.width > 0 ? Double(x / geo.size.width) : 0
                            scrubValue = fraction * max(player.duration, 1)
                        }
                        .onEnded { _ in
                            if let v = scrubValue {
                                player.seek(to: v)
                                scrubValue = nil
                            }
                        }
                )
            }
            .frame(height: 32)

            // Time labels
            HStack {
                Text(format(scrubValue ?? player.elapsed))
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkSecondary)
                    .accessibilityLabel(
                        "\(TimeFormatting.spoken(seconds: scrubValue ?? player.elapsed)) elapsed"
                    )
                Spacer()
                Text("-" + format(max(0, player.duration - (scrubValue ?? player.elapsed))))
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkSecondary)
                    .accessibilityLabel(
                        "\(TimeFormatting.spoken(seconds: max(0, player.duration - (scrubValue ?? player.elapsed)))) remaining"
                    )
            }
        }
    }

    private var scrubFraction: Double {
        let value = scrubValue ?? player.elapsed
        guard player.duration > 0 else { return 0 }
        return min(max(value / player.duration, 0), 1)
    }

    private var transportControls: some View {
        HStack(spacing: 24) {
            // Skip-back-15 (56×56)
            Button {
                player.skipBack()
            } label: {
                ZStack {
                    Circle()
                        .fill(Brand.Color.paper)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Brand.Color.ink)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Primary play/pause (70×70)
            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    if player.isPlaying {
                        Circle()
                            .fill(Brand.Color.accent)
                            .frame(width: 56, height: 56)
                        Image(systemName: "pause.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Brand.Color.paper)
                    } else {
                        Circle()
                            .fill(Brand.Color.paper)
                            .frame(width: 56, height: 56)
                            .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Brand.Color.ink)
                    }
                }
                .frame(width: Brand.HitTarget.primaryPlay, height: Brand.HitTarget.primaryPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Skip-forward-30 (56×56)
            Button {
                player.skipForward()
            } label: {
                ZStack {
                    Circle()
                        .fill(Brand.Color.paper)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Brand.Color.inkHairline, lineWidth: Brand.Layout.hairlineWidth))
                    Image(systemName: "goforward.30")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Brand.Color.ink)
                }
                .frame(width: Brand.HitTarget.rowPlay, height: Brand.HitTarget.rowPlay)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
