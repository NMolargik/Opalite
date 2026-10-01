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
    ///   - aspectRatio: Optional aspect ratio (width/height) for shapes that support non-uniform scaling
    /// - Returns: An array of PKStroke objects representing the shape
    func generateStrokes(
        for shape: CanvasShape,
        center: CGPoint,
        size: CGFloat,
        ink: PKInk,
        rotation: Angle = .zero,
        aspectRatio: CGFloat = 1.0
    ) -> [PKStroke] {
        switch shape {
        case .arrow:
            return createArrowStrokes(center: center, size: size, ink: ink, rotation: rotation)
        case .shirt:
            return createShirtStrokes(center: center, size: size, ink: ink, rotation: rotation)
        case .rectangle:
            let points = generateRectanglePoints(center: center, size: size, aspectRatio: aspectRatio, rotation: rotation)
            if let stroke = createStroke(from: points, ink: ink) {
                return [stroke]
            }
            return []
        default:
            let points = generateShapePoints(for: shape, center: center, size: size, rotation: rotation)
            if let stroke = createStroke(from: points, ink: ink) {
                return [stroke]
            }
            return []
        }
    }

    /// Generates PencilKit strokes for a shape defined by explicit width and height.
    ///
    /// Converts to the existing `size` + `aspectRatio` API internally:
    /// `size = height`, `aspectRatio = width / height`.
    ///
    /// - Parameters:
    ///   - shape: The type of shape to generate
    ///   - center: The center point of the shape on the canvas
    ///   - width: The explicit width of the bounding box
    ///   - height: The explicit height of the bounding box
    ///   - ink: The PencilKit ink to use for the strokes
    ///   - rotation: Optional rotation angle for the shape
    /// - Returns: An array of PKStroke objects representing the shape
    func generateStrokes(
        for shape: CanvasShape,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        ink: PKInk,
        rotation: Angle = .zero
    ) -> [PKStroke] {
        // Line and arrow use `size` as their length (width), not height.
        // All other shapes use `size` as height with aspectRatio = width/height.
        let size: CGFloat
        let aspectRatio: CGFloat
        switch shape {
        case .line, .arrow:
            size = width
            aspectRatio = 1.0
        case .triangle:
            // generateTrianglePoints interprets size as the base width,
            // then derives height as size * 0.866
            size = width
            aspectRatio = 1.0
        default:
            size = height
            aspectRatio = height > 0 ? width / height : 1.0
        }
        return generateStrokes(
            for: shape,
            center: center,
            size: size,
            ink: ink,
            rotation: rotation,
            aspectRatio: aspectRatio
        )
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

        case .rectangle:
            // Rectangle uses the dedicated method with aspectRatio; fallback to square here
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

        case .shirt:
            // Handled separately with curves
            return []
        }

        // Apply rotation if needed
        if rotation != .zero {
            points = points.map { rotatePoint($0, around: center, by: rotation) }
        }

        return points
    }

    // MARK: - Shape-Specific Point Generation

    /// Generates points for a rectangle with independent width and height.
    ///
    /// - Parameters:
    ///   - center: The center point of the rectangle
    ///   - size: The base size (used as height reference)
    ///   - aspectRatio: Width divided by height (1.0 = square, 2.0 = twice as wide)
    ///   - rotation: Optional rotation angle
    /// - Returns: An array of CGPoints defining the rectangle outline
    private func generateRectanglePoints(
        center: CGPoint,
        size: CGFloat,
        aspectRatio: CGFloat,
        rotation: Angle = .zero
    ) -> [CGPoint] {
        let halfHeight = size / 2
        let halfWidth = halfHeight * aspectRatio

        let topLeft = CGPoint(x: center.x - halfWidth, y: center.y - halfHeight)
        let topRight = CGPoint(x: center.x + halfWidth, y: center.y - halfHeight)
        let bottomRight = CGPoint(x: center.x + halfWidth, y: center.y + halfHeight)
        let bottomLeft = CGPoint(x: center.x - halfWidth, y: center.y + halfHeight)

        // Triple duplicate corner points for truly sharp edges
        var points = [
            topLeft, topLeft, topLeft,
            topRight, topRight, topRight,
            bottomRight, bottomRight, bottomRight,
            bottomLeft, bottomLeft, bottomLeft,
            topLeft, topLeft, topLeft
        ]

        // Apply rotation if needed
        if rotation != .zero {
            points = points.map { rotatePoint($0, around: center, by: rotation) }
        }

        return points
    }

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

    // MARK: - Shirt Shape Generation

    /// Creates strokes for a t-shirt shape.
    ///
    /// Based on SVG path: M 305,4 5,351 219,496 308,394 V 996 H 953 V 394 L 1041,496 1255,351 956,4 H 850 A 248,248 0 0 1 630,151 C 535,151 453,92 410,4 Z
    /// Original SVG dimensions: 1260x1000
    ///
    /// - Parameters:
    ///   - center: The center point of the shirt
    ///   - size: The size of the shirt (height)
    ///   - ink: The PencilKit ink to use
    ///   - rotation: Optional rotation angle
    /// - Returns: An array of PKStroke objects forming the shirt
    private func createShirtStrokes(
        center: CGPoint,
        size: CGFloat,
        ink: PKInk,
        rotation: Angle = .zero
    ) -> [PKStroke] {
        // Original SVG dimensions and center
        let svgWidth: CGFloat = 1260
        let svgHeight: CGFloat = 1000
        let svgCenterX: CGFloat = svgWidth / 2  // 630
        let svgCenterY: CGFloat = svgHeight / 2  // 500

        // Scale factor to fit the requested size (based on height)
        let scale = size / svgHeight

        // Helper to transform SVG coordinates to canvas coordinates
        func transform(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            var point = CGPoint(
                x: center.x + (x - svgCenterX) * scale,
                y: center.y + (y - svgCenterY) * scale
            )
            if rotation != .zero {
                point = rotatePoint(point, around: center, by: rotation)
            }
            return point
        }

        var points: [CGPoint] = []

        // M 305,4 - Start point
        points.append(transform(305, 4))

        // L 5,351 - Left sleeve top
        points.append(contentsOf: sampleLine(from: transform(305, 4), to: transform(5, 351)))

        // L 219,496 - Left sleeve bottom
        points.append(contentsOf: sampleLine(from: transform(5, 351), to: transform(219, 496)))

        // L 308,394 - Left armpit
        points.append(contentsOf: sampleLine(from: transform(219, 496), to: transform(308, 394)))

        // V 996 - Left side down
        points.append(contentsOf: sampleLine(from: transform(308, 394), to: transform(308, 996)))

        // H 953 - Bottom
        points.append(contentsOf: sampleLine(from: transform(308, 996), to: transform(953, 996)))

        // V 394 - Right side up
        points.append(contentsOf: sampleLine(from: transform(953, 996), to: transform(953, 394)))

        // L 1041,496 - Right armpit
        points.append(contentsOf: sampleLine(from: transform(953, 394), to: transform(1041, 496)))

        // L 1255,351 - Right sleeve bottom
        points.append(contentsOf: sampleLine(from: transform(1041, 496), to: transform(1255, 351)))

        // L 956,4 - Right sleeve top
        points.append(contentsOf: sampleLine(from: transform(1255, 351), to: transform(956, 4)))

        // H 850 - Right shoulder
        points.append(contentsOf: sampleLine(from: transform(956, 4), to: transform(850, 4)))

        // A 248,248 0 0 1 630,151 - Right side of neckline (arc)
        // Mirror the left neckline's cubic bezier (C 535,151 453,92 410,4) for symmetry
        // Left goes from (630,151) to (410,4) with controls at (535,151) and (453,92)
        // Right mirrors: from (850,4) to (630,151) with controls at (807,92) and (725,151)
        points.append(contentsOf: sampleCubicBezier(
            from: transform(850, 4),
            control1: transform(807, 92),
            control2: transform(725, 151),
            to: transform(630, 151),
            distance: 2.0
        ))

        // C 535,151 453,92 410,4 - Left side of neckline (cubic bezier)
        points.append(contentsOf: sampleCubicBezier(
            from: transform(630, 151),
            control1: transform(535, 151),
            control2: transform(453, 92),
            to: transform(410, 4),
            distance: 2.0
        ))

        // Z - Close path back to start
        points.append(contentsOf: sampleLine(from: transform(410, 4), to: transform(305, 4)))

        if let stroke = createStroke(from: points, ink: ink) {
            return [stroke]
        }
        return []
    }

    /// Samples points along a line for shirt shape
    private func sampleLine(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        var points: [CGPoint] = []
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        let distance: CGFloat = 2.0

        guard length > 0 else { return [end] }

        let numSteps = max(1, Int(length / distance))
        for i in 1...numSteps {
            let t = CGFloat(i) / CGFloat(numSteps)
            points.append(CGPoint(x: start.x + t * dx, y: start.y + t * dy))
        }
        return points
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

    // MARK: - SVG Stroke Generation

    /// Generates PencilKit strokes from SVG paths.
    ///
    /// - Parameters:
    ///   - paths: The CGPath objects parsed from the SVG
    ///   - svgBounds: The bounds of the original SVG for proper scaling
    ///   - center: The center point where the SVG should be placed
    ///   - size: The target size (height) of the SVG
    ///   - ink: The PencilKit ink to use for the strokes
    ///   - rotation: Optional rotation angle for the SVG
    /// - Returns: An array of PKStroke objects representing the SVG
    func generateSVGStrokes(
        from paths: [CGPath],
        svgBounds: CGRect,
        center: CGPoint,
        size: CGFloat,
        ink: PKInk,
        rotation: Angle = .zero
    ) -> [PKStroke] {
        var strokes: [PKStroke] = []

        // Calculate the scale factor to fit the SVG to the target size
        let scaleFactor = size / svgBounds.height

        // Calculate the center of the SVG bounds
        let svgCenter = CGPoint(
            x: svgBounds.midX,
            y: svgBounds.midY
        )

        for cgPath in paths {
            // Split each CGPath into separate subpaths so distinct closed shapes
            // within the same <path> element become independent strokes.
            let subpaths = sampleSubpathsFromPath(cgPath, samplingDistance: 2.0)

            for points in subpaths {
                guard !points.isEmpty else { continue }

                // Transform points: scale, center, and rotate
                let transformedPoints = points.map { point -> CGPoint in
                    // Scale relative to SVG center
                    var scaled = CGPoint(
                        x: (point.x - svgCenter.x) * scaleFactor + center.x,
                        y: (point.y - svgCenter.y) * scaleFactor + center.y
                    )

                    // Apply rotation if needed
                    if rotation != .zero {
                        scaled = rotatePoint(scaled, around: center, by: rotation)
                    }

                    return scaled
                }

                if let stroke = createStroke(from: transformedPoints, ink: ink) {
                    strokes.append(stroke)
                }
            }
        }

        return strokes
    }

    /// Samples points along a CGPath at regular intervals, splitting on each subpath
    /// so that distinct closed shapes within the same CGPath are returned separately.
    ///
    /// - Parameters:
    ///   - path: The CGPath to sample
    ///   - samplingDistance: The distance between sampled points
    /// - Returns: An array of point arrays — one per subpath
    private func sampleSubpathsFromPath(_ path: CGPath, samplingDistance: CGFloat) -> [[CGPoint]] {
        var subpaths: [[CGPoint]] = []
        var currentSubpath: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                // Flush the previous subpath if it has content
                if currentSubpath.count >= 2 {
                    subpaths.append(currentSubpath)
                }
                currentPoint = element.points[0]
                subpathStart = currentPoint
                currentSubpath = [currentPoint]

            case .addLineToPoint:
                let endPoint = element.points[0]
                let linePoints = sampleLine(from: currentPoint, to: endPoint, distance: samplingDistance)
                currentSubpath.append(contentsOf: linePoints)
                currentPoint = endPoint

            case .addQuadCurveToPoint:
                let controlPoint = element.points[0]
                let endPoint = element.points[1]
                let curvePoints = sampleQuadraticBezier(
                    from: currentPoint,
                    control: controlPoint,
                    to: endPoint,
                    distance: samplingDistance
                )
                currentSubpath.append(contentsOf: curvePoints)
                currentPoint = endPoint

            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let endPoint = element.points[2]
                let curvePoints = sampleCubicBezier(
                    from: currentPoint,
                    control1: control1,
                    control2: control2,
                    to: endPoint,
                    distance: samplingDistance
                )
                currentSubpath.append(contentsOf: curvePoints)
                currentPoint = endPoint

            case .closeSubpath:
                if currentPoint != subpathStart {
                    let linePoints = sampleLine(from: currentPoint, to: subpathStart, distance: samplingDistance)
                    currentSubpath.append(contentsOf: linePoints)
                }
                currentPoint = subpathStart

            @unknown default:
                break
            }
        }

        // Flush final subpath
        if currentSubpath.count >= 2 {
            subpaths.append(currentSubpath)
        }

        return subpaths
    }

    /// Samples points along a straight line.
    private func sampleLine(from start: CGPoint, to end: CGPoint, distance: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)

        guard length > 0 else { return [end] }

        let numSteps = max(1, Int(length / distance))
        for i in 1...numSteps {
            let t = CGFloat(i) / CGFloat(numSteps)
            let point = CGPoint(
                x: start.x + t * dx,
                y: start.y + t * dy
            )
            points.append(point)
        }

        return points
    }

    /// Samples points along a quadratic Bezier curve.
    private func sampleQuadraticBezier(
        from start: CGPoint,
        control: CGPoint,
        to end: CGPoint,
        distance: CGFloat
    ) -> [CGPoint] {
        var points: [CGPoint] = []

        // Estimate curve length for sampling
        let chord = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        let controlDist = sqrt(pow(control.x - start.x, 2) + pow(control.y - start.y, 2)) +
                         sqrt(pow(end.x - control.x, 2) + pow(end.y - control.y, 2))
        let approxLength = (chord + controlDist) / 2

        let numSteps = max(2, Int(approxLength / distance))

        for i in 1...numSteps {
            let t = CGFloat(i) / CGFloat(numSteps)
            let oneMinusT = 1 - t

            // Quadratic Bezier formula: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
            let x = oneMinusT * oneMinusT * start.x +
                   2 * oneMinusT * t * control.x +
                   t * t * end.x
            let y = oneMinusT * oneMinusT * start.y +
                   2 * oneMinusT * t * control.y +
                   t * t * end.y

            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    /// Samples points along a cubic Bezier curve.
    private func sampleCubicBezier(
        from start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        to end: CGPoint,
        distance: CGFloat
    ) -> [CGPoint] {
        var points: [CGPoint] = []

        // Estimate curve length for sampling
        let chord = sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
        let controlDist = sqrt(pow(control1.x - start.x, 2) + pow(control1.y - start.y, 2)) +
                         sqrt(pow(control2.x - control1.x, 2) + pow(control2.y - control1.y, 2)) +
                         sqrt(pow(end.x - control2.x, 2) + pow(end.y - control2.y, 2))
        let approxLength = (chord + controlDist) / 2

        let numSteps = max(2, Int(approxLength / distance))

        for i in 1...numSteps {
            let t = CGFloat(i) / CGFloat(numSteps)
            let oneMinusT = 1 - t

            // Cubic Bezier formula: B(t) = (1-t)³P0 + 3(1-t)²tP1 + 3(1-t)t²P2 + t³P3
            let x = oneMinusT * oneMinusT * oneMinusT * start.x +
                   3 * oneMinusT * oneMinusT * t * control1.x +
                   3 * oneMinusT * t * t * control2.x +
                   t * t * t * end.x
            let y = oneMinusT * oneMinusT * oneMinusT * start.y +
                   3 * oneMinusT * oneMinusT * t * control1.y +
                   3 * oneMinusT * t * t * control2.y +
                   t * t * t * end.y

            points.append(CGPoint(x: x, y: y))
        }

        return points
    }
}
