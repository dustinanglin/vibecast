import SwiftUI

/// Places the Library (primary) and the Stage (secondary). On iPhone Duo this
/// is a system arrangement view, which keeps both panes clear of the fold.
/// Everywhere else only the primary is shown.
struct StageSplitContainer<Primary: View, Secondary: View>: View {
    let mode: StageLayoutMode
    @ViewBuilder let primary: Primary
    @ViewBuilder let secondary: Secondary

    var body: some View {
        if let forced = DuoDebug.forcedMode {
            manualSplit(forced)
        } else if #available(iOS 27.1, *) {
            ArrangementView {
                primary
            } secondary: {
                secondary
            }
            .arrangementViewStyle(.split.axes(axes))
        } else {
            primary
        }
    }

    /// An axis left out means "primary only" on that axis, so `single` passes
    /// none and the arrangement can never disagree with `StageLayoutMode`.
    private var axes: Axis.Set {
        switch mode {
        case .single: return []
        case .sideBySide: return .horizontal
        case .stacked: return .vertical
        }
    }

    @ViewBuilder
    private func manualSplit(_ forced: StageLayoutMode) -> some View {
        switch forced {
        case .sideBySide:
            HStack(spacing: 0) {
                primary.frame(maxWidth: .infinity)
                secondary.frame(maxWidth: .infinity)
            }
        case .stacked:
            VStack(spacing: 0) {
                primary.frame(maxHeight: .infinity)
                secondary.frame(maxHeight: .infinity)
            }
        case .single:
            primary
        }
    }
}
