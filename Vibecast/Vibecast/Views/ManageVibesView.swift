import SwiftUI
import SwiftData

struct ManageVibesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Vibe.sortPosition)]) private var vibes: [Vibe]
    @State private var editing = false
    @State private var newSheet = false
    @State private var editTarget: Vibe?

    var body: some View {
        NavigationStack {
            List {
                ForEach(vibes) { vibe in
                    VibeManageCard(
                        vibe: vibe,
                        isEditing: editing,
                        onTap: { editTarget = vibe },
                        onDelete: { delete(vibe) }
                    )
                    .listRowBackground(Brand.Color.bg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onMove(perform: move)

                Button { newSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add vibe").font(Brand.Font.uiButton(size: 14))
                        Spacer()
                    }
                    .foregroundStyle(Brand.Color.inkMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: Brand.Radius.card)
                            .strokeBorder(
                                Brand.Color.inkHairline,
                                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                            )
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Brand.Color.bg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 24, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Brand.Color.bg)
            .navigationTitle("Manage vibes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button(editing ? "Done" : "Edit") {
                        withAnimation(.easeInOut(duration: 0.18)) { editing.toggle() }
                    }
                }
            }
            .sheet(isPresented: $newSheet) {
                VibeEditSheet(mode: .create(autoTagPodcast: nil))
            }
            .sheet(item: $editTarget) { vibe in
                VibeEditSheet(mode: .edit(vibe))
            }
        }
    }

    private func delete(_ vibe: Vibe) {
        // If this vibe is currently driving the queue, clear sourceVibe and
        // currentPodcast first so PlayerManager doesn't try to access a
        // deleted Vibe on the next end-of-episode advance. The cascade
        // would eventually nil sourceVibe via @Relationship(.nullify), but
        // doing it explicitly here removes any window where a stale
        // reference can be touched.
        if let state = try? QueueState.fetchOrCreate(in: modelContext),
           state.sourceVibe?.persistentModelID == vibe.persistentModelID {
            state.sourceVibe = nil
            state.currentPodcast = nil
        }
        modelContext.delete(vibe)
        try? modelContext.save()
        // Re-pack sortPosition contiguously among remaining vibes.
        let remaining = vibes.filter { $0.persistentModelID != vibe.persistentModelID }
        for (idx, v) in remaining.enumerated() {
            v.sortPosition = idx
        }
        try? modelContext.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = vibes
        reordered.move(fromOffsets: source, toOffset: destination)
        for (i, v) in reordered.enumerated() { v.sortPosition = i }
        try? modelContext.save()
    }
}
