//
//  HapticsManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/23/25.
//

import Foundation

#if canImport(UIKit) && !os(tvOS)
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

#else

// MARK: - tvOS / Fallback (No-Op)

/// No-op HapticsManager for platforms without haptic feedback (tvOS, etc.)
final class HapticsManager {

    static let shared = HapticsManager()
    private init() {}

    func impact() {}
    func selection() {}
    func notification() {}
}

#endif
