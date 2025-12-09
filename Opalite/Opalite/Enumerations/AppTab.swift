//
//  AppTab.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case palette = "Palette"
    case swatch = "Swatches"
    case canvas = "Canvas"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    func icon() -> Image {
        switch self {
        case .palette:
            return Image(systemName: "paintpalette")
        case .swatch:
            return Image(systemName: "square.stack")
        case .canvas:
            return Image(systemName: "pencil.and.scribble")
        case .settings:
            return Image(systemName: "gear")
        }
    }
}
