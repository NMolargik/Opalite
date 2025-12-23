import Foundation
import Observation

@Observable
final class QuickActionManager {
    // Use a trigger token so multiple requests can be distinguished.
    var newColorTrigger: UUID?

    func requestCreateNewColor() {
        newColorTrigger = UUID()
    }
}
