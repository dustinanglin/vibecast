// Vibecast/Vibecast/Views/Toast.swift
import SwiftUI
import Observation

/// Tiny transient banner. Single message at a time; calling `show(_:)` while
/// one is on-screen replaces it. Auto-dismisses after `duration`.
@MainActor
@Observable
final class ToastCenter {
    private(set) var current: String?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?

    func show(_ message: String, duration: Duration = .seconds(2)) {
        current = message
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }
}

private struct ToastCenterKey: EnvironmentKey {
    @MainActor static let defaultValue: ToastCenter? = nil
}

extension EnvironmentValues {
    var toastCenter: ToastCenter? {
        get { self[ToastCenterKey.self] }
        set { self[ToastCenterKey.self] = newValue }
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Brand.Font.uiBody(size: 14, weight: .medium))
            .foregroundStyle(Brand.Color.paper)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Brand.Color.ink.opacity(0.92))
            )
            .padding(.bottom, 100) // sit above mini-player
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
