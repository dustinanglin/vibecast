import SwiftData
import Foundation

/// Persistent queue state, modeled as a single-row table. Use
/// `fetchOrCreate(in:)` to get the row; never `init` directly except inside
/// the helper.
@Model
final class QueueState {
    var sourceVibe: Vibe?
    var currentPodcast: Podcast?
    var currentEpisode: Episode?
    var lastUpdated: Date

    init() {
        self.lastUpdated = .now
    }

    /// Fetch the singleton row, creating it if absent. Caller is responsible
    /// for `try context.save()` after mutation.
    static func fetchOrCreate(in context: ModelContext) -> QueueState {
        let descriptor = FetchDescriptor<QueueState>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let new = QueueState()
        context.insert(new)
        return new
    }
}
