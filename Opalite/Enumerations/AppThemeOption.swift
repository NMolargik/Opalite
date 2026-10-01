//
//  AppThemeOption.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import Foundation

enum AppThemeOption: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
