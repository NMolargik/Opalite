//
//  ColorBlindnessMode.swift
//  OpaliteCore
//
//  Color-vision-deficiency simulations. Display titles are localized in the UI.
//

import Foundation

nonisolated public enum ColorBlindnessMode: String, CaseIterable, Identifiable, Sendable {
    case off
    case protanopia    // Red-blind
    case deuteranopia  // Green-blind
    case tritanopia    // Blue-blind
    case achromatopsia // Monochromacy

    public var id: String { rawValue }

    public var isActive: Bool { self != .off }

    public var systemImage: String {
        switch self {
        case .off: "eye"
        case .protanopia, .deuteranopia, .tritanopia: "eye.trianglebadge.exclamationmark"
        case .achromatopsia: "circle.lefthalf.filled"
        }
    }
}
