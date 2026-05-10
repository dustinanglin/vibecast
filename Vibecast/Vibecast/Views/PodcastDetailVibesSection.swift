import SwiftUI
import SwiftData

struct PodcastDetailVibesSection: View {
    let podcast: Podcast
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Vibe.sortPosition)]) private var allVibes: [Vibe]
    @State private var newVibeSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("IN YOUR VIBES")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(Brand.Color.inkMuted)
                Spacer()
                Rectangle().fill(Brand.Color.inkHairline).frame(height: Brand.Layout.hairlineWidth)
            }

            FlowingPills(vibes: allVibes, taggedIds: taggedVibeIds, onTap: { toggle($0) }, onAddNew: { newVibeSheet = true })
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .sheet(isPresented: $newVibeSheet) {
            VibeEditSheet(mode: .create(autoTagPodcast: podcast))
        }
    }

    private var taggedVibeIds: Set<PersistentIdentifier> {
        Set(podcast.vibeMemberships.compactMap { $0.vibe?.persistentModelID })
    }

    private func toggle(_ vibe: Vibe) {
        let existingIndex = podcast.vibeMemberships.firstIndex(where: { $0.vibe?.persistentModelID == vibe.persistentModelID })
        if let idx = existingIndex {
            let membership = podcast.vibeMemberships[idx]
            modelContext.delete(membership)
        } else {
            // Use max-position-plus-one so untag/retag preserves monotonic ordering
            // (matches AddShowSheet's behavior; commit c66b24c).
            let position = (vibe.memberships.map(\.position).max() ?? -1) + 1
            modelContext.insert(VibeMembership(vibe: vibe, podcast: podcast, position: position))
        }
        try? modelContext.save()
    }
}

private struct FlowingPills: View {
    let vibes: [Vibe]
    let taggedIds: Set<PersistentIdentifier>
    let onTap: (Vibe) -> Void
    let onAddNew: () -> Void

    var body: some View {
        // SwiftUI lacks native flow layout — use a horizontal ScrollView for v1
        // since pill count is small (≤8 vibes typical).
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vibes) { vibe in
                    pill(for: vibe)
                }
                addNewPill
            }
        }
    }

    private func pill(for vibe: Vibe) -> some View {
        let isTagged = taggedIds.contains(vibe.persistentModelID)
        return Button {
            onTap(vibe)
        } label: {
            Text(vibe.name)
                .font(Brand.Font.uiButton(size: 13))
                .foregroundStyle(isTagged ? vibe.colorKey.ink : Brand.Color.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isTagged ? vibe.colorKey.chip : Color.clear)
                        .overlay(
                            Capsule().strokeBorder(
                                isTagged ? Color.clear : Brand.Color.inkHairline,
                                lineWidth: Brand.Layout.hairlineWidth
                            )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var addNewPill: some View {
        Button(action: onAddNew) {
            HStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 11, weight: .regular))
                Text("New vibe").font(Brand.Font.uiButton(size: 13))
            }
            .foregroundStyle(Brand.Color.inkMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().strokeBorder(
                    Brand.Color.inkHairline,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            )
        }
        .buttonStyle(.plain)
    }
}
