//
//  CanvasShape.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import Foundation

enum CanvasShape: String, CaseIterable {
    case square
    case circle
    case triangle
    case line
    case arrow

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .square: return "square"
        case .circle: return "circle"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        }
    }
}
