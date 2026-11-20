import CoreGraphics

/// Whether the Stage (Now Playing / show detail) gets its own pane.
enum StageLayoutMode: Equatable {
    case single
    case sideBySide
    case stacked

    static func resolve(
        pose: DuoPose,
        size: CGSize,
        isRegularWidth: Bool,
        horizontalFoldDividesView: Bool
    ) -> StageLayoutMode {
        switch pose {
        case .notFoldable, .closed:
            return .single
        case .partiallyOpen, .fullyOpen:
            let isLandscape = size.width > size.height
            if isLandscape {
                // Compact width here means Split View with another app.
                return isRegularWidth ? .sideBySide : .single
            }
            return pose == .partiallyOpen && horizontalFoldDividesView ? .stacked : .single
        }
    }

    /// Whether a fold runs left to right through the middle of a view of
    /// `size`, so that it has an upper and a lower half. `divisions` are the
    /// fold's reserved regions in the view's own coordinates. A fold running
    /// top to bottom (Split View beside another app in landscape, where the
    /// window is taller than wide) does not count: there is nothing to stack.
    static func horizontalFoldDivides(_ size: CGSize, divisions: [CGRect]) -> Bool {
        divisions.contains { fold in
            fold.width > fold.height && fold.midY > 0 && fold.midY < size.height
        }
    }
}
