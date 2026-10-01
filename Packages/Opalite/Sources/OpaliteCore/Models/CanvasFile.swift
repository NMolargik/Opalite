//
//  CanvasFile.swift
//  OpaliteCore
//
//  A PencilKit drawing with external-storage data blobs and an optional linked palette.
//  PencilKit helpers are guarded so the model also builds for tvOS/watchOS.
//

import Foundation
import CoreGraphics
import SwiftData
#if canImport(PencilKit)
import PencilKit
#endif

@Model
public final class CanvasFile {
    // MARK: - Identity & metadata
    public var id: UUID = UUID()
    public var title: String = "Untitled Canvas"
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var lastEditedDeviceName: String?

    // MARK: - Dimensions (stored so every device agrees on the drawing space)
    public var canvasWidth: Double = 0
    public var canvasHeight: Double = 0

    // MARK: - Blobs
    /// `PKDrawing.dataRepresentation()`.
    @Attribute(.externalStorage) public var drawingData: Data?
    /// JSON-encoded `[CanvasPlacedImage]`.
    @Attribute(.externalStorage) public var placedImagesData: Data?
    /// PNG preview for lists/grids.
    @Attribute(.externalStorage) public var thumbnailData: Data?

    // MARK: - Relationships
    @Relationship(inverse: \OpalitePalette.canvasFile)
    public var palette: OpalitePalette?

    public init(title: String = "Untitled Canvas", drawingData: Data? = nil) {
        self.id = UUID()
        self.title = title
        self.drawingData = drawingData
    }

    #if canImport(PencilKit)
    public convenience init(title: String = "Untitled Canvas", drawing: PKDrawing) {
        self.init(title: title, drawingData: drawing.dataRepresentation())
    }
    #endif
}

// MARK: - Constants

extension CanvasFile {
    /// Default size for new canvases — ample room for complex drawings; devices pan/zoom.
    public static let defaultCanvasSize = CGSize(width: 4096, height: 4096)
}

// MARK: - Dimensions

extension CanvasFile {
    /// The canvas size, or nil before it was first set.
    public var canvasSize: CGSize? {
        guard canvasWidth > 0, canvasHeight > 0 else { return nil }
        return CGSize(width: canvasWidth, height: canvasHeight)
    }

    /// Sets the canvas size once; later calls are ignored to preserve the original space.
    public func setCanvasSize(_ size: CGSize) {
        guard canvasWidth == 0, canvasHeight == 0 else { return }
        canvasWidth = size.width
        canvasHeight = size.height
        updatedAt = Date()
    }

    /// Grows the canvas to contain `size` (never shrinks).
    public func expandCanvasIfNeeded(to size: CGSize) {
        let newWidth = max(canvasWidth, size.width)
        let newHeight = max(canvasHeight, size.height)
        guard newWidth != canvasWidth || newHeight != canvasHeight else { return }
        canvasWidth = newWidth
        canvasHeight = newHeight
        updatedAt = Date()
    }
}

// MARK: - Placed images

extension CanvasFile {
    /// The decoded placed images (empty when none or undecodable).
    public var placedImages: [CanvasPlacedImage] {
        get {
            guard let placedImagesData else { return [] }
            return (try? JSONDecoder().decode([CanvasPlacedImage].self, from: placedImagesData)) ?? []
        }
        set {
            placedImagesData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}

// MARK: - PencilKit

#if canImport(PencilKit)
extension CanvasFile {
    /// The stored drawing, or an empty one when missing/corrupt.
    public func loadDrawing() -> PKDrawing {
        guard let drawingData else { return PKDrawing() }
        return (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }

    /// Persists a drawing and touches `updatedAt`.
    public func saveDrawing(_ drawing: PKDrawing) {
        drawingData = drawing.dataRepresentation()
        updatedAt = Date()
    }
}
#endif

// MARK: - Samples

extension CanvasFile {
    public static var sample: CanvasFile { CanvasFile(title: "Sketch") }
}
