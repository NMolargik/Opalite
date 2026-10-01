//
//  PreviewBackground.swift
//  OpaliteCore
//
//  Background choices for palette previews. The actual Color lives in the design system;
//  Core keeps the RGB so exports and tests don't need SwiftUI.
//

import Foundation

nonisolated public enum PreviewBackground: String, CaseIterable, Identifiable, Sendable {
    case white
    case black
    case cream
    case lightGray
    case darkGray
    case navy
    case forest
    case burgundy

    public var id: String { rawValue }

    public var rgba: RGBA {
        switch self {
        case .white: RGBA(red: 1, green: 1, blue: 1)
        case .black: RGBA(red: 0, green: 0, blue: 0)
        case .cream: RGBA(red: 0.98, green: 0.96, blue: 0.90)
        case .lightGray: RGBA(red: 0.85, green: 0.85, blue: 0.85)
        case .darkGray: RGBA(red: 0.25, green: 0.25, blue: 0.25)
        case .navy: RGBA(red: 0.10, green: 0.15, blue: 0.30)
        case .forest: RGBA(red: 0.15, green: 0.25, blue: 0.15)
        case .burgundy: RGBA(red: 0.35, green: 0.10, blue: 0.15)
        }
    }

    public var systemImage: String {
        switch self {
        case .white: "sun.max.fill"
        case .black: "moon.fill"
        case .cream: "paintpalette.fill"
        case .lightGray: "cloud.fill"
        case .darkGray: "smoke.fill"
        case .navy: "water.waves"
        case .forest: "leaf.fill"
        case .burgundy: "heart.fill"
        }
    }

    /// Whether overlays should use dark text on this background.
    public var prefersDarkText: Bool {
        switch self {
        case .white, .cream, .lightGray: true
        case .black, .darkGray, .navy, .forest, .burgundy: false
        }
    }

    /// The default for a color scheme (`isDark` = dark mode).
    public static func defaultFor(isDark: Bool) -> PreviewBackground { isDark ? .black : .white }
}
