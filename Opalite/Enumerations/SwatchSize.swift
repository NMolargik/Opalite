//
//  SwatchSize.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

enum SwatchSize: String, CaseIterable {
    case extraSmall
    case small
    case medium
    case large

    var size: CGFloat {
        switch self {
        case .extraSmall: return 40
        case .small: return 75
        case .medium: return 150
        case .large: return 250
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .extraSmall: return 8
        case .small: return 16
        case .medium: return 16
        case .large: return 16
        }
    }

    var showOverlays: Bool {
        self == .medium || self == .large
    }

    var next: SwatchSize {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return self }
        let nextIndex = all.index(after: idx)
        return nextIndex == all.endIndex ? all.first! : all[nextIndex]
    }

    /// Cycles between extraSmall, small, and medium only (for compact screens)
    var nextCompact: SwatchSize {
        switch self {
        case .extraSmall: return .small
        case .small: return .medium
        case .medium: return .extraSmall
        case .large: return .extraSmall
        }
    }

    var accessibilityName: String {
        switch self {
        case .extraSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}
