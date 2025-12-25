import Foundation
import Observation

@Observable
final class QuickActionManager {
    // Use a trigger token so multiple requests can be distinguished.
    var newColorTrigger: UUID?

    // Paywall trigger with context message
    var paywallTrigger: (id: UUID, context: String)?

    func requestCreateNewColor() {
        newColorTrigger = UUID()
    }

    func requestPaywall(context: String) {
        paywallTrigger = (UUID(), context)
    }
}
