//
//  ShapePlacementGeometry.swift
//  OpaliteFeatureCanvas
//
//  The math behind drag-to-define placement: the rect grown from a drag origin under an
//  optional aspect lock, the snap-up for tiny drags and plain taps, rotation snapping,
//  and the view ↔ canvas transform through the scroll offset and zoom.
//

import Foundation
import CoreGraphics

/// The placement flow's three phases.
nonisolated enum ShapePlacementPhase: Sendable, Equatable {
    /// Waiting for the first touch; a hover shows a ghost of the shape.
    case idle
    /// Dragging corner to corner to size the shape.
    case drawing
    /// Sized; one finger moves, two fingers (or Pencil Pro roll) rotate; Place/Cancel.
    case adjusting
}

nonisolated enum ShapePlacementGeometry {
    /// Below this on both axes a drag counts as a tap.
    static let minimumDimension: CGFloat = 20
    /// Size used for a plain tap (the larger axis).
    static let defaultTapSize: CGFloat = 120
    /// Rotation snaps to this many degrees.
    static let rotationIncrementDegrees: CGFloat = 5
    /// Haptics fire each time the snapped rotation crosses a multiple of this.
    static let rotationHapticDegrees: CGFloat = 10

    /// The rect spanned from `origin` to `current`, honoring `aspectRatio` (width / height)
    /// when given. The rect always grows away from the origin.
    static func dragRect(from origin: CGPoint, to current: CGPoint, aspectRatio: CGFloat?) -> CGRect {
        var width = abs(current.x - origin.x)
        var height = abs(current.y - origin.y)
        if let ratio = aspectRatio, ratio > 0 {
            if width / ratio <= height {
                height = width / ratio
            } else {
                width = height * ratio
            }
        }
        let x = current.x >= origin.x ? origin.x : origin.x - width
        let y = current.y >= origin.y ? origin.y : origin.y - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// The final rect after the finger lifts: taps get the default size centered on the
    /// origin; tiny drags snap up to twice the minimum, keeping their center.
    static func finalizedRect(_ rect: CGRect, origin: CGPoint, aspectRatio: CGFloat?) -> CGRect {
        if rect.width < minimumDimension, rect.height < minimumDimension {
            return defaultRect(centeredAt: origin, aspectRatio: aspectRatio)
        }
        let floor = minimumDimension * 2
        guard rect.width < floor || rect.height < floor else { return rect }
        var size = CGSize(width: max(rect.width, floor), height: max(rect.height, floor))
        size = constrained(size, to: aspectRatio)
        return CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    /// The default-size rect for a tap or a hover ghost.
    static func defaultRect(centeredAt point: CGPoint, aspectRatio: CGFloat?, size: CGFloat = defaultTapSize) -> CGRect {
        let fitted = constrained(CGSize(width: size, height: size), to: aspectRatio)
        return CGRect(x: point.x - fitted.width / 2, y: point.y - fitted.height / 2, width: fitted.width, height: fitted.height)
    }

    /// Shrinks the shorter side so `size` matches `aspectRatio` (the larger side wins).
    static func constrained(_ size: CGSize, to aspectRatio: CGFloat?) -> CGSize {
        guard let ratio = aspectRatio, ratio > 0 else { return size }
        return ratio >= 1 ? CGSize(width: size.width, height: size.width / ratio) : CGSize(width: size.height * ratio, height: size.height)
    }

    /// Rotation snapped to the increment, in radians.
    static func snappedRotation(_ radians: CGFloat, incrementDegrees: CGFloat = rotationIncrementDegrees) -> CGFloat {
        let degrees = radians * 180 / .pi
        return (degrees / incrementDegrees).rounded() * incrementDegrees * .pi / 180
    }

    /// The haptic bucket a snapped rotation falls in (a change means "tick").
    static func hapticBucket(forRotation radians: CGFloat) -> Int {
        Int((radians * 180 / .pi / rotationHapticDegrees).rounded(.towardZero))
    }

    /// A rect in the scroll view's visible coordinates mapped into canvas coordinates.
    static func canvasRect(fromViewRect rect: CGRect, contentOffset: CGPoint, zoomScale: CGFloat) -> CGRect {
        let zoom = max(zoomScale, 0.0001)
        return CGRect(
            x: contentOffset.x / zoom + rect.minX / zoom,
            y: contentOffset.y / zoom + rect.minY / zoom,
            width: rect.width / zoom,
            height: rect.height / zoom
        )
    }

    /// The canvas region currently visible for a viewport of `viewportSize`.
    static func visibleCanvasRect(viewportSize: CGSize, contentOffset: CGPoint, zoomScale: CGFloat) -> CGRect {
        canvasRect(fromViewRect: CGRect(origin: .zero, size: viewportSize), contentOffset: contentOffset, zoomScale: zoomScale)
    }
}
