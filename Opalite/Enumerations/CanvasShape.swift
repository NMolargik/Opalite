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

    /// Aspect ratio (width/height) to enforce during drag-to-define.
    /// Returns `nil` for shapes that allow free-form sizing.
    var constrainedAspectRatio: CGFloat? {
        switch self {
        case .square, .circle:
            return 1.0
        case .triangle:
            return 1.0 / 0.866
        case .shirt:
            return 1260.0 / 1000.0
        case .rectangle, .line, .arrow:
            return nil
        }
    }
}
