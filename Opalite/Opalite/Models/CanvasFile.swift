//
//  CanvasFile.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import Foundation
import SwiftData
import PencilKit

@Model
final class CanvasFile {
    // MARK: - Identity & Metadata (CloudKit-friendly)
    var id: UUID = UUID()
    
    var title: String = "Untitled Canvas"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Optional bookkeeping for future conflict/debug use
    var lastEditedDeviceName: String? = nil

    // MARK: - Canvas Dimensions
    // Store the canvas size to maintain consistency across devices
    var canvasWidth: Double = 0
    var canvasHeight: Double = 0

    // MARK: - PencilKit Drawing Data
    // Store rich, editable drawing data (PKDrawing.dataRepresentation())
    @Attribute(.externalStorage)
    var drawingData: Data? = nil

    // Optional lightweight preview for lists/grids
    @Attribute(.externalStorage)
    var thumbnailData: Data? = nil

    // MARK: - Init
    init(
        title: String = "Untitled Canvas",
        drawing: PKDrawing = PKDrawing()
    ) {
        self.id = UUID()
        self.title = title
        self.drawingData = drawing.dataRepresentation()
    }
}

// MARK: - Convenience Helpers
extension CanvasFile {
    /// Reconstruct a PKDrawing for editing/display
    func loadDrawing() -> PKDrawing {
        guard let drawingData,
              let drawing = try? PKDrawing(data: drawingData) else {
            return PKDrawing()
        }
        return drawing
    }

    /// Persist changes from a Canvas/PencilKit view
    func saveDrawing(_ drawing: PKDrawing) {
        self.drawingData = drawing.dataRepresentation()
        self.updatedAt = Date()
    }

    /// Get the canvas size, or nil if not yet set
    var canvasSize: CGSize? {
        guard canvasWidth > 0 && canvasHeight > 0 else { return nil }
        return CGSize(width: canvasWidth, height: canvasHeight)
    }

    /// Set the canvas size (typically done once when first opened or when placing content)
    func setCanvasSize(_ size: CGSize) {
        // Only set if not already set, to preserve original canvas dimensions
        guard canvasWidth == 0 && canvasHeight == 0 else { return }
        self.canvasWidth = size.width
        self.canvasHeight = size.height
        self.updatedAt = Date()
    }

    /// Force update the canvas size (for expanding canvas to fit content)
    func expandCanvasIfNeeded(to size: CGSize) {
        let newWidth = max(canvasWidth, size.width)
        let newHeight = max(canvasHeight, size.height)
        if newWidth != canvasWidth || newHeight != canvasHeight {
            self.canvasWidth = newWidth
            self.canvasHeight = newHeight
            self.updatedAt = Date()
        }
    }
}
