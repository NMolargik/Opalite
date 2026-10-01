//
//  ColorBlindnessMode.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import Foundation

/// Color blindness simulation modes for accessibility testing.
///
/// Allows users to preview how colors appear to people with different types
/// of color vision deficiency. When active, all SwatchViews apply the selected
/// transformation to their displayed colors.
enum ColorBlindnessMode: String, CaseIterable, Identifiable {
    case off
    case protanopia    // Red-blind (~1% of males)
    case deuteranopia  // Green-blind (~1% of males)
    case tritanopia    // Blue-blind (~0.01% of population)
    case achromatopsia // Complete color blindness (monochromacy)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .protanopia: return "Protanopia (Red-blind)"
        case .deuteranopia: return "Deuteranopia (Green-blind)"
        case .tritanopia: return "Tritanopia (Blue-blind)"
        case .achromatopsia: return "Achromatopsia (No Color)"
        }
    }

    var shortTitle: String {
        switch self {
        case .off: return "Normal Vision"
        case .protanopia: return "Protanopia"
        case .deuteranopia: return "Deuteranopia"
        case .tritanopia: return "Tritanopia"
        case .achromatopsia: return "Achromatopsia"
        }
    }

    var modeDescription: String {
        switch self {
        case .off:
            return "No simulation active"
        case .protanopia:
            return "Difficulty distinguishing red from green; red appears darker"
        case .deuteranopia:
            return "Difficulty distinguishing green from red; most common form"
        case .tritanopia:
            return "Difficulty distinguishing blue from yellow; rare form"
        case .achromatopsia:
            return "Complete color blindness; sees only in grayscale (monochromacy)"
        }
    }
}
