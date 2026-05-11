import SwiftUI
import SwiftData

struct VibeEditSheet: View {
    enum Mode {
        case create(autoTagPodcast: Podcast?)
        case edit(Vibe)
    }

    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Vibe.sortPosition)]) private var allVibes: [Vibe]
    @State private var name: String
    @State private var colorKey: VibeColorKey

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _colorKey = State(initialValue: .morning)
        case .edit(let vibe):
            _name = State(initialValue: vibe.name)
            _colorKey = State(initialValue: vibe.colorKey)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NAME")
                        .font(Brand.Font.monoEyebrow())
                        .tracking(Brand.Layout.monoTracking)
                        .foregroundStyle(Brand.Color.inkMuted)
                    TextField("e.g. Commute", text: $name)
                        .font(Brand.Font.serifTitle(size: 22))
                        .foregroundStyle(Brand.Color.ink)
                        .padding(.vertical, 8)
                        .overlay(Rectangle().fill(Brand.Color.inkHairline).frame(height: 1), alignment: .bottom)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("COLOR")
                        .font(Brand.Font.monoEyebrow())
                        .tracking(Brand.Layout.monoTracking)
                        .foregroundStyle(Brand.Color.inkMuted)
                    HStack(spacing: 16) {
                        ForEach(VibeColorKey.allCases, id: \.self) { key in
                            colorSwatch(key)
                        }
                    }
                }

                Spacer()
            }
            .padding(22)
            .background(Brand.Color.bg)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var titleText: String {
        switch mode {
        case .create: return "New vibe"
        case .edit:   return "Edit vibe"
        }
    }

    private func colorSwatch(_ key: VibeColorKey) -> some View {
        Button {
            colorKey = key
        } label: {
            Circle()
                .fill(key.band)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .strokeBorder(key == colorKey ? Brand.Color.ink : Color.clear, lineWidth: 2)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create(let autoTag):
            // Use max-position-plus-one for the new vibe's sortPosition so
            // deletions earlier in the session don't produce duplicate
            // sortPosition values when re-creating.
            let nextPosition = (allVibes.map(\.sortPosition).max() ?? -1) + 1
            let newVibe = Vibe(name: trimmed, colorKey: colorKey, sortPosition: nextPosition, isSeeded: false)
            modelContext.insert(newVibe)
            if let podcast = autoTag {
                modelContext.insert(VibeMembership(vibe: newVibe, podcast: podcast, position: 0))
            }
        case .edit(let vibe):
            vibe.name = trimmed
            vibe.colorKey = colorKey
        }
        try? modelContext.save()
        dismiss()
    }
}
