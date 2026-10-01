//
//  CanvasExportGeometry.swift
//  OpaliteFeatureCanvas
//
//  Where an exported PNG is cropped: the union of the ink bounds and the placed images,
//  padded, clamped to the canvas.
//

import Foundation
import CoreGraphics
import OpaliteCore

nonisolated enum CanvasExportGeometry {
    static let padding: CGFloat = 40

    /// The crop rect for an export, or nil when there is nothing to export.
    static func exportRect(drawingBounds: CGRect, images: [CanvasPlacedImage], canvasSize: CGSize) -> CGRect? {
        var content = CGRect.null
        if !drawingBounds.isNull, !drawingBounds.isEmpty { content = content.union(drawingBounds) }
        let imageBounds = PlacedImageGeometry.unionBounds(of: images)
        if !imageBounds.isNull { content = content.union(imageBounds) }
        guard !content.isNull, content.width > 0 || content.height > 0 else { return nil }
        let padded = content.insetBy(dx: -padding, dy: -padding)
        let canvas = CGRect(origin: .zero, size: canvasSize)
        let clamped = canvas.isEmpty ? padded : padded.intersection(canvas)
        return clamped.isNull || clamped.isEmpty ? padded : clamped
    }
}
