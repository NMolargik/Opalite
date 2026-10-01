//
//  CanvasExport.swift
//  OpaliteFeatureCanvas
//
//  Renders the drawing plus placed images to a PNG cropped around the content, and the
//  `Transferable` that lets `ShareLink` hand that PNG to the share sheet lazily.
//

#if canImport(PencilKit) && (os(iOS) || os(visionOS))
import SwiftUI
import UIKit
import PencilKit
import CoreTransferable
import UniformTypeIdentifiers
import OpaliteCore

enum CanvasImageRenderer {
    /// A white-backed image of the content region, or nil when the canvas is empty.
    static func render(drawing: PKDrawing, images: [CanvasPlacedImage], canvasSize: CGSize, scale: CGFloat) -> UIImage? {
        guard let rect = CanvasExportGeometry.exportRect(drawingBounds: drawing.bounds, images: images, canvasSize: canvasSize) else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)
        let inkImage = drawing.image(from: rect, scale: scale)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: rect.size))
            for image in images.sorted(by: { $0.zIndex < $1.zIndex }) {
                guard let uiImage = UIImage(data: image.imageData) else { continue }
                let cg = context.cgContext
                cg.saveGState()
                cg.translateBy(x: image.position.x - rect.minX, y: image.position.y - rect.minY)
                cg.rotate(by: image.rotation * .pi / 180)
                uiImage.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
                cg.restoreGState()
            }
            inkImage.draw(at: .zero)
        }
    }
}

/// The lazily rendered PNG a `ShareLink` exports.
nonisolated struct CanvasImageExport: Transferable, Sendable {
    let title: String
    let drawingData: Data
    let images: [CanvasPlacedImage]
    let canvasSize: CGSize
    let scale: CGFloat

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { export in
            try await MainActor.run { try export.renderPNG() }
        }
        .suggestedFileName { "\($0.title).png" }
    }

    @MainActor
    func renderPNG() throws -> Data {
        let drawing = (try? PKDrawing(data: drawingData)) ?? PKDrawing()
        guard let image = CanvasImageRenderer.render(drawing: drawing, images: images, canvasSize: canvasSize, scale: scale),
              let data = image.pngData() else {
            throw OpaliteError.exportFailed(reason: String(localized: "The canvas is empty"))
        }
        return data
    }
}
#endif
