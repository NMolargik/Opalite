//
//  OpaliteFileCodec.swift
//  OpaliteCore
//
//  Decodes the native `.opalitecolor` / `.opalitepalette` JSON (shared with the QuickLook
//  and Thumbnail extensions, which only need the color values) and builds import previews
//  against the existing portfolio.
//

import Foundation

nonisolated public enum OpaliteFileError: LocalizedError, Equatable, Sendable {
    case invalidFormat
    case missingRequiredFields
    case fileAccessDenied
    case unsupportedExtension(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: String(localized: "The file format is invalid or corrupted.")
        case .missingRequiredFields: String(localized: "The file is missing required data.")
        case .fileAccessDenied: String(localized: "Unable to access the file.")
        case .unsupportedExtension: String(localized: "Opalite can't open this kind of file.")
        }
    }
}

/// The values a `.opalitecolor` file carries, without touching SwiftData (extensions use this).
nonisolated public struct DecodedColor: Sendable, Equatable {
    public let id: UUID
    public let name: String?
    public let notes: String?
    public let rgba: RGBA
    public let createdByDisplayName: String?
    public let createdOnDeviceName: String?
    public let updatedOnDeviceName: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: UUID, name: String?, notes: String?, rgba: RGBA, createdByDisplayName: String? = nil, createdOnDeviceName: String? = nil, updatedOnDeviceName: String? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.notes = notes
        self.rgba = rgba
        self.createdByDisplayName = createdByDisplayName
        self.createdOnDeviceName = createdOnDeviceName
        self.updatedOnDeviceName = updatedOnDeviceName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// A fresh model object with these values.
    @MainActor
    public func makeModel() -> OpaliteColor {
        OpaliteColor(id: id, name: name, notes: notes, createdByDisplayName: createdByDisplayName, createdOnDeviceName: createdOnDeviceName, updatedOnDeviceName: updatedOnDeviceName, createdAt: createdAt, updatedAt: updatedAt, red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
    }
}

nonisolated public struct DecodedPalette: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let notes: String?
    public let tags: [String]
    public let createdByDisplayName: String?
    public let previewBackgroundRaw: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let colors: [DecodedColor]

    public init(id: UUID, name: String, notes: String?, tags: [String], createdByDisplayName: String?, previewBackgroundRaw: String?, createdAt: Date, updatedAt: Date, colors: [DecodedColor]) {
        self.id = id
        self.name = name
        self.notes = notes
        self.tags = tags
        self.createdByDisplayName = createdByDisplayName
        self.previewBackgroundRaw = previewBackgroundRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colors = colors
    }

    @MainActor
    public func makeModel() -> OpalitePalette {
        let colorModels = colors.map { $0.makeModel() }
        let palette = OpalitePalette(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt, createdByDisplayName: createdByDisplayName, notes: notes, tags: tags, colors: colorModels)
        palette.previewBackgroundRaw = previewBackgroundRaw
        colorModels.forEach { $0.palette = palette }
        return palette
    }
}

