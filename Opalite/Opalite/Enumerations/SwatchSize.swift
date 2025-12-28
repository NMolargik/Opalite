//
//  SwatchSize.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

enum SwatchSize: String, CaseIterable, Equatable {
    case small
    case medium
    case large

    var size: CGFloat {
        switch self {
        case .small: return 75
        case .medium: return 150
        case .large: return 250
        }
    }
    
    var showOverlays: Bool {
        switch self {
            case .small: return false
            case .medium: return true
            case .large: return true
        }
    }

    var next: SwatchSize {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return self }
        let nextIndex = all.index(after: idx)
        return nextIndex == all.endIndex ? all.first! : all[nextIndex]
    }

    var accessibilityName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}
