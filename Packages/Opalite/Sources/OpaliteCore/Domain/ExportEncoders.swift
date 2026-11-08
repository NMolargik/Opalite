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

    /// CSS custom properties on `:root`. With `darkSwatches`, the same properties are
    /// overridden inside `@media (prefers-color-scheme: dark)`, paired with the light
    /// swatches by position; extra dark swatches are ignored and missing ones keep the
    /// light value.
    public static func css(title: String, prefix: String?, swatches: [ExportSwatch], darkSwatches: [ExportSwatch]? = nil) -> Data {
        var lines = ["/* \(title) - Exported from Opalite */", ":root {"]
        let prefixSlug = prefix.map(cssSlug)
        func slug(for swatch: ExportSwatch) -> String {
            var slug = cssSlug(swatch.resolvedName)
            if let prefixSlug, !prefixSlug.isEmpty { slug = "\(prefixSlug)-\(slug)" }
            return slug
        }
        func declarations(_ slug: String, _ c: RGBA, indent: String) -> [String] {
            let value = c.alpha < 1
                ? "rgba(\(c.red.byte), \(c.green.byte), \(c.blue.byte), \(String(format: "%.2f", c.alpha)))"
                : "rgb(\(c.red.byte), \(c.green.byte), \(c.blue.byte))"
            var lines = ["\(indent)--\(slug): \(value);", "\(indent)--\(slug)-hex: \(c.hexString);", "\(indent)--\(slug)-oklch: \(c.oklchString);"]
            if !c.isInSRGBGamut { lines.append("\(indent)--\(slug)-p3: \(c.displayP3String);") }
            return lines
        }
        for swatch in swatches {
            lines += declarations(slug(for: swatch), swatch.rgba, indent: "  ")
        }
        lines.append("}")
        if let darkSwatches {
            let pairs = Array(zip(swatches, darkSwatches))
            if !pairs.isEmpty {
                lines.append("")
                lines.append("@media (prefers-color-scheme: dark) {")
                lines.append("  :root {")
                for (light, dark) in pairs {
                    lines += declarations(slug(for: light), dark.rgba, indent: "    ")
                }
                lines.append("  }")
                lines.append("}")
            }
        }
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

    /// A `Color` extension with one static constant per swatch. With `darkSwatches`,
    /// each paired constant becomes an adaptive color that resolves per appearance
    /// through a small `Color(light:dark:)` helper appended to the file; swatches past
    /// the end of the dark palette stay fixed.
    public static func swiftUI(title: String, prefix: String?, swatches: [ExportSwatch], darkSwatches: [ExportSwatch]? = nil) -> Data {
        var lines = ["// \(title) - Exported from Opalite", "import SwiftUI", "", "extension Color {"]
        let typePrefix = prefix.map(upperCamel) ?? ""
        func literal(_ c: RGBA, indent: String) -> [String] {
            // Colors outside sRGB (wide-gamut samples) are emitted in Display P3 so they survive.
            let wide = !c.isInSRGBGamut
            let p3 = c.displayP3
            return [
                "\(indent)Color(",
                wide ? "\(indent)    .displayP3," : nil,
                "\(indent)    red: \(String(format: "%.3f", wide ? p3.red : c.red)),",
                "\(indent)    green: \(String(format: "%.3f", wide ? p3.green : c.green)),",
                "\(indent)    blue: \(String(format: "%.3f", wide ? p3.blue : c.blue)),",
                "\(indent)    opacity: \(String(format: "%.2f", c.alpha))",
                "\(indent))",
            ].compactMap { $0 }
        }
        var usedAdaptive = false
        for (index, swatch) in swatches.enumerated() {
            var property = lowerCamel(swatch.resolvedName)
            if !typePrefix.isEmpty {
                property = lowerCamel(typePrefix) + property.prefix(1).uppercased() + property.dropFirst()
            }
            if let darkSwatches, index < darkSwatches.count {
                usedAdaptive = true
                lines.append("    static let \(property) = Color(")
                let light = literal(swatch.rgba, indent: "        ")
                let dark = literal(darkSwatches[index].rgba, indent: "        ")
                lines.append("        light: " + light[0].trimmingCharacters(in: .whitespaces))
                lines += light.dropFirst().dropLast()
                lines.append("        ),")
                lines.append("        dark: " + dark[0].trimmingCharacters(in: .whitespaces))
                lines += dark.dropFirst().dropLast()
                lines.append("        )")
                lines.append("    )")
            } else {
                let body = literal(swatch.rgba, indent: "    ")
                lines.append("    static let \(property) = " + body[0].trimmingCharacters(in: .whitespaces))
                lines += body.dropFirst()
            }
            lines.append("")
        }
        if lines.last == "" { lines.removeLast() }
        lines.append("}")
        if usedAdaptive {
            lines += [
                "",
                "extension Color {",
                "    /// Resolves to `light` or `dark` with the current appearance.",
                "    init(light: Color, dark: Color) {",
                "        #if canImport(UIKit)",
                "        self.init(uiColor: UIColor { traits in",
                "            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)",
                "        })",
                "        #elseif canImport(AppKit)",
                "        self.init(nsColor: NSColor(name: nil) { appearance in",
                "            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)",
                "        })",
                "        #else",
                "        self = light",
                "        #endif",
                "    }",
                "}",
            ]
        }
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

/// One file in a stored ZIP.
nonisolated public struct ZipEntry: Sendable {
    public let path: String
    public let content: Data

    public init(path: String, content: Data) {
        self.path = path
        self.content = content
    }
}

nonisolated public enum ZipArchive {
    /// A minimal ZIP containing one uncompressed entry.
    public static func stored(filename: String, content: Data, date: Date = Date()) -> Data {
        stored(entries: [ZipEntry(path: filename, content: content)], date: date)
    }

    /// A ZIP of uncompressed entries (paths use "/" separators).
    public static func stored(entries: [ZipEntry], date: Date = Date()) -> Data {
        var zip = Data()
        let dos = dosDateTime(date)
        var directory = Data()

        for entry in entries {
            let name = Data(entry.path.utf8)
            let crc = crc32(entry.content)
            let offset = UInt32(zip.count)
            let utf8Flag: UInt16 = entry.path.utf8.contains { $0 > 0x7F } ? 0x0800 : 0

            // Local file header
            zip.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            zip.append(contentsOf: [0x14, 0x00]) // version needed
            zip.append(littleEndian: utf8Flag)
            zip.append(contentsOf: [0x00, 0x00]) // stored
            zip.append(littleEndian: dos.time)
            zip.append(littleEndian: dos.date)
            zip.append(littleEndian: crc)
            zip.append(littleEndian: UInt32(entry.content.count))
            zip.append(littleEndian: UInt32(entry.content.count))
            zip.append(littleEndian: UInt16(name.count))
            zip.append(contentsOf: [0x00, 0x00]) // extra length
            zip.append(name)
            zip.append(entry.content)

            // Central directory record
            directory.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            directory.append(contentsOf: [0x14, 0x00]) // version made by
            directory.append(contentsOf: [0x14, 0x00]) // version needed
            directory.append(littleEndian: utf8Flag)
            directory.append(contentsOf: [0x00, 0x00])
            directory.append(littleEndian: dos.time)
            directory.append(littleEndian: dos.date)
            directory.append(littleEndian: crc)
            directory.append(littleEndian: UInt32(entry.content.count))
            directory.append(littleEndian: UInt32(entry.content.count))
            directory.append(littleEndian: UInt16(name.count))
            directory.append(contentsOf: [0x00, 0x00]) // extra
            directory.append(contentsOf: [0x00, 0x00]) // comment
            directory.append(contentsOf: [0x00, 0x00]) // disk
            directory.append(contentsOf: [0x00, 0x00]) // internal attrs
            directory.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // external attrs
            directory.append(littleEndian: offset)
            directory.append(name)
        }

        let cdStart = UInt32(zip.count)
        zip.append(directory)

        // End of central directory
        zip.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        zip.append(contentsOf: [0x00, 0x00])
        zip.append(contentsOf: [0x00, 0x00])
        zip.append(littleEndian: UInt16(entries.count))
        zip.append(littleEndian: UInt16(entries.count))
        zip.append(littleEndian: UInt32(directory.count))
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
