import SwiftUI

extension View {
    /// Library actions as system toolbar items, shown only where the system
    /// presents a vertical side bar. Elsewhere the navigation bar stays
    /// hidden and the masthead keeps its own buttons.
    func duoLibraryToolbar(
        layout: DuoLayout,
        showsClose: Bool,
        onClose: @escaping () -> Void,
        onAdd: @escaping () -> Void,
        onVibes: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) -> some View {
        toolbar {
            if layout.hasSideBar {
                if showsClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: onClose) {
                            Label("Close show", systemImage: "xmark")
                        }
                    }
                }
                DuoLibraryToolbarItems(onAdd: onAdd, onVibes: onVibes, onSettings: onSettings)
            }
        }
        .toolbar(layout.hasSideBar ? .automatic : .hidden, for: .navigationBar)
    }

    /// In the side-by-side layout, sheets cover the Stage half and leave the
    /// Library visible.
    @ViewBuilder
    func duoSheetPlacement(_ mode: StageLayoutMode) -> some View {
        if #available(iOS 27.0, *) {
            presentationPlacement(mode == .sideBySide ? .trailing : .automatic)
        } else {
            self
        }
    }
}

/// Top to bottom: Add, Vibes, Settings. Settings is the first to move into
/// the overflow menu when the bar runs out of room.
private struct DuoLibraryToolbarItems: ToolbarContent {
    let onAdd: () -> Void
    let onVibes: () -> Void
    let onSettings: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 27.0, *) {
            add.visibilityPriority(.high)
            vibes
            settings.visibilityPriority(.low)
        } else {
            add
            vibes
            settings
        }
    }

    private var add: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onAdd) { Label("Add podcast", systemImage: "plus") }
        }
    }

    private var vibes: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onVibes) { Label("Manage vibes", systemImage: "square.3.layers.3d") }
        }
    }

    private var settings: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSettings) { Label("Download settings", systemImage: "gearshape") }
        }
    }
}
