//
//  CanvasPlacedImage.swift
//  OpaliteCore
//
//  A discrete image object placed on a canvas (position/size/rotation/z-order). The image
//  bytes are PNG. Image-creation helpers live in the Canvas feature (UIKit).
//

import Foundation
import CoreGraphics

nonisolated public struct CanvasPlacedImage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    /// PNG bytes.
    public var imageData: Data
    /// Center in canvas coordinates.
    public var position: CGPoint
    /// Size in canvas coordinates.
    public var size: CGSize
    /// Rotation in degrees.
    public var rotation: Double
    /// Layer order (lower is behind).
    public var zIndex: Int
    public var placedAt: Date

    public init(
        id: UUID = UUID(),
        imageData: Data,
        position: CGPoint,
        size: CGSize,
        rotation: Double = 0,
        zIndex: Int = 0,
        placedAt: Date = Date()
    ) {
        self.id = id
        self.imageData = imageData
        self.position = position
        self.size = size
        self.rotation = rotation
        self.zIndex = zIndex
        self.placedAt = placedAt
    }

    /// The bounding rect in canvas coordinates.
    public var boundingRect: CGRect {
        CGRect(x: position.x - size.width / 2, y: position.y - size.height / 2, width: size.width, height: size.height)
    }

    /// Scales `imageSize` to fit within `maxSize` preserving aspect ratio.
    public static func fittedSize(for imageSize: CGSize, maxSize: CGSize = CGSize(width: 400, height: 400)) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let aspect = imageSize.width / imageSize.height
        var target = imageSize
        if target.width > maxSize.width {
            target.width = maxSize.width
            target.height = maxSize.width / aspect
        }
        if target.height > maxSize.height {
            target.height = maxSize.height
            target.width = maxSize.height * aspect
        }
        return target
    }

    // MARK: - Codable (flat x/y/width/height keys for forward compatibility)

    enum CodingKeys: String, CodingKey {
        case id, imageData, positionX, positionY, width, height, rotation, zIndex, placedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageData = try container.decode(Data.self, forKey: .imageData)
        position = CGPoint(
            x: try container.decode(Double.self, forKey: .positionX),
            y: try container.decode(Double.self, forKey: .positionY)
        )
        size = CGSize(
            width: try container.decode(Double.self, forKey: .width),
            height: try container.decode(Double.self, forKey: .height)
        )
        rotation = try container.decode(Double.self, forKey: .rotation)
        zIndex = try container.decode(Int.self, forKey: .zIndex)
        placedAt = try container.decode(Date.self, forKey: .placedAt)
    }

    public func encode(to encoder: Encoder) throws {
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
}
