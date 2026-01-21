//
//  CanvasShape.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import Foundation

enum CanvasShape: String, CaseIterable {
    case square
    case rectangle
    case circle
    case triangle
    case line
    case arrow
    case shirt

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .square: return "square"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .shirt: return "tshirt"
        }
    }

    /// Whether this shape supports independent width/height scaling (non-uniform)
    var supportsNonUniformScale: Bool {
        switch self {
        case .rectangle: return true
        default: return false
        }
    }
}
