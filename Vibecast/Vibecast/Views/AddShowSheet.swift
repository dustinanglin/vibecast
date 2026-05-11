import SwiftUI
import SwiftData

struct AddShowSheet: View {
    let vibe: Vibe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Podcast.title)]) private var allPodcasts: [Podcast]
    @State private var query: String = ""
    @State private var selected: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header band — vibe.chip behind title.
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADD TO")
                        .font(Brand.Font.monoEyebrow())
                        .tracking(Brand.Layout.monoTracking)
                        .foregroundStyle(vibe.colorKey.ink.opacity(0.7))
                    Text(vibe.name)
                        .font(Brand.Font.serifTitle(size: 28))
                        .foregroundStyle(vibe.colorKey.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .background(vibe.colorKey.chip)

                TextField("Search your library", text: $query)
                    .font(Brand.Font.uiBody(size: 16))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Brand.Color.paper)
                    .overlay(Rectangle().fill(Brand.Color.inkHairline).frame(height: 1), alignment: .bottom)

                List(filtered) { podcast in
                    libraryRow(for: podcast)
                        .listRowBackground(Brand.Color.bg)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Brand.Color.bg)
            }
            .background(Brand.Color.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(addLabel) { addSelectionAndDismiss() }
                        .disabled(selected.isEmpty)
                }
            }
        }
    }

    private var alreadyTagged: Set<PersistentIdentifier> {
        Set(vibe.memberships.compactMap { $0.podcast?.persistentModelID })
    }

    private var filtered: [Podcast] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allPodcasts }
        return allPodcasts.filter { $0.title.lowercased().contains(q) }
    }

    private var addLabel: String {
        selected.isEmpty ? "Add" : "Add \(selected.count)"
    }

    @ViewBuilder
    private func libraryRow(for podcast: Podcast) -> some View {
        let isTagged = alreadyTagged.contains(podcast.persistentModelID)
        HStack(spacing: 14) {
            CoverArtwork(urlString: podcast.artworkURL, title: podcast.title, size: 44, radius: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(podcast.title).font(Brand.Font.serifBody(size: 16))
                Text(podcast.author).font(Brand.Font.uiBody(size: 13)).foregroundStyle(Brand.Color.inkSecondary)
            }
            Spacer()
            if isTagged {
                Text("ADDED")
                    .font(Brand.Font.monoEyebrow())
                    .tracking(Brand.Layout.monoTracking)
                    .foregroundStyle(vibe.colorKey.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(vibe.colorKey.chip))
            } else {
                checkboxCircle(isOn: selected.contains(podcast.persistentModelID))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isTagged else { return }
            if selected.contains(podcast.persistentModelID) {
                selected.remove(podcast.persistentModelID)
            } else {
                selected.insert(podcast.persistentModelID)
            }
        }
    }

    private func checkboxCircle(isOn: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(vibe.colorKey.band, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isOn {
                Circle().fill(vibe.colorKey.band).frame(width: 14, height: 14)
            }
        }
    }

    private func addSelectionAndDismiss() {
        // Use max-position-plus-one rather than count so deletions in earlier
        // sessions don't produce duplicate positions when re-tagged later.
        // Positions are append-only and monotonically increasing; resolver
        // sorts by position so duplicates would yield nondeterministic order.
        var counter = (vibe.memberships.map(\.position).max() ?? -1) + 1
        for podcast in allPodcasts where selected.contains(podcast.persistentModelID) {
            modelContext.insert(VibeMembership(vibe: vibe, podcast: podcast, position: counter))
            counter += 1
        }
        try? modelContext.save()
        dismiss()
    }
}
