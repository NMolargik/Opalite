//
//  CanvasShapeGenerator.swift
//  Opalite
//
//  Created by Nick Molargik on 12/25/25.
//

import SwiftUI
import PencilKit

// MARK: - CanvasShapeGenerator

/// A utility for generating PencilKit strokes for various geometric shapes.
///
/// This class provides methods to create pre-defined shapes like squares, circles,
/// triangles, arrows, and lines as PencilKit strokes that can be added to a canvas.
///
/// ## Usage
/// ```swift
/// let generator = CanvasShapeGenerator()
/// let strokes = generator.generateStrokes(
///     for: .square,
///     center: CGPoint(x: 200, y: 200),
///     size: 100,
///     ink: PKInk(.pen, color: .black),
///     rotation: .degrees(45)
/// )
/// ```
struct CanvasShapeGenerator {

    // MARK: - Public Methods

    /// Generates PencilKit strokes for the specified shape.
    ///
    /// - Parameters:
    ///   - shape: The type of shape to generate
    ///   - center: The center point of the shape on the canvas
    ///   - size: The size of the shape (width/height for most shapes)
    ///   - ink: The PencilKit ink to use for the strokes
    ///   - rotation: Optional rotation angle for the shape
    /// - Returns: An array of PKStroke objects representing the shape
    func generateStrokes(
        for shape: CanvasShape,
        center: CGPoint,
        size: CGFloat,
        ink: PKInk,
        rotation: Angle = .zero
    ) -> [PKStroke] {
        switch shape {
        case .arrow:
            return createArrowStrokes(center: center, size: size, ink: ink, rotation: rotation)
        default:
            let points = generateShapePoints(for: shape, center: center, size: size, rotation: rotation)
            if let stroke = createStroke(from: points, ink: ink) {
                return [stroke]
            }
            return []
        }
    }

    // MARK: - Point Generation

    /// Generates the corner/edge points for a given shape.
    ///
    /// Points are duplicated at corners to create sharp edges when rendered
    /// as PencilKit strokes.
    ///
    /// - Parameters:
    ///   - shape: The type of shape to generate points for
    ///   - center: The center point of the shape
    ///   - size: The size of the shape
    ///   - rotation: Optional rotation angle
    /// - Returns: An array of CGPoints defining the shape's outline
    func generateShapePoints(
        for shape: CanvasShape,
        center: CGPoint,
        size: CGFloat,
        rotation: Angle = .zero
    ) -> [CGPoint] {
        let halfSize = size / 2
        var points: [CGPoint]

        switch shape {
        case .square:
            points = generateSquarePoints(center: center, halfSize: halfSize)

        case .circle:
            points = generateCirclePoints(center: center, radius: halfSize, segments: 36)

        case .triangle:
            points = generateTrianglePoints(center: center, size: size)

        case .line:
            points = [
                CGPoint(x: center.x - halfSize, y: center.y),
                CGPoint(x: center.x + halfSize, y: center.y)
            ]

        case .arrow:
            // Handled separately with multiple strokes
            return []
        }

        // Apply rotation if needed
        if rotation != .zero {
            points = points.map { rotatePoint($0, around: center, by: rotation) }
        }

        return points
    }

    // MARK: - Shape-Specific Point Generation

    /// Generates points for a square shape with tripled corners for sharp edges.
    private func generateSquarePoints(center: CGPoint, halfSize: CGFloat) -> [CGPoint] {
        let topLeft = CGPoint(x: center.x - halfSize, y: center.y - halfSize)
        let topRight = CGPoint(x: center.x + halfSize, y: center.y - halfSize)
        let bottomRight = CGPoint(x: center.x + halfSize, y: center.y + halfSize)
        let bottomLeft = CGPoint(x: center.x - halfSize, y: center.y + halfSize)

        // Triple duplicate corner points for truly sharp edges
        return [
            topLeft, topLeft, topLeft,
            topRight, topRight, topRight,
            bottomRight, bottomRight, bottomRight,
            bottomLeft, bottomLeft, bottomLeft,
            topLeft, topLeft, topLeft
        ]
    }

    /// Generates points for a circle using the specified number of segments.
    private func generateCirclePoints(center: CGPoint, radius: CGFloat, segments: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        for i in 0...segments {
            let angle = (CGFloat(i) / CGFloat(segments)) * 2 * .pi
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            points.append(CGPoint(x: x, y: y))
        }
        return points
    }

