//
//  PathSampling.swift
//  OpaliteFeatureCanvas
//
//  Converts geometry into dense polylines — the form PencilKit strokes want. Lines and
//  Béziers are sampled at a fixed spacing; CGPaths split per subpath so distinct closed
//  shapes inside one `<path>` become separate strokes.
//

import Foundation
import CoreGraphics

nonisolated enum PathSampling {
    /// Default spacing between sampled points, in canvas points.
    static let defaultSpacing: CGFloat = 2

    /// Points along a segment, excluding `start`, ending exactly at `end`.
    static func line(from start: CGPoint, to end: CGPoint, spacing: CGFloat = defaultSpacing) -> [CGPoint] {
        let dx = end.x - start.x, dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return [end] }
        let steps = max(1, Int(length / spacing))
        return (1...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        }
    }

    static func quadraticBezier(from start: CGPoint, control: CGPoint, to end: CGPoint, spacing: CGFloat = defaultSpacing) -> [CGPoint] {
        let approxLength = (distance(start, end) + distance(start, control) + distance(control, end)) / 2
        let steps = max(2, Int(approxLength / spacing))
        return (1...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps), u = 1 - t
            return CGPoint(
                x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
            )
        }
    }

    static func cubicBezier(from start: CGPoint, control1: CGPoint, control2: CGPoint, to end: CGPoint, spacing: CGFloat = defaultSpacing) -> [CGPoint] {
        let approxLength = (distance(start, end) + distance(start, control1) + distance(control1, control2) + distance(control2, end)) / 2
        let steps = max(2, Int(approxLength / spacing))
        return (1...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps), u = 1 - t
            return CGPoint(
                x: u * u * u * start.x + 3 * u * u * t * control1.x + 3 * u * t * t * control2.x + t * t * t * end.x,
                y: u * u * u * start.y + 3 * u * u * t * control1.y + 3 * u * t * t * control2.y + t * t * t * end.y
            )
        }
    }

    /// One polyline per subpath of `path` (subpaths with fewer than two points are dropped).
    static func polylines(from path: CGPath, spacing: CGFloat = defaultSpacing) -> [[CGPoint]] {
        var result: [[CGPoint]] = []
        var current: [CGPoint] = []
        var point = CGPoint.zero
        var subpathStart = CGPoint.zero

        func flush() {
            if current.count >= 2 { result.append(current) }
            current = []
        }

        path.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint:
                flush()
                point = element.points[0]
                subpathStart = point
                current = [point]
            case .addLineToPoint:
                let end = element.points[0]
                current.append(contentsOf: line(from: point, to: end, spacing: spacing))
                point = end
            case .addQuadCurveToPoint:
                let end = element.points[1]
                current.append(contentsOf: quadraticBezier(from: point, control: element.points[0], to: end, spacing: spacing))
                point = end
            case .addCurveToPoint:
                let end = element.points[2]
                current.append(contentsOf: cubicBezier(from: point, control1: element.points[0], control2: element.points[1], to: end, spacing: spacing))
                point = end
            case .closeSubpath:
                if point != subpathStart {
                    current.append(contentsOf: line(from: point, to: subpathStart, spacing: spacing))
                }
                point = subpathStart
            @unknown default:
                break
            }
        }
        flush()
        return result
    }

    /// Rotates `point` around `center` by `radians` (clockwise in the flipped UIKit space).
    static func rotate(_ point: CGPoint, around center: CGPoint, by radians: CGFloat) -> CGPoint {
        guard radians != 0 else { return point }
        let dx = point.x - center.x, dy = point.y - center.y
        let c = cos(radians), s = sin(radians)
        return CGPoint(x: center.x + dx * c - dy * s, y: center.y + dx * s + dy * c)
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// The bounding box of a set of polylines (null when empty).
    static func bounds(of polylines: [[CGPoint]]) -> CGRect {
        var minX = CGFloat.infinity, minY = CGFloat.infinity, maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for polyline in polylines {
            for point in polyline {
                minX = min(minX, point.x); minY = min(minY, point.y)
                maxX = max(maxX, point.x); maxY = max(maxY, point.y)
            }
        }
        guard minX.isFinite else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
