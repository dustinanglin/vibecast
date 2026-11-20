import Foundation
import os

/// Collects download progress callbacks off the main thread so the UI is
/// told about them in batches.
///
/// URLSession reports progress many times a second per task. Forwarding
/// each report to the main actor redraws the show list every time, which
/// makes scrolling stutter while several episodes download. Callers record
/// here instead, and drain the latest values on a timer.
final class DownloadProgressBuffer: Sendable {

    private struct State {
        var latest: [String: Double] = [:]
        var flushPending = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Stores the latest fraction for `key`. Returns true when the caller
    /// should schedule a flush, false when one is already on its way.
    func record(fraction: Double, for key: String) -> Bool {
        state.withLock { state in
            state.latest[key] = fraction
            guard !state.flushPending else { return false }
            state.flushPending = true
            return true
        }
    }

    /// Hands back the latest fraction per key and empties the buffer.
    func drain() -> [String: Double] {
        state.withLock { state in
            let latest = state.latest
            state.latest = [:]
            state.flushPending = false
            return latest
        }
    }
}
