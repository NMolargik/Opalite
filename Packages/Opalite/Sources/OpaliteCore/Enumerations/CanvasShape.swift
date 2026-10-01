//
//  CanvasShape.swift
//  OpaliteCore
//

import Foundation
import CoreGraphics

nonisolated public enum CanvasShape: String, CaseIterable, Identifiable, Sendable {
    case square
    case rectangle
    case circle
    case triangle
    case line
    case arrow
    case shirt

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .square: "square"
        case .rectangle: "rectangle"
        case .circle: "circle"
        case .triangle: "triangle"
        case .line: "line.diagonal"
        case .arrow: "arrow.right"
        case .shirt: "tshirt"
        }
    }

    /// Whether width and height scale independently.
    public var supportsNonUniformScale: Bool { self == .rectangle }

    /// Aspect ratio (width/height) enforced while dragging to define the shape; nil = free.
    public var constrainedAspectRatio: CGFloat? {
        switch self {
        case .square, .circle: 1.0
        case .triangle: 1.0 / 0.866
        case .shirt: 1260.0 / 1000.0
        case .rectangle, .line, .arrow: nil
        }
    }

    /// Keyboard shortcut number for the menu bar (⇧⌘N), nil for shapes without one.
    public var keyboardNumber: Int? {
        switch self {
        case .square: 1
        case .circle: 2
        case .triangle: 3
        case .line: 4
        case .arrow: 5
        case .rectangle, .shirt: nil
        }
    }
}
