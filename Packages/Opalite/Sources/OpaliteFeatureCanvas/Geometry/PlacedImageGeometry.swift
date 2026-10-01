//
//  PlacedImageGeometry.swift
//  OpaliteFeatureCanvas
//
//  Pure manipulation math for `CanvasPlacedImage`: moving, aspect-locked corner resizing
//  anchored on the opposite corner, rotation nudges, initial placement in the visible
//  region, and the bounds that exports must cover.
//

import Foundation
import CoreGraphics
import OpaliteCore

/// The four corner handles of a selected image.
nonisolated enum PlacedImageHandle: CaseIterable, Sendable, Hashable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    var isTrailing: Bool { self == .topTrailing || self == .bottomTrailing }
    var isBottom: Bool { self == .bottomLeading || self == .bottomTrailing }

    /// The handle's offset from the image center for a given size.
    func offset(for size: CGSize) -> CGPoint {
        CGPoint(x: (isTrailing ? 1 : -1) * size.width / 2, y: (isBottom ? 1 : -1) * size.height / 2)
    }

    var accessibilityName: String {
        switch self {
        case .topLeading: String(localized: "Top leading resize handle")
        case .topTrailing: String(localized: "Top trailing resize handle")
        case .bottomLeading: String(localized: "Bottom leading resize handle")
        case .bottomTrailing: String(localized: "Bottom trailing resize handle")
        }
    }
}

nonisolated enum PlacedImageGeometry {
    /// The smallest side an image can be resized to, in canvas points.
    static let minimumSide: CGFloat = 50
    /// The largest side a freshly inserted image gets (before user resizing).
    static let insertedMaxSide: CGFloat = 400

    /// `image` moved by a drag translation measured in view points at `zoomScale`.
    static func moved(_ image: CanvasPlacedImage, by translation: CGSize, zoomScale: CGFloat) -> CanvasPlacedImage {
        let zoom = max(zoomScale, 0.0001)
        var updated = image
        updated.position = CGPoint(x: image.position.x + translation.width / zoom, y: image.position.y + translation.height / zoom)
        return updated
    }

    /// `image` resized by dragging `handle`, keeping the aspect ratio and pinning the
    /// opposite corner. `startSize`/`startPosition` are the values when the drag began.
    static func resized(_ image: CanvasPlacedImage, handle: PlacedImageHandle, translation: CGSize, zoomScale: CGFloat, startSize: CGSize, startPosition: CGPoint) -> CanvasPlacedImage {
        guard startSize.width > 0, startSize.height > 0 else { return image }
        let zoom = max(zoomScale, 0.0001)
        let dx = translation.width / zoom * (handle.isTrailing ? 1 : -1)
        let dy = translation.height / zoom * (handle.isBottom ? 1 : -1)
        let aspect = startSize.width / startSize.height

        let proposedWidth = max(startSize.width + dx, (startSize.height + dy) * aspect)
        let minimumWidth = aspect >= 1 ? minimumSide * aspect : minimumSide
        let width = max(proposedWidth, minimumWidth)
        let height = width / aspect

        let anchor = CGPoint(
            x: startPosition.x - (handle.isTrailing ? 1 : -1) * startSize.width / 2,
            y: startPosition.y - (handle.isBottom ? 1 : -1) * startSize.height / 2
        )
        var updated = image
        updated.size = CGSize(width: width, height: height)
        updated.position = CGPoint(
            x: anchor.x + (handle.isTrailing ? 1 : -1) * width / 2,
            y: anchor.y + (handle.isBottom ? 1 : -1) * height / 2
        )
        return updated
    }

    /// `image` rotated by `degrees`, normalized to 0..<360.
    static func rotated(_ image: CanvasPlacedImage, by degrees: Double) -> CanvasPlacedImage {
        var updated = image
        var value = (image.rotation + degrees).truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        updated.rotation = value
        return updated
    }

    /// Position and size for a new image of `pixelSize` dropped into `visibleRect`: fitted to
    /// the smaller of `insertedMaxSide` and 70% of the visible region, centered.
    static func initialPlacement(for pixelSize: CGSize, in visibleRect: CGRect) -> (position: CGPoint, size: CGSize) {
        let limit = min(insertedMaxSide, max(visibleRect.width, visibleRect.height) * 0.7)
        let size = CanvasPlacedImage.fittedSize(for: pixelSize, maxSize: CGSize(width: limit, height: limit))
        return (CGPoint(x: visibleRect.midX, y: visibleRect.midY), size)
    }

    /// The next z-index above every image in `images`.
    static func nextZIndex(after images: [CanvasPlacedImage]) -> Int {
        (images.map(\.zIndex).max() ?? -1) + 1
    }

    /// The axis-aligned bounds of `image` after rotation.
    static func rotatedBounds(of image: CanvasPlacedImage) -> CGRect {
        let radians = image.rotation * .pi / 180
        let corners = PlacedImageHandle.allCases.map { handle -> CGPoint in
            let offset = handle.offset(for: image.size)
            return PathSampling.rotate(CGPoint(x: image.position.x + offset.x, y: image.position.y + offset.y), around: image.position, by: radians)
        }
        return PathSampling.bounds(of: [corners])
    }

    /// The union of every image's rotated bounds (null when empty).
    static func unionBounds(of images: [CanvasPlacedImage]) -> CGRect {
        images.reduce(CGRect.null) { $0.union(rotatedBounds(of: $1)) }
    }
}
