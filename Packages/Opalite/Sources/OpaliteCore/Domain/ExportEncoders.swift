//
//  ExportEncoders.swift
//  OpaliteCore
//
//  Pure byte generators for the interchange formats: Adobe ASE, Procreate .swatches (a
//  stored ZIP of Swatches.json), GIMP .gpl, CSS custom properties, and a SwiftUI
//  extension. Everything works over `ExportSwatch` values so the encoders are host-tested
//  and shared by colors and palettes.
//

import Foundation

/// One named color going into an export.
nonisolated public struct ExportSwatch: Hashable, Sendable {
    public let name: String?
    public let rgba: RGBA

    public init(name: String?, rgba: RGBA) {
        self.name = name
        self.rgba = rgba
    }

    /// The name, or the hex when unnamed.
    public var resolvedName: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return rgba.hexString
    }
}

nonisolated public enum ExportEncoders {

    // MARK: - Adobe Swatch Exchange

    /// A single-color ASE document.
    public static func ase(_ swatch: ExportSwatch) -> Data {
        var data = aseHeader(blockCount: 1)
        appendColorBlock(swatch, to: &data)
        return data
    }

    /// A grouped ASE document (group start, colors, group end).
    public static func ase(groupName: String, swatches: [ExportSwatch]) -> Data {
        var data = aseHeader(blockCount: UInt32(swatches.count + 2))

        data.append(contentsOf: [0xC0, 0x01]) // group start
        var group = Data()
        appendUTF16String(groupName, to: &group)
        data.append(bigEndian: UInt32(group.count))
        data.append(group)

        for swatch in swatches { appendColorBlock(swatch, to: &data) }

        data.append(contentsOf: [0xC0, 0x02]) // group end
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        return data
    }

    private static func aseHeader(blockCount: UInt32) -> Data {
        var data = Data()
        data.append(contentsOf: [0x41, 0x53, 0x45, 0x46]) // "ASEF"
        data.append(contentsOf: [0x00, 0x01, 0x00, 0x00]) // version 1.0
        data.append(bigEndian: blockCount)
        return data
    }

    private static func appendColorBlock(_ swatch: ExportSwatch, to data: inout Data) {
        data.append(contentsOf: [0x00, 0x01]) // color entry
        var block = Data()
        appendUTF16String(swatch.resolvedName, to: &block)
        block.append(contentsOf: [0x52, 0x47, 0x42, 0x20]) // "RGB "
        block.append(bigEndian: Float32(swatch.rgba.red).bitPattern)
        block.append(bigEndian: Float32(swatch.rgba.green).bitPattern)
        block.append(bigEndian: Float32(swatch.rgba.blue).bitPattern)
        block.append(contentsOf: [0x00, 0x00]) // global
        data.append(bigEndian: UInt32(block.count))
        data.append(block)
    }

    private static func appendUTF16String(_ string: String, to data: inout Data) {
        let units = Array(string.utf16)
        data.append(bigEndian: UInt16(units.count + 1))
        for unit in units { data.append(bigEndian: unit) }
        data.append(contentsOf: [0x00, 0x00])
    }

    // MARK: - Procreate

    /// A Procreate `.swatches` archive (ZIP containing Swatches.json).
    public static func procreateSwatches(name: String, swatches: [ExportSwatch]) throws -> Data {
        let entries: [[String: Any]] = swatches.map { swatch in
            let hsv = swatch.rgba.hsv
            return [
                "hue": hsv.hue / 360,
                "saturation": hsv.saturation,
                "brightness": hsv.value,
                "alpha": swatch.rgba.alpha,
                "colorSpace": 0,
            ]
        }
        let json: [String: Any] = ["name": name, "swatches": entries]
        let jsonData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        return ZipArchive.stored(filename: "Swatches.json", content: jsonData)
    }

    // MARK: - GIMP

    public static func gpl(name: String, swatches: [ExportSwatch]) -> Data {
        var lines = [
            "GIMP Palette",
            "Name: \(name)",
            "Columns: \(max(1, min(swatches.count, 16)))",
            "#",
        ]
        for swatch in swatches {
            lines.append(String(format: "%3d %3d %3d\t%@", swatch.rgba.red.byte, swatch.rgba.green.byte, swatch.rgba.blue.byte, swatch.resolvedName))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    // MARK: - CSS

    public static func css(title: String, prefix: String?, swatches: [ExportSwatch]) -> Data {
        var lines = ["/* \(title) - Exported from Opalite */", ":root {"]
        let prefixSlug = prefix.map(cssSlug)
        for swatch in swatches {
            var slug = cssSlug(swatch.resolvedName)
            if let prefixSlug, !prefixSlug.isEmpty { slug = "\(prefixSlug)-\(slug)" }
            let c = swatch.rgba
            if c.alpha < 1 {
                lines.append("  --\(slug): rgba(\(c.red.byte), \(c.green.byte), \(c.blue.byte), \(String(format: "%.2f", c.alpha)));")
            } else {
                lines.append("  --\(slug): rgb(\(c.red.byte), \(c.green.byte), \(c.blue.byte));")
            }
            lines.append("  --\(slug)-hex: \(c.hexString);")
        }
        lines.append("}")
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// "Dusty Rose" → "dusty-rose".
    public static func cssSlug(_ name: String) -> String {
        let slug = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        return slug.isEmpty ? "color" : slug
    }

    // MARK: - SwiftUI

    public static func swiftUI(title: String, prefix: String?, swatches: [ExportSwatch]) -> Data {
        var lines = ["// \(title) - Exported from Opalite", "import SwiftUI", "", "extension Color {"]
        let typePrefix = prefix.map(upperCamel) ?? ""
        for swatch in swatches {
            var property = lowerCamel(swatch.resolvedName)
            if !typePrefix.isEmpty {
                property = lowerCamel(typePrefix) + property.prefix(1).uppercased() + property.dropFirst()
            }
            let c = swatch.rgba
            lines.append("    static let \(property) = Color(")
            lines.append("        red: \(String(format: "%.3f", c.red)),")
            lines.append("        green: \(String(format: "%.3f", c.green)),")
            lines.append("        blue: \(String(format: "%.3f", c.blue)),")
            lines.append("        opacity: \(String(format: "%.2f", c.alpha))")
            lines.append("    )")
            lines.append("")
        }
        if lines.last == "" { lines.removeLast() }
        lines.append("}")
        if swatches.count == 1, let only = swatches.first {
            lines.append("")
            lines.append("// Usage: Color.\(lowerCamel(only.resolvedName))")
            lines.append("// Hex: \(only.rgba.hexString)")
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// "Dusty Rose" → "dustyRose"; hex "#FF5733" → "ff5733".
    public static func lowerCamel(_ name: String) -> String {
        let words = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let joined = words.enumerated().map { index, word in index == 0 ? word.lowercased() : word.capitalized }.joined()
        let cleaned = joined.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        if cleaned.isEmpty { return "customColor" }
        return cleaned.first!.isNumber ? "color\(cleaned)" : cleaned
    }

    public static func upperCamel(_ name: String) -> String {
        let words = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return words.map { $0.capitalized }.joined().replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
    }

    // MARK: - Filenames

    /// "my sunset palette!" → "MySunsetPalette"; empty → "Untitled".
    public static func sanitizedFilename(_ name: String) -> String {
        let words = name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let capitalized = words.map { word -> String in
            guard let first = word.first else { return word }
            return first.uppercased() + word.dropFirst()
        }.joined()
        let sanitized = capitalized.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "", options: .regularExpression)
        return sanitized.isEmpty ? "Untitled" : sanitized
    }

    /// "#FF5733" → "FF5733".
    public static func filename(fromHex hex: String) -> String {
        hex.replacingOccurrences(of: "#", with: "")
    }
}

// MARK: - ZIP (stored, single entry)

nonisolated public enum ZipArchive {
    /// A minimal ZIP containing one uncompressed entry.
    public static func stored(filename: String, content: Data, date: Date = Date()) -> Data {
        var zip = Data()
        let filenameData = Data(filename.utf8)
        let crc = crc32(content)
        let dos = dosDateTime(date)

        // Local file header
        zip.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
        zip.append(contentsOf: [0x14, 0x00]) // version needed
        zip.append(contentsOf: [0x00, 0x00]) // flags
        zip.append(contentsOf: [0x00, 0x00]) // stored
        zip.append(littleEndian: dos.time)
        zip.append(littleEndian: dos.date)
        zip.append(littleEndian: crc)
        zip.append(littleEndian: UInt32(content.count))
        zip.append(littleEndian: UInt32(content.count))
        zip.append(littleEndian: UInt16(filenameData.count))
        zip.append(contentsOf: [0x00, 0x00]) // extra length
        zip.append(filenameData)
        zip.append(content)

        // Central directory
        let cdStart = UInt32(zip.count)
        zip.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
        zip.append(contentsOf: [0x14, 0x00]) // version made by
        zip.append(contentsOf: [0x14, 0x00]) // version needed
        zip.append(contentsOf: [0x00, 0x00])
        zip.append(contentsOf: [0x00, 0x00])
        zip.append(littleEndian: dos.time)
        zip.append(littleEndian: dos.date)
        zip.append(littleEndian: crc)
        zip.append(littleEndian: UInt32(content.count))
        zip.append(littleEndian: UInt32(content.count))
        zip.append(littleEndian: UInt16(filenameData.count))
        zip.append(contentsOf: [0x00, 0x00]) // extra
        zip.append(contentsOf: [0x00, 0x00]) // comment
        zip.append(contentsOf: [0x00, 0x00]) // disk
        zip.append(contentsOf: [0x00, 0x00]) // internal attrs
        zip.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // external attrs
        zip.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // local header offset
        zip.append(filenameData)
        let cdSize = UInt32(zip.count) - cdStart

        // End of central directory
        zip.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        zip.append(contentsOf: [0x00, 0x00])
        zip.append(contentsOf: [0x00, 0x00])
        zip.append(contentsOf: [0x01, 0x00])
        zip.append(contentsOf: [0x01, 0x00])
        zip.append(littleEndian: cdSize)
        zip.append(littleEndian: cdStart)
        zip.append(contentsOf: [0x00, 0x00])
        return zip
    }

    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return ~crc
    }

    public static func dosDateTime(_ date: Date) -> (date: UInt16, time: UInt16) {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max(0, (components.year ?? 1980) - 1980)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2
        return (UInt16((year << 9) | (month << 5) | day), UInt16((hour << 11) | (minute << 5) | second))
    }
}

nonisolated extension Data {
    mutating func append<T: FixedWidthInteger>(bigEndian value: T) {
        var v = value.bigEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
