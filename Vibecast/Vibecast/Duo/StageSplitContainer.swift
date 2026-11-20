import SwiftUI

/// Places the Library (primary) and the Stage (secondary). On iPhone Duo this
/// is a system arrangement view, which keeps both panes clear of the fold.
/// Everywhere else only the primary is shown. Side by side the Library is
/// first; stacked, the Stage is on top.
struct StageSplitContainer<Primary: View, Secondary: View>: View {
    let mode: StageLayoutMode
    @ViewBuilder let primary: Primary
    @ViewBuilder let secondary: Secondary

    var body: some View {
        if let forced = DuoDebug.forcedMode {
            manualSplit(forced)
        } else if #available(iOS 27.1, *) {
            ArrangementView {
                if stageLeads { secondary } else { primary }
            } secondary: {
                if stageLeads { primary } else { secondary }
            }
            .arrangementViewStyle(.split.axes(axes))
            // The strip the system keeps clear over the fold shows whatever
            // is behind the two panes; make that the app's paper, not white.
            .background(Brand.Color.bg.ignoresSafeArea())
        } else {
            primary
        }
    }

    /// Part-folded in portrait, the Stage takes the upper half (the upright
    /// screen) and the Library the lower one. The split style always puts
    /// its first view on top, so the two trade slots in that pose.
    private var stageLeads: Bool { mode == .stacked }

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
                secondary.frame(maxHeight: .infinity)
                primary.frame(maxHeight: .infinity)
            }
        case .single:
            primary
        }
    }
}
