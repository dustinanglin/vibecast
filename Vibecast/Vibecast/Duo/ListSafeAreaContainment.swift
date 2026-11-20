import SwiftUI

extension View {
    /// Keeps a `List` out from under a horizontal safe-area inset.
    ///
    /// A list that touches the edge of the safe area extends its scroll view
    /// underneath it. On iPhone Duo the vertical side bar is a wide trailing
    /// inset, and a row swiped to reveal its actions then slides over by that
    /// inset on top of the width of the actions. A hairline gap between the
    /// list and the inset is enough to stop the extension. With no horizontal
    /// inset (every other iPhone in portrait) this changes nothing.
    func containedInHorizontalSafeArea() -> some View {
        GeometryReader { proxy in
            self
                .padding(.leading, proxy.safeAreaInsets.leading > 0 ? 1 : 0)
                .padding(.trailing, proxy.safeAreaInsets.trailing > 0 ? 1 : 0)
        }
    }
}