nonisolated public enum OpaliteFileCodec {

    // MARK: - Decoding

    public static func decodeColor(from data: Data) throws(OpaliteFileError) -> DecodedColor {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw .invalidFormat }
        return try decodeColor(json: json)
    }

    public static func decodeColor(json: [String: Any]) throws(OpaliteFileError) -> DecodedColor {
        guard let idString = json["id"] as? String, let id = UUID(uuidString: idString),
              let red = json["red"] as? Double, let green = json["green"] as? Double, let blue = json["blue"] as? Double else {
            throw .missingRequiredFields
        }
        return DecodedColor(
            id: id,
            name: json["name"] as? String,
            notes: json["notes"] as? String,
            rgba: RGBA(red: red, green: green, blue: blue, alpha: json["alpha"] as? Double ?? 1),
            createdByDisplayName: json["createdByDisplayName"] as? String,
            createdOnDeviceName: json["createdOnDeviceName"] as? String,
            updatedOnDeviceName: json["updatedOnDeviceName"] as? String,
            createdAt: (json["createdAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .now,
            updatedAt: (json["updatedAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .now
        )
    }

    /// Just the color values (QuickLook/Thumbnail), tolerant of a missing id.
    public static func decodeColorValues(json: [String: Any]) -> RGBA? {
        guard let red = json["red"] as? Double, let green = json["green"] as? Double, let blue = json["blue"] as? Double else { return nil }
        return RGBA(red: red, green: green, blue: blue, alpha: json["alpha"] as? Double ?? 1)
    }

    public static func decodePalette(from data: Data) throws(OpaliteFileError) -> DecodedPalette {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw .invalidFormat }
        guard let idString = json["id"] as? String, let id = UUID(uuidString: idString), let name = json["name"] as? String else {
            throw .missingRequiredFields
        }
        var colors: [DecodedColor] = []
        for dict in json["colors"] as? [[String: Any]] ?? [] {
            colors.append(try decodeColor(json: dict))
        }
        return DecodedPalette(
            id: id,
            name: name,
            notes: json["notes"] as? String,
            tags: json["tags"] as? [String] ?? [],
            createdByDisplayName: json["createdByDisplayName"] as? String,
            previewBackgroundRaw: json["previewBackground"] as? String,
            createdAt: (json["createdAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .now,
            updatedAt: (json["updatedAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? .now,
            colors: colors
        )
    }

    /// Which kind of Opalite file a URL points at, by extension.
    public static func kind(of url: URL) -> Kind? {
        switch url.pathExtension.lowercased() {
        case OpaliteFileType.colorExtension: .color
        case OpaliteFileType.paletteExtension: .palette
        default: nil
        }
    }

    public enum Kind: Sendable { case color, palette }
}

// MARK: - Import previews

/// What importing a color file would do, computed against the existing portfolio.
nonisolated public struct ColorImportPreview: Sendable, Equatable {
    public let color: DecodedColor
    public let existingColorID: UUID?

    public init(color: DecodedColor, existingColorID: UUID?) {
        self.color = color
        self.existingColorID = existingColorID
    }

    /// The same id already exists locally, so the import is skipped.
    public var willSkip: Bool { existingColorID != nil }
}

nonisolated public struct PaletteImportPreview: Sendable, Equatable {
    public let palette: DecodedPalette
    public let existingPaletteID: UUID?
    public let newColors: [DecodedColor]
    public let existingColorIDs: [UUID]

    public init(palette: DecodedPalette, existingPaletteID: UUID?, newColors: [DecodedColor], existingColorIDs: [UUID]) {
        self.palette = palette
        self.existingPaletteID = existingPaletteID
        self.newColors = newColors
        self.existingColorIDs = existingColorIDs
    }

    public var willUpdate: Bool { existingPaletteID != nil }
}

extension OpaliteFileCodec {
    public static func previewColorImport(data: Data, existingColorIDs: Set<UUID>) throws(OpaliteFileError) -> ColorImportPreview {
        let color = try decodeColor(from: data)
        return ColorImportPreview(color: color, existingColorID: existingColorIDs.contains(color.id) ? color.id : nil)
    }

    public static func previewPaletteImport(data: Data, existingPaletteIDs: Set<UUID>, existingColorIDs: Set<UUID>) throws(OpaliteFileError) -> PaletteImportPreview {
        let palette = try decodePalette(from: data)
        let newColors = palette.colors.filter { !existingColorIDs.contains($0.id) }
        let existing = palette.colors.filter { existingColorIDs.contains($0.id) }.map(\.id)
        return PaletteImportPreview(
            palette: palette,
            existingPaletteID: existingPaletteIDs.contains(palette.id) ? palette.id : nil,
            newColors: newColors,
            existingColorIDs: existing
        )
    }
}
