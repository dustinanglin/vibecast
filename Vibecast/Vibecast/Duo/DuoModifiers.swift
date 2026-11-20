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

    /// Side by side, sheets cover the Stage half and leave the Library
    /// visible. Stacked, they rise only as far as the top of the Library's
    /// (lower) half, so the Stage above the fold stays in view. Apply to the
    /// content of every sheet, including ones presented from other sheets.
    func duoSheetPlacement() -> some View {
        modifier(DuoSheetPlacement())
    }
}

/// What a sheet needs to know to place itself; set once by the main screen
/// and inherited by every sheet presented beneath it.
struct DuoSheetContext: Equatable {
    var mode: StageLayoutMode = .single
    var libraryPaneHeight: CGFloat = 0
}

extension EnvironmentValues {
    @Entry var duoSheetContext = DuoSheetContext()
}

private struct DuoSheetPlacement: ViewModifier {
    @Environment(\.duoSheetContext) private var context

    func body(content: Content) -> some View {
        // A sheet shorter than full height gets the system's translucent
        // material, which lets the list show through; keep it solid paper.
        let sized = content
            .presentationDetents(detents)
            .presentationBackground(context.mode == .stacked ? AnyShapeStyle(Brand.Color.bg) : AnyShapeStyle(.background))
        if #available(iOS 27.0, *) {
            sized.presentationPlacement(context.mode == .sideBySide ? .trailing : .automatic)
        } else {
            sized
        }
    }

    /// There is no system placement for "the lower half", so the stacked
    /// case is a fixed-height detent matching the Library pane.
    private var detents: Set<PresentationDetent> {
        guard context.mode == .stacked, context.libraryPaneHeight > 0 else { return [.large] }
        return [.height(context.libraryPaneHeight)]
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
