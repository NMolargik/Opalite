//
//  AppearanceOptions.swift
//  OpaliteCore
//
//  Appearance preferences persisted as raw strings. Titles are localized in the UI.
//

import Foundation
import CoreGraphics

nonisolated public enum AppThemeOption: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }
}

nonisolated public enum AppIconOption: String, CaseIterable, Identifiable, Sendable {
    case dark
    case light

    public var id: String { rawValue }

    /// The alternate icon name, or nil for the primary icon.
    public var iconName: String? {
        switch self {
        case .dark: nil
        case .light: "AppIcon-Light"
        }
    }
}

/// Swatch sizes for the Portfolio grid.
nonisolated public enum SwatchSize: String, CaseIterable, Identifiable, Sendable {
    case extraSmall
    case small
    case medium
    case large

    public var id: String { rawValue }

    public var side: CGFloat {
        switch self {
        case .extraSmall: 40
        case .small: 75
        case .medium: 150
        case .large: 250
        }
    }

    public var cornerRadius: CGFloat {
        switch self {
        case .extraSmall: 8
        case .small, .medium, .large: 16
        }
    }

    /// Whether name/hex overlays fit on the swatch.
    public var showsOverlays: Bool { self == .medium || self == .large }

    /// The next size in the cycle (wraps).
    public var next: SwatchSize {
        let all = Self.allCases
        let index = all.firstIndex(of: self)!
        return all[(index + 1) % all.count]
    }

    /// Cycles extraSmall → small → medium only (compact widths can't fit `large`).
    public var nextCompact: SwatchSize {
        switch self {
        case .extraSmall: .small
        case .small: .medium
        case .medium, .large: .extraSmall
        }
    }
}
