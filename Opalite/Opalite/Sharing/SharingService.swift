//
//  SharingService.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Compression

// MARK: - Color Export Formats

enum ColorExportFormat: String, CaseIterable, Identifiable {
    case opalite = "opalite"
    case ase = "ase"
    case procreate = "procreate"
    case gpl = "gpl"
    case css = "css"
    case swiftui = "swiftui"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opalite: return "Opalite Color"
        case .ase: return "Adobe Swatch Exchange"
        case .procreate: return "Procreate Swatch"
        case .gpl: return "GIMP Palette"
        case .css: return "CSS Code"
        case .swiftui: return "SwiftUI Code"
        }
    }

    var fileExtension: String {
        switch self {
        case .opalite: return "opalitecolor"
        case .ase: return "ase"
        case .procreate: return "swatches"
        case .gpl: return "gpl"
        case .css: return "css"
        case .swiftui: return "swift"
        }
    }

    var icon: String {
        switch self {
        case .opalite: return "paintpalette.fill"
        case .ase: return "a.square.fill"
        case .procreate: return "paintbrush.fill"
        case .gpl: return "square.grid.3x3.fill"
        case .css: return "chevron.left.forwardslash.chevron.right"
        case .swiftui: return "swift"
        }
    }

    var description: String {
        switch self {
        case .opalite:
            return "Native Opalite format. Import back into Opalite on any device."
        case .ase:
            return "Works with Adobe Photoshop, Illustrator, InDesign, and other Adobe apps."
        case .procreate:
            return "Import directly into Procreate on iPad for digital painting."
        case .gpl:
            return "Works with GIMP, Inkscape, Krita, and other open-source tools."
        case .css:
            return "CSS custom property ready to paste into your stylesheets."
        case .swiftui:
            return "SwiftUI Color extension ready for your Xcode project."
        }
    }
}

// MARK: - Palette Export Formats

