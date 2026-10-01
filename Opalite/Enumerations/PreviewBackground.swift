//
//  PreviewBackground.swift
//  Opalite
//
//  Created by Nick Molargik on 1/2/26.
//

import SwiftUI

/// Background color options for palette preview display
enum PreviewBackground: String, CaseIterable, Identifiable {
    case white
    case black
    case cream
    case lightGray
    case darkGray
    case navy
    case forest
    case burgundy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        case .cream: return "Cream"
        case .lightGray: return "Light Gray"
        case .darkGray: return "Dark Gray"
        case .navy: return "Navy"
        case .forest: return "Forest"
        case .burgundy: return "Burgundy"
        }
    }

    var color: Color {
        switch self {
        case .white: return Color.white
        case .black: return Color.black
        case .cream: return Color(red: 0.98, green: 0.96, blue: 0.90)
        case .lightGray: return Color(red: 0.85, green: 0.85, blue: 0.85)
        case .darkGray: return Color(red: 0.25, green: 0.25, blue: 0.25)
        case .navy: return Color(red: 0.10, green: 0.15, blue: 0.30)
        case .forest: return Color(red: 0.15, green: 0.25, blue: 0.15)
        case .burgundy: return Color(red: 0.35, green: 0.10, blue: 0.15)
        }
    }

    var iconName: String {
        switch self {
        case .white: return "sun.max.fill"
        case .black: return "moon.fill"
        case .cream: return "paintpalette.fill"
        case .lightGray: return "cloud.fill"
        case .darkGray: return "smoke.fill"
        case .navy: return "water.waves"
        case .forest: return "leaf.fill"
        case .burgundy: return "heart.fill"
        }
    }

    /// The ideal text color for overlays on this background
    var idealTextColor: Color {
        switch self {
        case .white, .cream, .lightGray:
            return .black
        case .black, .darkGray, .navy, .forest, .burgundy:
            return .white
        }
    }

    /// Default background based on the current color scheme
    static func defaultFor(colorScheme: ColorScheme) -> PreviewBackground {
        colorScheme == .dark ? .black : .white
    }
}
