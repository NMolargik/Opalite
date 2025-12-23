//
//  HapticsManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/23/25.
//

import Foundation
import UIKit

final class HapticsManager {

    static let shared = HapticsManager()
    private init() {}

    // MARK: - Impact (most common)

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Selection

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Notification

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
