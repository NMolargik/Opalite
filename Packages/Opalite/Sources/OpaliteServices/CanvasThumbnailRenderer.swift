//
//  CanvasThumbnailRenderer.swift
//  OpaliteServices
//
//  Renders a PencilKit drawing to a PNG thumbnail (max 400pt, white background) for
//  canvas lists and the tvOS presentation.
//

#if canImport(PencilKit) && canImport(UIKit) && !os(watchOS) && !os(tvOS)
import PencilKit
import UIKit

public enum CanvasThumbnailRenderer {
    public static let maxSide: CGFloat = 400

    public static func thumbnailPNG(for drawing: PKDrawing, canvasSize: CGSize?) -> Data? {
        let sourceSize = canvasSize ?? drawing.bounds.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let scale = min(maxSide / sourceSize.width, maxSide / sourceSize.height, 1)
        let thumbnailSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawingImage = drawing.image(from: CGRect(origin: .zero, size: sourceSize), scale: 1)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))
            drawingImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }.pngData()
    }
}
#endif
