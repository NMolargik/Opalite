//
//  OpalitePalette.swift
//  OpaliteCore
//
//  A named collection of colors with an optional linked canvas. CloudKit-safe: defaults on
//  every attribute, optional relationships.
//

import Foundation
import SwiftData

@Model
public final class OpalitePalette {
    public var id: UUID = UUID()

    // MARK: - Core fields
    public var name: String = ""
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var createdByDisplayName: String?

    // MARK: - User-facing metadata
    public var notes: String?
    public var tags: [String] = []

    /// Preview background (raw `PreviewBackground` value).
    public var previewBackgroundRaw: String?

    /// Whether the palette has been archived (hidden from the main Portfolio).
    public var isArchived: Bool = false

    // MARK: - Relationships
    @Relationship public var colors: [OpaliteColor]? = []
    @Relationship public var canvasFile: CanvasFile?

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        createdByDisplayName: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        isArchived: Bool = false,
        colors: [OpaliteColor] = [],
        canvasFile: CanvasFile? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByDisplayName = createdByDisplayName
        self.notes = notes
        self.tags = tags
        self.isArchived = isArchived
        self.colors = colors
        self.canvasFile = canvasFile
    }
}

// MARK: - Derived

extension OpalitePalette {
    /// Colors sorted by last update (newest first), with a stable tie-break on id.
    public var sortedColors: [OpaliteColor] {
        guard let colors, !colors.isEmpty else { return [] }
        let snapshot = colors.map { (color: $0, date: $0.updatedAt, id: $0.id) }
        return snapshot
            .sorted { $0.date > $1.date || ($0.date == $1.date && $0.id.uuidString > $1.id.uuidString) }
            .map(\.color)
    }

    public var colorCount: Int { colors?.count ?? 0 }

    /// The persisted preview background, if the user picked one.
    public var previewBackground: PreviewBackground? {
        get { previewBackgroundRaw.flatMap(PreviewBackground.init(rawValue:)) }
        set { previewBackgroundRaw = newValue?.rawValue }
    }

    /// The RGBA values of the palette's colors in display order (for rendering/transfer).
    public var colorValues: [RGBA] { sortedColors.map(\.rgba) }
}

// MARK: - Export / serialization

extension OpalitePalette {
    /// Dictionary representation for the native `.opalitepalette` format.
    public var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "createdByDisplayName": createdByDisplayName as Any,
            "notes": notes as Any,
            "tags": tags,
            "isArchived": isArchived,
            "colors": (colors ?? []).map(\.dictionaryRepresentation),
        ]
        if let previewBackgroundRaw { dict["previewBackground"] = previewBackgroundRaw }
        if let canvasFile {
            dict["canvasFileId"] = canvasFile.id.uuidString
            dict["canvasFileTitle"] = canvasFile.title
        }
        return dict
    }

    public func jsonRepresentation() throws -> Data {
        try JSONSerialization.data(withJSONObject: dictionaryRepresentation, options: [.prettyPrinted, .sortedKeys])
    }

    /// Suggested filename for the native export.
    public var suggestedExportFilename: String {
        let sanitized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .lowercased()
        return sanitized.isEmpty ? "opalite-palette.json" : "\(sanitized).opalite-palette.json"
    }
}

// MARK: - Samples (previews)

extension OpalitePalette {
    public static var sample: OpalitePalette {
        let sunset = OpaliteColor(name: "Sunset Orange", red: 0.95, green: 0.45, blue: 0.30)
        return OpalitePalette(
            name: "Sample Palette",
            createdByDisplayName: "Nick Molargik",
            notes: "Example palette for SwiftUI previews.",
            tags: ["preview", "sample"],
            colors: [sunset, .sample, .sample2, .sample3, .sample4, .sample5]
        )
    }
}
