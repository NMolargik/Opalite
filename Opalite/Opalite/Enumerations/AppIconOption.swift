//
//  AppIconOption.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import Foundation

/// Options for the app icon appearance.
enum AppIconOption: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }

    /// The alternate icon name to use, or nil for the default (dark) icon.
    var iconName: String? {
        switch self {
        case .dark: return nil  // Default icon (AppIcon)
        case .light: return "AppIcon-Light"
        }
    }
}
