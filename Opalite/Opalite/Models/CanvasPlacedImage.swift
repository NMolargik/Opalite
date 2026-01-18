//
//  CanvasPlacedImage.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//

import Foundation
import SwiftUI

/// Represents an image placed on a canvas that can be positioned, resized, and deleted.
/// Unlike pixel drawings, placed images are discrete objects that maintain their integrity.
struct CanvasPlacedImage: Identifiable, Codable, Equatable {
    let id: UUID

    /// The image data stored as PNG for lossless quality
    var imageData: Data

    /// Position of the image center in canvas coordinates
    var position: CGPoint

    /// Size of the image in canvas coordinates
    var size: CGSize

    /// Rotation angle in degrees
    var rotation: Double

    /// Order index for layering (lower values are behind)
    var zIndex: Int

    /// When the image was placed
    var placedAt: Date

    init(
        id: UUID = UUID(),
        imageData: Data,
        position: CGPoint,
        size: CGSize,
        rotation: Double = 0,
        zIndex: Int = 0
    ) {
        self.id = id
        self.imageData = imageData
        self.position = position
        self.size = size
        self.rotation = rotation
        self.zIndex = zIndex
        self.placedAt = Date()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, imageData, positionX, positionY, width, height, rotation, zIndex, placedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageData = try container.decode(Data.self, forKey: .imageData)
        let x = try container.decode(Double.self, forKey: .positionX)
        let y = try container.decode(Double.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)
        let w = try container.decode(Double.self, forKey: .width)
        let h = try container.decode(Double.self, forKey: .height)
        size = CGSize(width: w, height: h)
        rotation = try container.decode(Double.self, forKey: .rotation)
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        placedAt = try container.decode(Date.self, forKey: .placedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(imageData, forKey: .imageData)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(placedAt, forKey: .placedAt)
    }

    // MARK: - Helpers

    /// Returns the UIImage from the stored data
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }

    /// Returns the bounding rect in canvas coordinates
    var boundingRect: CGRect {
        CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Creates a placed image from a UIImage with initial positioning
    static func from(
        _ image: UIImage,
        at position: CGPoint,
        maxSize: CGSize = CGSize(width: 400, height: 400)
    ) -> CanvasPlacedImage? {
        // Scale image to fit within maxSize while maintaining aspect ratio
        let aspectRatio = image.size.width / image.size.height
        var targetSize = image.size

        if targetSize.width > maxSize.width {
            targetSize.width = maxSize.width
            targetSize.height = maxSize.width / aspectRatio
        }
        if targetSize.height > maxSize.height {
            targetSize.height = maxSize.height
            targetSize.width = maxSize.height * aspectRatio
        }

        // Convert to PNG data
        guard let pngData = image.pngData() else { return nil }

        return CanvasPlacedImage(
            imageData: pngData,
            position: position,
            size: targetSize
        )
    }
}
