//
//  AppTab.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case portfolio = "Portfolio"
    case swatch = "Swatches"
    case canvas = "Canvas"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    func iconName() -> String {
        switch self {
        case .portfolio:
            return "paintpalette"
        case .swatch:
            return "square.stack"
        case .canvas:
            return "pencil.and.scribble"
        case .settings:
            return "gear"
        }
    }
}
