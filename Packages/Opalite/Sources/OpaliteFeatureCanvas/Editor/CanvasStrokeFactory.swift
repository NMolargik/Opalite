//
//  CanvasStrokeFactory.swift
//  OpaliteFeatureCanvas
//
//  Turns sampled polylines into PencilKit strokes with a uniform pen tip.
//

#if canImport(PencilKit) && (os(iOS) || os(visionOS))
import Foundation
import CoreGraphics
import PencilKit

enum CanvasStrokeFactory {
    /// One stroke per polyline (polylines with fewer than two points are skipped).
    static func strokes(from polylines: [[CGPoint]], ink: PKInk, tipSize: CGFloat = 3) -> [PKStroke] {
        polylines.compactMap { stroke(from: $0, ink: ink, tipSize: tipSize) }
    }

    static func stroke(from points: [CGPoint], ink: PKInk, tipSize: CGFloat = 3) -> PKStroke? {
        guard points.count >= 2 else { return nil }
        let controlPoints = points.enumerated().map { index, point in
            PKStrokePoint(
                location: point,
                timeOffset: TimeInterval(index) * 0.01,
                size: CGSize(width: tipSize, height: tipSize),
                opacity: 1,
                force: 1,
                azimuth: 0,
                altitude: .pi / 2
            )
        }
        return PKStroke(ink: ink, path: PKStrokePath(controlPoints: controlPoints, creationDate: Date()))
    }
}
#endif