enum PaletteExportFormat: String, CaseIterable, Identifiable {
    case opalite = "opalite"
    case ase = "ase"
    case procreate = "procreate"
    case gpl = "gpl"
    case css = "css"
    case swiftui = "swiftui"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .opalite: return "Opalite Palette"
        case .ase: return "Adobe Swatch Exchange"
        case .procreate: return "Procreate Swatches"
        case .gpl: return "GIMP Palette"
        case .css: return "CSS Code"
        case .swiftui: return "SwiftUI Code"
        }
    }

    var fileExtension: String {
        switch self {
        case .opalite: return "opalitepalette"
        case .ase: return "ase"
        case .procreate: return "swatches"
        case .gpl: return "gpl"
        case .css: return "css"
        case .swiftui: return "swift"
        }
    }

    var icon: String {
        switch self {
        case .opalite: return "swatchpalette.fill"
        case .ase: return "a.square.fill"
        case .procreate: return "paintbrush.fill"
        case .gpl: return "square.grid.3x3.fill"
        case .css: return "chevron.left.forwardslash.chevron.right"
        case .swiftui: return "swift"
        }
    }

    var description: String {
        switch self {
        case .opalite:
            return "Native Opalite format. Import back into Opalite on any device."
        case .ase:
            return "Works with Adobe Photoshop, Illustrator, InDesign, and other Adobe apps."
        case .procreate:
            return "Import directly into Procreate on iPad for digital painting."
        case .gpl:
            return "Works with GIMP, Inkscape, Krita, and other open-source tools."
        case .css:
            return "CSS custom properties ready to paste into your stylesheets."
        case .swiftui:
            return "SwiftUI Color extension ready for your Xcode project."
        }
    }
}

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

    /// Exports a color to a shareable file URL in the temp directory (legacy method)
    static func exportColor(_ color: OpaliteColor) throws -> URL {
        return try exportColor(color, format: .opalite)
    }

    /// Exports a color in the specified format to a shareable file URL
    static func exportColor(_ color: OpaliteColor, format: ColorExportFormat) throws -> URL {
        let baseName: String
        if let name = color.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            baseName = sanitizeFilename(name)
        } else {
            baseName = filenameFromHex(color.hexString)
        }

        let filename = baseName + "." + format.fileExtension
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            let data: Data
            switch format {
            case .opalite:
                data = try color.jsonRepresentation()
            case .ase:
                data = try generateASE(for: color)
            case .procreate:
                data = try generateProcreateSwatches(for: color)
            case .gpl:
                data = try generateGPL(for: color)
            case .css:
                data = try generateCSS(for: color)
            case .swiftui:
                data = try generateSwiftUI(for: color)
            }
            try data.write(to: tempURL)
            return tempURL
        } catch {
            throw SharingError.exportFailed(error)
        }
    }

    // MARK: - Format Generators

    /// Generates Adobe Swatch Exchange (ASE) format
    private static func generateASE(for color: OpaliteColor) throws -> Data {
        var data = Data()

        // ASE Header: "ASEF" signature
        data.append(contentsOf: [0x41, 0x53, 0x45, 0x46]) // "ASEF"

        // Version: 1.0
        data.append(contentsOf: [0x00, 0x01, 0x00, 0x00])

        // Number of blocks: 1 color
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])

        // Color entry block
        // Block type: 0x0001 (color entry)
        data.append(contentsOf: [0x00, 0x01])

        // Build color block content
        var colorBlock = Data()

        // Name length (including null terminator, in UTF-16 chars)
        let colorName = color.name ?? color.hexString
        let utf16Name = Array(colorName.utf16)
        let nameLength = UInt16(utf16Name.count + 1)
        colorBlock.append(contentsOf: withUnsafeBytes(of: nameLength.bigEndian) { Array($0) })

        // Name in UTF-16BE
        for char in utf16Name {
            colorBlock.append(contentsOf: withUnsafeBytes(of: char.bigEndian) { Array($0) })
        }
        // Null terminator
        colorBlock.append(contentsOf: [0x00, 0x00])

        // Color model: "RGB " (4 chars)
        colorBlock.append(contentsOf: [0x52, 0x47, 0x42, 0x20]) // "RGB "

        // RGB values as 32-bit floats (big-endian)
        let r = Float32(color.red)
        let g = Float32(color.green)
        let b = Float32(color.blue)

        colorBlock.append(contentsOf: withUnsafeBytes(of: r.bitPattern.bigEndian) { Array($0) })
        colorBlock.append(contentsOf: withUnsafeBytes(of: g.bitPattern.bigEndian) { Array($0) })
        colorBlock.append(contentsOf: withUnsafeBytes(of: b.bitPattern.bigEndian) { Array($0) })

        // Color type: 0 = Global
        colorBlock.append(contentsOf: [0x00, 0x00])

        // Block length
        let blockLength = UInt32(colorBlock.count)
        data.append(contentsOf: withUnsafeBytes(of: blockLength.bigEndian) { Array($0) })

        // Append color block
        data.append(colorBlock)

        return data
    }

    /// Generates Procreate .swatches format (ZIP containing JSON)
    private static func generateProcreateSwatches(for color: OpaliteColor) throws -> Data {
        // Procreate swatches are a ZIP file containing Swatches.json
        let swatchName = color.name ?? color.hexString

        // HSV conversion for Procreate format
        let (h, s, v) = rgbToHSV(r: color.red, g: color.green, b: color.blue)

        let swatchesJSON: [String: Any] = [
            "name": swatchName,
            "swatches": [
                [
                    "hue": h,
                    "saturation": s,
                    "brightness": v,
                    "alpha": color.alpha,
                    "colorSpace": 0
                ]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: swatchesJSON, options: .prettyPrinted)

        // Create a simple ZIP archive
        return try createZipArchive(filename: "Swatches.json", content: jsonData)
    }

    /// Generates GIMP Palette (GPL) format
    private static func generateGPL(for color: OpaliteColor) throws -> Data {
        let colorName = color.name ?? color.hexString
        let r = Int(round(color.red * 255))
        let g = Int(round(color.green * 255))
        let b = Int(round(color.blue * 255))

        let gpl = """
        GIMP Palette
        Name: \(colorName)
        Columns: 1
        #
        \(String(format: "%3d %3d %3d", r, g, b))\t\(colorName)
        """

        guard let data = gpl.data(using: .utf8) else {
            throw SharingError.exportFailed(NSError(domain: "SharingService", code: -1))
        }
        return data
    }

    /// Generates CSS custom property
    private static func generateCSS(for color: OpaliteColor) throws -> Data {
        let colorName = color.name ?? "color"
        let cssName = colorName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

        let r = Int(round(color.red * 255))
        let g = Int(round(color.green * 255))
        let b = Int(round(color.blue * 255))

        let css: String
        if color.alpha < 1.0 {
            css = """
            /* \(colorName) - Exported from Opalite */
            :root {
              --\(cssName): rgba(\(r), \(g), \(b), \(String(format: "%.2f", color.alpha)));
              --\(cssName)-hex: \(color.hexString);
            }
            """
        } else {
            css = """
            /* \(colorName) - Exported from Opalite */
            :root {
              --\(cssName): rgb(\(r), \(g), \(b));
              --\(cssName)-hex: \(color.hexString);
            }
            """
        }

        guard let data = css.data(using: .utf8) else {
            throw SharingError.exportFailed(NSError(domain: "SharingService", code: -1))
        }
        return data
    }

    /// Generates SwiftUI Color extension
    private static func generateSwiftUI(for color: OpaliteColor) throws -> Data {
        let colorName = color.name ?? "customColor"
        let swiftName = colorName
            .components(separatedBy: .whitespaces)
            .enumerated()
            .map { index, word in
                if index == 0 {
                    return word.lowercased()
                }
                return word.capitalized
            }
            .joined()
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)

        let swift = """
        // \(colorName) - Exported from Opalite
        import SwiftUI

        extension Color {
            static let \(swiftName) = Color(
                red: \(String(format: "%.3f", color.red)),
                green: \(String(format: "%.3f", color.green)),
                blue: \(String(format: "%.3f", color.blue)),
                opacity: \(String(format: "%.2f", color.alpha))
            )
        }

        // Usage: Color.\(swiftName)
        // Hex: \(color.hexString)
        """

        guard let data = swift.data(using: .utf8) else {
            throw SharingError.exportFailed(NSError(domain: "SharingService", code: -1))
        }
        return data
    }

    // MARK: - Color Space Helpers

    private static func rgbToHSV(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal

        var h: Double = 0
        let s: Double = maxVal == 0 ? 0 : delta / maxVal
        let v: Double = maxVal

        if delta != 0 {
            if maxVal == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxVal == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
        }

        return (h, s, v)
    }

    // MARK: - ZIP Archive Helper

    private static func createZipArchive(filename: String, content: Data) throws -> Data {
        // Simple ZIP file structure (uncompressed for simplicity)
        var zip = Data()

        let filenameData = filename.data(using: .utf8) ?? Data()
        let filenameLength = UInt16(filenameData.count)
        let contentLength = UInt32(content.count)

        // Calculate CRC32
        let crc = crc32(content)

        // Current date/time for DOS format
        let dosTime = dosDateTime()

        // Local file header
        zip.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Signature
        zip.append(contentsOf: [0x14, 0x00]) // Version needed (2.0)
        zip.append(contentsOf: [0x00, 0x00]) // General purpose bit flag
        zip.append(contentsOf: [0x00, 0x00]) // Compression method (none)
        zip.append(contentsOf: withUnsafeBytes(of: dosTime.time.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: dosTime.date.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: contentLength.littleEndian) { Array($0) }) // Compressed size
        zip.append(contentsOf: withUnsafeBytes(of: contentLength.littleEndian) { Array($0) }) // Uncompressed size
        zip.append(contentsOf: withUnsafeBytes(of: filenameLength.littleEndian) { Array($0) })
        zip.append(contentsOf: [0x00, 0x00]) // Extra field length
        zip.append(filenameData)
        zip.append(content)

        let localHeaderSize = UInt32(30 + filenameData.count + content.count)

        // Central directory header
        let cdStart = UInt32(zip.count)
        zip.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Signature
        zip.append(contentsOf: [0x14, 0x00]) // Version made by
        zip.append(contentsOf: [0x14, 0x00]) // Version needed
        zip.append(contentsOf: [0x00, 0x00]) // General purpose bit flag
        zip.append(contentsOf: [0x00, 0x00]) // Compression method
        zip.append(contentsOf: withUnsafeBytes(of: dosTime.time.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: dosTime.date.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: contentLength.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: contentLength.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: filenameLength.littleEndian) { Array($0) })
        zip.append(contentsOf: [0x00, 0x00]) // Extra field length
        zip.append(contentsOf: [0x00, 0x00]) // Comment length
        zip.append(contentsOf: [0x00, 0x00]) // Disk number start
        zip.append(contentsOf: [0x00, 0x00]) // Internal attributes
        zip.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // External attributes
        zip.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Offset of local header
        zip.append(filenameData)

        let cdSize = UInt32(zip.count) - cdStart

        // End of central directory
        zip.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // Signature
        zip.append(contentsOf: [0x00, 0x00]) // Disk number
        zip.append(contentsOf: [0x00, 0x00]) // Disk with CD
        zip.append(contentsOf: [0x01, 0x00]) // Entries on disk
        zip.append(contentsOf: [0x01, 0x00]) // Total entries
        zip.append(contentsOf: withUnsafeBytes(of: cdSize.littleEndian) { Array($0) })
        zip.append(contentsOf: withUnsafeBytes(of: cdStart.littleEndian) { Array($0) })
        zip.append(contentsOf: [0x00, 0x00]) // Comment length

        return zip
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let polynomial: UInt32 = 0xEDB88320

        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ polynomial
                } else {
                    crc >>= 1
                }
            }
        }

        return ~crc
    }

    private static func dosDateTime() -> (date: UInt16, time: UInt16) {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)

        let year = max(0, (components.year ?? 1980) - 1980)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2

        let date = UInt16((year << 9) | (month << 5) | day)
        let time = UInt16((hour << 11) | (minute << 5) | second)

        return (date, time)
    }

    /// Exports a palette to a shareable file URL in the temp directory (legacy method)
    static func exportPalette(_ palette: OpalitePalette) throws -> URL {
        return try exportPalette(palette, format: .opalite)
    }

    /// Exports a palette in the specified format to a shareable file URL
    static func exportPalette(_ palette: OpalitePalette, format: PaletteExportFormat) throws -> URL {
        let baseName = sanitizeFilename(palette.name)
        let filename = baseName + "." + format.fileExtension
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            let data: Data
            switch format {
            case .opalite:
                data = try palette.jsonRepresentation()
            case .ase:
                data = try generatePaletteASE(for: palette)
            case .procreate:
                data = try generatePaletteProcreateSwatches(for: palette)
            case .gpl:
                data = try generatePaletteGPL(for: palette)
            case .css:
                data = try generatePaletteCSS(for: palette)
            case .swiftui:
                data = try generatePaletteSwiftUI(for: palette)
            }
            try data.write(to: tempURL)
            return tempURL
        } catch {
            throw SharingError.exportFailed(error)
        }
    }

    // MARK: - Palette Format Generators

    /// Generates Adobe Swatch Exchange (ASE) format for a palette
    private static func generatePaletteASE(for palette: OpalitePalette) throws -> Data {
        let colors = palette.colors ?? []
        var data = Data()

        // ASE Header: "ASEF" signature
        data.append(contentsOf: [0x41, 0x53, 0x45, 0x46]) // "ASEF"

        // Version: 1.0
        data.append(contentsOf: [0x00, 0x01, 0x00, 0x00])

        // Number of blocks: group start + colors + group end
        let blockCount = UInt32(colors.count + 2)
        data.append(contentsOf: withUnsafeBytes(of: blockCount.bigEndian) { Array($0) })

        // Group start block
        data.append(contentsOf: [0xC0, 0x01]) // Block type: group start
        var groupBlock = Data()
        let groupName = palette.name
        let utf16GroupName = Array(groupName.utf16)
        let groupNameLength = UInt16(utf16GroupName.count + 1)
        groupBlock.append(contentsOf: withUnsafeBytes(of: groupNameLength.bigEndian) { Array($0) })
        for char in utf16GroupName {
            groupBlock.append(contentsOf: withUnsafeBytes(of: char.bigEndian) { Array($0) })
        }
        groupBlock.append(contentsOf: [0x00, 0x00]) // Null terminator
        let groupBlockLength = UInt32(groupBlock.count)
        data.append(contentsOf: withUnsafeBytes(of: groupBlockLength.bigEndian) { Array($0) })
        data.append(groupBlock)

        // Color entry blocks
        for color in colors {
            data.append(contentsOf: [0x00, 0x01]) // Block type: color entry

            var colorBlock = Data()
            let colorName = color.name ?? color.hexString
            let utf16Name = Array(colorName.utf16)
            let nameLength = UInt16(utf16Name.count + 1)
            colorBlock.append(contentsOf: withUnsafeBytes(of: nameLength.bigEndian) { Array($0) })
            for char in utf16Name {
                colorBlock.append(contentsOf: withUnsafeBytes(of: char.bigEndian) { Array($0) })
            }
            colorBlock.append(contentsOf: [0x00, 0x00]) // Null terminator

            // Color model: "RGB "
            colorBlock.append(contentsOf: [0x52, 0x47, 0x42, 0x20])

            // RGB values as 32-bit floats
            let r = Float32(color.red)
            let g = Float32(color.green)
            let b = Float32(color.blue)
            colorBlock.append(contentsOf: withUnsafeBytes(of: r.bitPattern.bigEndian) { Array($0) })
            colorBlock.append(contentsOf: withUnsafeBytes(of: g.bitPattern.bigEndian) { Array($0) })
            colorBlock.append(contentsOf: withUnsafeBytes(of: b.bitPattern.bigEndian) { Array($0) })

            // Color type: 0 = Global
            colorBlock.append(contentsOf: [0x00, 0x00])

            let colorBlockLength = UInt32(colorBlock.count)
            data.append(contentsOf: withUnsafeBytes(of: colorBlockLength.bigEndian) { Array($0) })
            data.append(colorBlock)
        }

        // Group end block
        data.append(contentsOf: [0xC0, 0x02]) // Block type: group end
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Zero length

        return data
    }

    /// Generates Procreate .swatches format for a palette
    private static func generatePaletteProcreateSwatches(for palette: OpalitePalette) throws -> Data {
        let colors = palette.colors ?? []

        var swatchesArray: [[String: Any]] = []
        for color in colors {
            let (h, s, v) = rgbToHSV(r: color.red, g: color.green, b: color.blue)
            swatchesArray.append([
                "hue": h,
                "saturation": s,
                "brightness": v,
                "alpha": color.alpha,
                "colorSpace": 0
            ])
        }

        let swatchesJSON: [String: Any] = [
            "name": palette.name,
            "swatches": swatchesArray
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: swatchesJSON, options: .prettyPrinted)
        return try createZipArchive(filename: "Swatches.json", content: jsonData)
    }

    /// Generates GIMP Palette (GPL) format for a palette
    private static func generatePaletteGPL(for palette: OpalitePalette) throws -> Data {
        let colors = palette.colors ?? []

        var lines: [String] = [
            "GIMP Palette",
            "Name: \(palette.name)",
            "Columns: \(min(colors.count, 16))",
            "#"
        ]

        for color in colors {
            let r = Int(round(color.red * 255))
            let g = Int(round(color.green * 255))
            let b = Int(round(color.blue * 255))
            let name = color.name ?? color.hexString
            lines.append(String(format: "%3d %3d %3d\t%@", r, g, b, name))
        }

        let gpl = lines.joined(separator: "\n")
        guard let data = gpl.data(using: .utf8) else {
            throw SharingError.exportFailed(NSError(domain: "SharingService", code: -1))
        }
        return data
    }

    /// Generates CSS custom properties for a palette
    private static func generatePaletteCSS(for palette: OpalitePalette) throws -> Data {
        let colors = palette.colors ?? []
        let paletteName = palette.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

        var lines: [String] = [
            "/* \(palette.name) - Exported from Opalite */",
            ":root {"
        ]

        for color in colors {
            let colorName = (color.name ?? color.hexString)
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)

            let r = Int(round(color.red * 255))
            let g = Int(round(color.green * 255))
            let b = Int(round(color.blue * 255))

            let varName = "--\(paletteName)-\(colorName)"
            if color.alpha < 1.0 {
                lines.append("  \(varName): rgba(\(r), \(g), \(b), \(String(format: "%.2f", color.alpha)));")
            } else {
                lines.append("  \(varName): rgb(\(r), \(g), \(b));")
            }
            lines.append("  \(varName)-hex: \(color.hexString);")
        }

        lines.append("}")

        let css = lines.joined(separator: "\n")
        guard let data = css.data(using: .utf8) else {
            throw SharingError.exportFailed(NSError(domain: "SharingService", code: -1))
        }
        return data
    }

    /// Generates SwiftUI Color extension for a palette
    private static func generatePaletteSwiftUI(for palette: OpalitePalette) throws -> Data {
        let colors = palette.colors ?? []

        let structName = palette.name
            .components(separatedBy: .whitespaces)
            .map { $0.capitalized }
            .joined()
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)

        var lines: [String] = [
            "// \(palette.name) - Exported from Opalite",
            "import SwiftUI",
            "",
            "extension Color {"
        ]

        for color in colors {
            let colorName = (color.name ?? color.hexString)
                .components(separatedBy: .whitespaces)
                .enumerated()
                .map { index, word in
                    if index == 0 {
                        return word.lowercased()
                    }
                    return word.capitalized
                }
                .joined()
                .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)

            let propertyName = "\(structName.prefix(1).lowercased() + structName.dropFirst())\(colorName.prefix(1).uppercased() + colorName.dropFirst())"

            lines.append("    static let \(propertyName) = Color(")
            lines.append("        red: \(String(format: "%.3f", color.red)),")
            lines.append("        green: \(String(format: "%.3f", color.green)),")
            lines.append("        blue: \(String(format: "%.3f", color.blue)),")
            lines.append("        opacity: \(String(format: "%.2f", color.alpha))")
            lines.append("    )")
            lines.append("")
        }

        lines.append("}")

        let swift = lines.joined(separator: "\n")
        guard let data = swift.data(using: .utf8) else {
            throw SharingError.exportFailed(NSError(domain: "SharingService", code: -1))
        }
        return data
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
