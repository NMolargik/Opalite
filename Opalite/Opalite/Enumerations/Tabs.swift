//
//  Tabs.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

enum Tabs: Equatable, Hashable, Identifiable {
    case portfolio
    case canvas
    case settings
    case search
    case swatchBar
    case canvasBody(CanvasFile?)

    var id: Int {
        switch self {
        case .portfolio: 2001
        case .canvas: 2002
        case .settings: 2003
        case .search: 2004
        case .swatchBar: 2005
        case .canvasBody: 2006
        }
    }

    var name: String {
        switch self {
        case .portfolio: String(localized: "Portfolio", comment: "Tab title")
        case .canvas: String(localized: "Canvas", comment: "Tab title")
        case .settings: String(localized: "Settings", comment: "Tab title")
        case .search: String(localized: "Search", comment: "Tab title")
        case .swatchBar: String(localized: "SwatchBar", comment: "Tab title")
        case .canvasBody: String(localized: "Canvas", comment: "Tab title")
        }
    }

    var symbol: String {
        switch self {
        case .portfolio: "paintpalette.fill"
        case .canvas: "pencil.and.scribble"
        case .settings: "gear"
        case .search: "magnifyingglass"
        case .swatchBar: "square.stack"
        case .canvasBody: "scribble.variable"
        }
    }

    func symbolColor() -> Color {
        switch self {
        case .portfolio:
            return .blue
        case .canvas:
            return .red
        case .settings:
            return .orange
        case .search:
            return .green
        case .swatchBar:
            return .purple
        case .canvasBody:
            return .red
        }
    }

    var isSecondary: Bool {
        switch self {
        case .portfolio, .canvas, .settings, .search, .swatchBar:
            false
        case .canvasBody:
            true
        }
    }
}
