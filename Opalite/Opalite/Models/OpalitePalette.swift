//
//  OpalitePalette.swift
//  Opalite
//
//  Created by Nick Molargik on 12/6/25.
//

import SwiftUI
import SwiftData

@Model
final class OpalitePalette {
    var id: UUID = UUID()
    
    // Core fields
    var name: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var createdByDisplayName: String?
    
    // User-facing metadata
    var notes: String?
    var tags: [String] = []

    // Preview background color (stored as raw value)
    var previewBackgroundRaw: String?

    // Relationship
    @Relationship var colors: [OpaliteColor]? = []

    /// Colors sorted by creation date (newest first)
    var sortedColors: [OpaliteColor] {
        (colors ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    #if !os(watchOS)
    /// Preview background color (computed from stored raw value)
    var previewBackground: PreviewBackground? {
        get {
            guard let raw = previewBackgroundRaw else { return nil }
            return PreviewBackground(rawValue: raw)
        }
        set {
            previewBackgroundRaw = newValue?.rawValue
        }
    }
    #endif
    
    // Init
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        createdByDisplayName: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        colors: [OpaliteColor] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdByDisplayName = createdByDisplayName
        self.notes = notes
        self.tags = tags
        self.colors = colors
    }
}

// MARK: - Export / Serialization

extension OpalitePalette {
    /// Dictionary representation for flexible exporting / sharing
    var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "name": name,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "createdByDisplayName": createdByDisplayName as Any,
            "notes": notes as Any,
            "tags": tags,
            "colors": (colors ?? []).map { $0.dictionaryRepresentation }
        ]
        if let previewBackgroundRaw {
            dict["previewBackground"] = previewBackgroundRaw
        }
        return dict
    }

    /// JSON representation of the entire palette, including all colors
    func jsonRepresentation() throws -> Data {
        try JSONSerialization.data(withJSONObject: dictionaryRepresentation, options: .prettyPrinted)
    }

    /// Suggested filename when exporting this palette as a file
    var suggestedExportFilename: String {
        let sanitizedName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .lowercased()
        
        return sanitizedName.isEmpty ? "opalite-palette.json" : "\(sanitizedName).opalite-palette.json"
    }
}

extension OpalitePalette {
    /// Sample palette for SwiftUI previews
    static var sample: OpalitePalette {
        let color = OpaliteColor(
            name: "Sunset Orange",
            red: 0.95,
            green: 0.45,
            blue: 0.30,
            alpha: 1.0
        )

        let palette = OpalitePalette(
            name: "Sample Palette",
            createdAt: Date(),
            updatedAt: Date(),
            createdByDisplayName: "Nick Molargik",
            notes: "Example palette for SwiftUI previews.",
            tags: ["preview", "sample"],
            colors: [color, OpaliteColor.sample, OpaliteColor.sample2]
        )

        return palette
    }
}