    /// Generates points for an equilateral triangle with tripled corners for sharp edges.
    private func generateTrianglePoints(center: CGPoint, size: CGFloat) -> [CGPoint] {
        let halfSize = size / 2
        let height = size * 0.866 // Equilateral triangle height

        let top = CGPoint(x: center.x, y: center.y - height / 2)
        let bottomRight = CGPoint(x: center.x + halfSize, y: center.y + height / 2)
        let bottomLeft = CGPoint(x: center.x - halfSize, y: center.y + height / 2)

        // Triple duplicate corner points for truly sharp edges
        return [
            top, top, top,
            bottomRight, bottomRight, bottomRight,
            bottomLeft, bottomLeft, bottomLeft,
            top, top, top
        ]
    }

    // MARK: - Complex Shape Generation

    /// Creates strokes for an arrow shape (line with arrowhead).
    ///
    /// - Parameters:
    ///   - center: The center point of the arrow
    ///   - size: The total length of the arrow
    ///   - ink: The PencilKit ink to use
    ///   - rotation: Optional rotation angle
    /// - Returns: An array of PKStroke objects forming the arrow
    private func createArrowStrokes(
        center: CGPoint,
        size: CGFloat,
        ink: PKInk,
        rotation: Angle = .zero
    ) -> [PKStroke] {
        let halfSize = size / 2
        let arrowHeadSize = size * 0.25
        var strokes: [PKStroke] = []

        // Main line
        var linePoints = [
            CGPoint(x: center.x - halfSize, y: center.y),
            CGPoint(x: center.x + halfSize, y: center.y)
        ]
        if rotation != .zero {
            linePoints = linePoints.map { rotatePoint($0, around: center, by: rotation) }
        }
        if let lineStroke = createStroke(from: linePoints, ink: ink) {
            strokes.append(lineStroke)
        }

        // Arrow head top
        var headTop = [
            CGPoint(x: center.x + halfSize, y: center.y),
            CGPoint(x: center.x + halfSize - arrowHeadSize, y: center.y - arrowHeadSize)
        ]
        if rotation != .zero {
            headTop = headTop.map { rotatePoint($0, around: center, by: rotation) }
        }
        if let topStroke = createStroke(from: headTop, ink: ink) {
            strokes.append(topStroke)
        }

        // Arrow head bottom
        var headBottom = [
            CGPoint(x: center.x + halfSize, y: center.y),
            CGPoint(x: center.x + halfSize - arrowHeadSize, y: center.y + arrowHeadSize)
        ]
        if rotation != .zero {
            headBottom = headBottom.map { rotatePoint($0, around: center, by: rotation) }
        }
        if let bottomStroke = createStroke(from: headBottom, ink: ink) {
            strokes.append(bottomStroke)
        }

        return strokes
    }

    // MARK: - Stroke Creation

    /// Creates a PencilKit stroke from an array of points.
    ///
    /// - Parameters:
    ///   - points: The points defining the stroke path
    ///   - ink: The PencilKit ink to use
    /// - Returns: A PKStroke, or nil if fewer than 2 points provided
    func createStroke(from points: [CGPoint], ink: PKInk) -> PKStroke? {
        guard points.count >= 2 else { return nil }

        var strokePoints: [PKStrokePoint] = []
        for (index, point) in points.enumerated() {
            let timeOffset = TimeInterval(index) * 0.01
            let strokePoint = PKStrokePoint(
                location: point,
                timeOffset: timeOffset,
                size: CGSize(width: 3, height: 3),
                opacity: 1.0,
                force: 1.0,
                azimuth: 0,
                altitude: .pi / 2
            )
            strokePoints.append(strokePoint)
        }

        let path = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }

    // MARK: - Geometry Helpers

    /// Rotates a point around a center point by the specified angle.
    ///
    /// - Parameters:
    ///   - point: The point to rotate
    ///   - center: The center of rotation
    ///   - angle: The rotation angle
    /// - Returns: The rotated point
    func rotatePoint(_ point: CGPoint, around center: CGPoint, by angle: Angle) -> CGPoint {
        let radians = CGFloat(angle.radians)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosAngle = CoreGraphics.cos(radians)
        let sinAngle = CoreGraphics.sin(radians)
        let rotatedX = dx * cosAngle - dy * sinAngle
        let rotatedY = dx * sinAngle + dy * cosAngle
        return CGPoint(x: center.x + rotatedX, y: center.y + rotatedY)
    }
}
