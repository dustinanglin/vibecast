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
        foldDividesView: Bool
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
            return pose == .partiallyOpen && foldDividesView ? .stacked : .single
        }
    }
}
