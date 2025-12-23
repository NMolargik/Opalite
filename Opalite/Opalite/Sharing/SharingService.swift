//
//  SharingService.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Import Preview Types
struct ColorImportPreview {
    let color: OpaliteColor
    let existingColor: OpaliteColor?
    var willSkip: Bool { existingColor != nil }
}

struct PaletteImportPreview {
    let palette: OpalitePalette
    let existingPalette: OpalitePalette?
    let newColors: [OpaliteColor]
    let existingColors: [OpaliteColor]
    var willUpdate: Bool { existingPalette != nil }
}

// MARK: - Sharing Errors

enum SharingError: LocalizedError {
    case invalidFormat
    case missingRequiredFields
    case fileAccessDenied
    case exportFailed(Error)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The file format is invalid or corrupted."
        case .missingRequiredFields:
            return "The file is missing required data."
        case .fileAccessDenied:
            return "Unable to access the file."
        case .exportFailed(let error):
            return "Failed to export: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to read file: \(error.localizedDescription)"
        }
    }
}

// MARK: - Sharing Service

@MainActor
enum SharingService {

    // MARK: - Export

    /// Exports a color to a shareable file URL in the temp directory
    static func exportColor(_ color: OpaliteColor) throws -> URL {
        do {
            let data = try color.jsonRepresentation()
            let baseName: String
            if let name = color.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                baseName = sanitizeFilename(name)
            } else {
                baseName = filenameFromHex(color.hexString)
            }
            let filename = baseName + ".opalitecolor"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            return tempURL
        } catch {
            throw SharingError.exportFailed(error)
        }
    }

    /// Exports a palette to a shareable file URL in the temp directory
    static func exportPalette(_ palette: OpalitePalette) throws -> URL {
        do {
            let data = try palette.jsonRepresentation()
            let filename = sanitizeFilename(palette.name) + ".opalitepalette"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            return tempURL
        } catch {
            throw SharingError.exportFailed(error)
        }
    }

    // MARK: - Import Preview

    /// Decodes color data from a URL and checks for existing duplicates by UUID
    static func previewColorImport(from url: URL, existingColors: [OpaliteColor]) throws -> ColorImportPreview {
        do {
            let data = try Data(contentsOf: url)
            let color = try decodeColor(from: data)
            let existing = existingColors.first { $0.id == color.id }
            return ColorImportPreview(
                color: color,
                existingColor: existing
            )
        } catch let error as SharingError {
            throw error
        } catch {
            throw SharingError.decodingFailed(error)
        }
    }

    /// Decodes palette data from a URL and checks for existing duplicates by UUID
    static func previewPaletteImport(
        from url: URL,
        existingPalettes: [OpalitePalette],
        existingColors: [OpaliteColor]
    ) throws -> PaletteImportPreview {
        do {
            let data = try Data(contentsOf: url)
            let palette = try decodePalette(from: data)

            let existingPalette = existingPalettes.first { $0.id == palette.id }

            var newColors: [OpaliteColor] = []
            var foundExisting: [OpaliteColor] = []

            for color in palette.colors ?? [] {
                if let existing = existingColors.first(where: { $0.id == color.id }) {
                    foundExisting.append(existing)
                } else {
                    newColors.append(color)
                }
            }

            return PaletteImportPreview(
                palette: palette,
                existingPalette: existingPalette,
                newColors: newColors,
                existingColors: foundExisting
            )
        } catch let error as SharingError {
            throw error
        } catch {
            throw SharingError.decodingFailed(error)
        }
    }

    // MARK: - Decoding

    private static func decodeColor(from data: Data) throws -> OpaliteColor {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SharingError.invalidFormat
        }

        guard let idString = json["id"] as? String,
              let id = UUID(uuidString: idString),
              let red = json["red"] as? Double,
              let green = json["green"] as? Double,
              let blue = json["blue"] as? Double else {
            throw SharingError.missingRequiredFields
        }

        let alpha = json["alpha"] as? Double ?? 1.0
        let name = json["name"] as? String
        let notes = json["notes"] as? String
        let createdByDisplayName = json["createdByDisplayName"] as? String
        let createdOnDeviceName = json["createdOnDeviceName"] as? String
        let updatedOnDeviceName = json["updatedOnDeviceName"] as? String

        let createdAt: Date
        if let timestamp = json["createdAt"] as? Double {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = .now
        }

        let updatedAt: Date
        if let timestamp = json["updatedAt"] as? Double {
            updatedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            updatedAt = .now
        }

        return OpaliteColor(
            id: id,
            name: name,
            notes: notes,
            createdByDisplayName: createdByDisplayName,
            createdOnDeviceName: createdOnDeviceName,
            updatedOnDeviceName: updatedOnDeviceName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha
        )
    }

    private static func decodePalette(from data: Data) throws -> OpalitePalette {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SharingError.invalidFormat
        }

        guard let idString = json["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = json["name"] as? String else {
            throw SharingError.missingRequiredFields
        }

        let notes = json["notes"] as? String
        let tags = json["tags"] as? [String] ?? []
        let createdByDisplayName = json["createdByDisplayName"] as? String

        let createdAt: Date
        if let timestamp = json["createdAt"] as? Double {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else {
            createdAt = .now
        }

        let updatedAt: Date
        if let timestamp = json["updatedAt"] as? Double {
            updatedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            updatedAt = .now
        }

        // Decode embedded colors
        var colors: [OpaliteColor] = []
        if let colorDicts = json["colors"] as? [[String: Any]] {
            for colorDict in colorDicts {
                let colorData = try JSONSerialization.data(withJSONObject: colorDict)
                let color = try decodeColor(from: colorData)
                colors.append(color)
            }
        }

        let palette = OpalitePalette(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdByDisplayName: createdByDisplayName,
            notes: notes,
            tags: tags,
            colors: colors
        )

        // Set back-references
        colors.forEach { $0.palette = palette }

        return palette
    }

    // MARK: - Helpers

    private static func sanitizeFilename(_ name: String) -> String {
        // Capitalize first letter of each word and remove whitespace
        let words = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        let capitalized = words.map { word -> String in
            guard let first = word.first else { return word }
            return first.uppercased() + word.dropFirst()
        }.joined()

        // Remove any non-alphanumeric characters except underscore and hyphen
        let sanitized = capitalized.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "",
            options: .regularExpression
        )

        return sanitized.isEmpty ? "Untitled" : sanitized
    }

    /// Creates a clean filename from a hex code (e.g., "#FF5733" -> "FF5733")
    private static func filenameFromHex(_ hex: String) -> String {
        hex.replacingOccurrences(of: "#", with: "")
    }
}
