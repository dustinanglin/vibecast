import SwiftUI
import MediaPlayer

/// Wraps `MPVolumeView` so SwiftUI can host it. `MPVolumeView` shows the
/// system volume slider plus the AirPlay route-picker button. It writes to
/// system volume — no app-private state.
///
/// Note: in the iOS Simulator the slider renders blank/disabled. Verify on a
/// device.
struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = true
        view.showsVolumeSlider = true
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
