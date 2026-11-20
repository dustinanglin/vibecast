import SwiftUI

/// What the current device pose asks of the main screen.
struct DuoLayout: Equatable {
    /// The system shows toolbar items in a vertical bar on the side.
    var hasSideBar = false
    var mode: StageLayoutMode = .single
}

/// Resolves `DuoLayout` from the environment. On anything other than an
/// iPhone Duo (or before iOS 27.1) this always yields the default layout,
/// so callers need no availability checks of their own.
struct DuoLayoutReader<Content: View>: View {
    @ViewBuilder let content: (DuoLayout) -> Content

    var body: some View {
        if #available(iOS 27.1, *) {
            PoseAwareReader(content: content)
        } else {
            content(DuoLayout(mode: DuoDebug.forcedMode ?? .single))
        }
    }
}

@available(iOS 27.1, *)
private struct PoseAwareReader<Content: View>: View {
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge
    @Environment(\.duoPose) private var pose
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder let content: (DuoLayout) -> Content

    var body: some View {
        GeometryReader { proxy in
            let foldDividesView = !proxy.reservedRegions(kind: .division).isEmpty
            let mode = DuoDebug.forcedMode ?? StageLayoutMode.resolve(
                pose: pose,
                size: proxy.size,
                isRegularWidth: horizontalSizeClass == .regular,
                foldDividesView: foldDividesView
            )
            content(DuoLayout(hasSideBar: toolbarVerticalEdge != nil, mode: mode))
        }
    }
}

/// Lets the two-pane layouts be exercised on a simulator that cannot fold:
/// launch with `-duoForceLayout sideBySide` or `-duoForceLayout stacked`.
/// Debug builds only.
enum DuoDebug {
    static var forcedMode: StageLayoutMode? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "duoForceLayout") {
        case "sideBySide": return .sideBySide
        case "stacked": return .stacked
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
