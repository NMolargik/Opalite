//
//  CanvasShapeGeometry.swift
//  OpaliteFeatureCanvas
//
//  The outline polylines for every `CanvasShape`, sized by an explicit width/height,
//  centered and rotated. PencilKit-free so the geometry is host-testable; the stroke
//  factory turns these polylines into `PKStroke`s.
//

import Foundation
import CoreGraphics
import OpaliteCore

nonisolated enum CanvasShapeGeometry {
    /// The t-shirt outline as SVG path data in a 1260 × 1000 space.
    static let shirtPathData = "M 305,4 L 5,351 L 219,496 L 308,394 V 996 H 953 V 394 L 1041,496 L 1255,351 L 956,4 H 850 C 807,92 725,151 630,151 C 535,151 453,92 410,4 Z"
    static let shirtNativeSize = CGSize(width: 1260, height: 1000)

    /// Outline polylines for `shape` filling a `width` × `height` box centered at `center`,
    /// rotated by `rotation` radians about that center. Corners are tripled so PencilKit
    /// renders them sharp.
    static func polylines(for shape: CanvasShape, center: CGPoint, width: CGFloat, height: CGFloat, rotation: CGFloat = 0) -> [[CGPoint]] {
        let w = max(width, 1), h = max(height, 1)
        let halfW = w / 2, halfH = h / 2
        let raw: [[CGPoint]]

        switch shape {
        case .square, .rectangle:
            raw = [closedPolygon([
                CGPoint(x: center.x - halfW, y: center.y - halfH),
                CGPoint(x: center.x + halfW, y: center.y - halfH),
                CGPoint(x: center.x + halfW, y: center.y + halfH),
                CGPoint(x: center.x - halfW, y: center.y + halfH),
            ])]
        case .circle:
            let segments = max(36, Int((w + h) / 8))
            raw = [(0...segments).map { step in
                let angle = CGFloat(step) / CGFloat(segments) * 2 * .pi
                return CGPoint(x: center.x + cos(angle) * halfW, y: center.y + sin(angle) * halfH)
            }]
        case .triangle:
            raw = [closedPolygon([
                CGPoint(x: center.x, y: center.y - halfH),
                CGPoint(x: center.x + halfW, y: center.y + halfH),
                CGPoint(x: center.x - halfW, y: center.y + halfH),
            ])]
        case .line:
            raw = [[CGPoint(x: center.x - halfW, y: center.y), CGPoint(x: center.x + halfW, y: center.y)]]
        case .arrow:
            let tip = CGPoint(x: center.x + halfW, y: center.y)
            let head = min(w * 0.25, halfH)
            raw = [
                [CGPoint(x: center.x - halfW, y: center.y), tip],
                [tip, CGPoint(x: tip.x - head, y: center.y - head)],
                [tip, CGPoint(x: tip.x - head, y: center.y + head)],
            ]
        case .shirt:
            raw = shirtPolylines(center: center, width: w, height: h)
        }

        guard rotation != 0 else { return raw }
        return raw.map { $0.map { PathSampling.rotate($0, around: center, by: rotation) } }
    }

    /// Polylines for arbitrary SVG paths fitted into a `width` × `height` box at `center`.
    static func polylines(forSVGPaths paths: [CGPath], svgBounds: CGRect, center: CGPoint, width: CGFloat, height: CGFloat, rotation: CGFloat = 0, spacing: CGFloat = PathSampling.defaultSpacing) -> [[CGPoint]] {
        guard svgBounds.width > 0, svgBounds.height > 0 else { return [] }
        let scaleX = max(width, 1) / svgBounds.width
        let scaleY = max(height, 1) / svgBounds.height
        let svgCenter = CGPoint(x: svgBounds.midX, y: svgBounds.midY)
        // Sample in source units at a spacing that yields the target density.
        let sourceSpacing = spacing / max(scaleX, scaleY)
        return paths.flatMap { path in
            PathSampling.polylines(from: path, spacing: sourceSpacing).map { polyline in
                polyline.map { point in
                    let placed = CGPoint(x: center.x + (point.x - svgCenter.x) * scaleX, y: center.y + (point.y - svgCenter.y) * scaleY)
                    return PathSampling.rotate(placed, around: center, by: rotation)
                }
            }
        }
    }

    // MARK: - Helpers

    private static func shirtPolylines(center: CGPoint, width: CGFloat, height: CGFloat) -> [[CGPoint]] {
        guard let path = SVGPathParser().parsePathData(shirtPathData) else { return [] }
        return polylines(forSVGPaths: [path], svgBounds: CGRect(origin: .zero, size: shirtNativeSize), center: center, width: width, height: height)
    }

    /// Repeats each corner three times and closes the loop — PencilKit smooths single
    /// control points into curves; tripling pins the corner.
    private static func closedPolygon(_ corners: [CGPoint]) -> [CGPoint] {
        var points: [CGPoint] = []
        for corner in corners + [corners[0]] {
            points.append(contentsOf: [corner, corner, corner])
        }
        return points
    }
}
