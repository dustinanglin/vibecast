import SwiftUI

private struct SubscriptionManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: SubscriptionManager? = nil
}

extension EnvironmentValues {
    var subscriptionManager: SubscriptionManager? {
        get { self[SubscriptionManagerKey.self] }
        set { self[SubscriptionManagerKey.self] = newValue }
    }
}
