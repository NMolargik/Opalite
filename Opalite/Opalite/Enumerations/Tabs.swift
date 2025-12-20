//
//  Tabs.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

enum Tabs: Equatable, Hashable, Identifiable {
    case portfolio
    case swatchBoard
    case canvas
    case settings
    case search
    case canvasBody(CanvasFile?)
    
    var id: Int {
        switch self {
        case .portfolio: 2001
        case .swatchBoard: 2002
        case .canvas: 2003
        case .settings: 2004
        case .search: 2005
        case .canvasBody(_): 2006
        }
    }
    
    var name: String {
        switch self {
        case .portfolio: String(localized: "Portfolio", comment: "Tab title")
        case .swatchBoard: String(localized: "Swatches ", comment: "Tab title")
        case .canvas: String(localized: "Canvas", comment: "Tab title")
        case .settings: String(localized: "Settings", comment: "Tab title")
        case .search: String(localized: "Search", comment: "Tab title")
        case .canvasBody(_): String(localized: "Canvas", comment: "Tab title")
        }
    }
    
    var symbol: String {
        switch self {
        case.portfolio: "paintpalette.fill"
        case .swatchBoard: "square.stack.fill"
        case .canvas: "pencil.and.scribble"
        case .settings: "gear"
        case .search: "magnifyingglass"
        case .canvasBody(_): "scribble.variable"
        }
    }
    
    func symbolColor() -> Color {
        switch self {
        case .portfolio:
            return .blue
        case .swatchBoard:
            return .purple
        case .canvas:
            return .red
        case .settings:
            return .orange
        case .search:
            return .green
        case .canvasBody(_):
            return .red
        }
    }
    
    var isSecondary: Bool {
        switch self {
        case .portfolio, .swatchBoard, .canvas, .settings, .search:
            false
        case .canvasBody(_):
            true
        }
    }
}
