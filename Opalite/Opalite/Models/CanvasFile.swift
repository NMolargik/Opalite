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

    // MARK: - PencilKit Drawing Data
    // Store rich, editable drawing data (PKDrawing.dataRepresentation())
    @Attribute(.externalStorage)
    var drawingData: Data? = nil

    // Optional lightweight preview for lists/grids
    @Attribute(.externalStorage)
    var thumbnailData: Data? = nil

    // MARK: - Background Image (composited placed images)
    @Attribute(.externalStorage)
    var backgroundImageData: Data? = nil

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

    /// Load the background image (composited placed images)
    func loadBackgroundImage() -> UIImage? {
        guard let data = backgroundImageData else { return nil }
        return UIImage(data: data)
    }

    /// Save a background image (composited placed images)
    func saveBackgroundImage(_ image: UIImage?) {
        self.backgroundImageData = image?.pngData()
        self.updatedAt = Date()
    }
}
