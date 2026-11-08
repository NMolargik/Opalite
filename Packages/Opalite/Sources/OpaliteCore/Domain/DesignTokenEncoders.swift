//
//  DesignTokenEncoders.swift
//  OpaliteCore
//
//  Pure exporters for design-token formats: Tailwind v4 `@theme`, W3C Design Tokens
//  (DTCG 2025.10), an Xcode asset catalog (zipped), Android `colors.xml`, a Flutter
//  constants class, Sass variables, plain JSON, and a Figma-variables JSON. Every encoder
//  works over a `TokenSet` (optionally with a paired dark palette) and returns bytes, so
//  they are golden-tested on the host.
//

import Foundation

/// The colors going into a token file.
nonisolated public struct TokenSet: Sendable {
    /// Palette name (or the color's name for a single color); used in comments and file titles.
    public let title: String
    /// Words prefixed to each token name. Nil for a single color.
    public let prefix: String?
    public let swatches: [ExportSwatch]
    /// Dark-appearance counterparts, paired with `swatches` by position.
    public let darkSwatches: [ExportSwatch]?

    public init(title: String, prefix: String?, swatches: [ExportSwatch], darkSwatches: [ExportSwatch]? = nil) {
        self.title = title
        self.prefix = prefix
        self.swatches = swatches
        self.darkSwatches = darkSwatches
    }

    /// The dark counterpart of the swatch at `index`, when the dark palette reaches that far.
    func dark(at index: Int) -> RGBA? {
        guard let darkSwatches, index < darkSwatches.count else { return nil }
        return darkSwatches[index].rgba
    }

    var hasDark: Bool { (darkSwatches?.isEmpty == false) && !swatches.isEmpty }
}

// MARK: - Number formatting

nonisolated enum TokenNumber {
    /// "0.5", "1", "0.9019": fixed places with trailing zeros trimmed and no "-0".
    static func format(_ value: Double, places: Int = 4) -> String {
        var text = String(format: "%.\(places)f", value)
        if text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        return text == "-0" || text.isEmpty ? "0" : text
    }
}

// MARK: - Color helpers

nonisolated extension RGBA {
    /// An sRGB color that can be written as hex: the color itself, or its gamut-mapped
    /// approximation when it lies outside sRGB.
    var srgbFallback: RGBA {
        guard !isInSRGBGamut else { return self }
        var mapped = oklch.gamutMappedRGBA
        mapped.alpha = alpha
        return mapped
    }

    var isWide: Bool { !isInSRGBGamut }

    /// "#RRGGBB" of the sRGB fallback.
    var fallbackHex: String { srgbFallback.hexString }
}

// MARK: - A tiny ordered JSON writer

nonisolated indirect enum TokenJSON {
    case string(String)
    /// An already formatted number.
    case number(String)
    case bool(Bool)
    case array([TokenJSON])
    case object([(String, TokenJSON)])

    static func num(_ value: Double, places: Int = 4) -> TokenJSON { .number(TokenNumber.format(value, places: places)) }
    static func int(_ value: Int) -> TokenJSON { .number(String(value)) }

    /// - Parameter spaceBeforeColon: Xcode writes `"key" : value`.
    func render(spaceBeforeColon: Bool = false) -> String {
        var out = ""
        write(into: &out, indent: 0, separator: spaceBeforeColon ? " : " : ": ")
        return out
    }

    private func write(into out: inout String, indent: Int, separator: String) {
        let pad = String(repeating: "  ", count: indent)
        let inner = String(repeating: "  ", count: indent + 1)
        switch self {
        case .string(let text): out += Self.quote(text)
        case .number(let text): out += text
        case .bool(let flag): out += flag ? "true" : "false"
        case .array(let items):
            if items.isEmpty { out += "[]"; return }
            // Short numeric/string arrays stay on one line.
            let simple = items.allSatisfy { if case .number = $0 { true } else { false } }
            if simple {
                out += "[" + items.map { item -> String in
                    var piece = ""
                    item.write(into: &piece, indent: 0, separator: separator)
                    return piece
                }.joined(separator: ", ") + "]"
                return
            }
            out += "[\n"
            for (index, item) in items.enumerated() {
                out += inner
                item.write(into: &out, indent: indent + 1, separator: separator)
                out += index == items.count - 1 ? "\n" : ",\n"
            }
            out += pad + "]"
        case .object(let pairs):
            if pairs.isEmpty { out += "{}"; return }
            out += "{\n"
            for (index, pair) in pairs.enumerated() {
                out += inner + Self.quote(pair.0) + separator
                pair.1.write(into: &out, indent: indent + 1, separator: separator)
                out += index == pairs.count - 1 ? "\n" : ",\n"
            }
            out += pad + "}"
        }
    }

    static func quote(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 { result += String(format: "\\u%04x", scalar.value) } else { result.unicodeScalars.append(scalar) }
            }
        }
        return result + "\""
    }
}

// MARK: - Encoders

nonisolated public enum DesignTokenEncoders {

    private static func data(_ text: String) -> Data { Data((text + "\n").utf8) }

    /// Makes text safe inside an XML or CSS comment.
    private static func commentSafe(_ text: String) -> String {
        text.replacingOccurrences(of: "--", with: "- -").replacingOccurrences(of: "*/", with: "* /")
            .replacingOccurrences(of: "\n", with: " ")
    }

    // MARK: Tailwind CSS v4

    /// A Tailwind v4 `@theme` block with `--color-<palette>-<name>` variables in `oklch()`.
    /// Colors outside sRGB carry a comment with their sRGB fallback. With a dark palette, a
    /// `prefers-color-scheme: dark` block overrides the same variables.
    public static func tailwind(_ set: TokenSet) -> Data {
        let names = TokenNaming.uniqueNames(for: set.swatches, prefix: set.prefix, style: .kebab, leadingLetter: false)
        func line(_ name: String, _ c: RGBA, indent: String) -> String {
            var text = "\(indent)--color-\(name): \(c.oklchString);"
            if c.isWide { text += " /* outside sRGB, fallback \(c.fallbackHex) */" }
            return text
        }
        var lines = ["/* \(commentSafe(set.title)) - Tailwind CSS v4 theme, exported from Opalite */", "@theme {"]
        for (index, swatch) in set.swatches.enumerated() { lines.append(line(names[index], swatch.rgba, indent: "  ")) }
        lines.append("}")
        if set.hasDark {
            lines += ["", "/* Dark appearance: overrides the theme variables above. */", "@media (prefers-color-scheme: dark) {", "  :root {"]
            for index in set.swatches.indices {
                if let dark = set.dark(at: index) { lines.append(line(names[index], dark, indent: "    ")) }
            }
            lines += ["  }", "}"]
        }
        return data(lines.joined(separator: "\n"))
    }

    // MARK: W3C Design Tokens (DTCG 2025.10)

    /// The DTCG color value: `colorSpace`, `components`, optional `alpha`, and an sRGB `hex`.
    /// sRGB colors are written in `srgb`; wide-gamut ones in `display-p3` (or `oklch` beyond P3).
    static func dtcgValue(_ c: RGBA) -> TokenJSON {
        var pairs: [(String, TokenJSON)] = []
        let space: String
        let components: [Double]
        if !c.isWide {
            space = "srgb"
            components = [c.red, c.green, c.blue]
        } else if c.displayP3.isInGamut {
            space = "display-p3"
            components = [c.displayP3.red, c.displayP3.green, c.displayP3.blue]
        } else {
            space = "oklch"
            let lch = c.oklch
            components = [lch.lightness, lch.chroma, lch.hue]
        }
        pairs.append(("colorSpace", .string(space)))
        pairs.append(("components", .array(components.map { .num($0) })))
        if c.alpha < 1 { pairs.append(("alpha", .num(c.alpha))) }
        pairs.append(("hex", .string(c.fallbackHex.lowercased())))
        return .object(pairs)
    }

    /// A `tokens.json` per the Oct 2025 DTCG color module. A palette becomes a group of
    /// `$type: "color"` tokens; a paired dark palette rides along in `$extensions.mode.dark`.
    public static func dtcg(_ set: TokenSet) -> Data {
        let names = TokenNaming.uniqueNames(for: set.swatches, prefix: nil, style: .kebab, leadingLetter: false)
        var tokens: [(String, TokenJSON)] = []
        for (index, swatch) in set.swatches.enumerated() {
            var pairs: [(String, TokenJSON)] = [("$type", .string("color")), ("$value", dtcgValue(swatch.rgba))]
            if swatch.rgba.isWide {
                pairs.append(("$description", .string("Wide-gamut color. The hex value is an sRGB approximation.")))
            }
            if let dark = set.dark(at: index) {
                pairs.append(("$extensions", .object([("mode", .object([("dark", dtcgValue(dark))]))])))
            }
            tokens.append((names[index], .object(pairs)))
        }
        let root: TokenJSON
        if let prefix = set.prefix {
            let group = TokenNaming.words(prefix)
            root = .object([(group.isEmpty ? "palette" : TokenNameStyle.kebab.join(group), .object(tokens))])
        } else {
            root = .object(tokens)
        }
        return data(root.render())
    }

    // MARK: Xcode asset catalog

    private static func xcodeColor(_ c: RGBA) -> TokenJSON {
        let space: String
        let comps: [Double]
        if !c.isWide {
            space = "srgb"
            comps = [c.red, c.green, c.blue]
        } else if c.displayP3.isInGamut {
            space = "display-p3"
            comps = [c.displayP3.red, c.displayP3.green, c.displayP3.blue]
        } else {
            space = "extended-srgb"
            comps = [c.red, c.green, c.blue]
        }
        func fixed(_ v: Double) -> TokenJSON { .string(String(format: "%.3f", v)) }
        return .object([
            ("color-space", .string(space)),
            ("components", .object([
                ("alpha", fixed(c.alpha)), ("blue", fixed(comps[2])), ("green", fixed(comps[1])), ("red", fixed(comps[0])),
            ])),
        ])
    }

    private static let xcodeInfo: TokenJSON = .object([("author", .string("xcode")), ("version", .int(1))])

    /// The files of an `.xcassets` folder: a root `Contents.json` and one `.colorset` per color.
    /// Entries are display-p3 where the color is wide-gamut; with a dark palette each color set
    /// carries a universal and a dark-luminosity appearance. Paths are relative to the folder.
    public static func xcassetsFiles(_ set: TokenSet) -> [(path: String, data: Data)] {
        let names = TokenNaming.uniqueNames(for: set.swatches, prefix: set.prefix, style: .title, leadingLetter: false)
        var files: [(String, Data)] = [("Contents.json", data(TokenJSON.object([("info", xcodeInfo)]).render(spaceBeforeColon: true)))]
        for (index, swatch) in set.swatches.enumerated() {
            var entries: [TokenJSON] = [.object([("color", xcodeColor(swatch.rgba)), ("idiom", .string("universal"))])]
            if let dark = set.dark(at: index) {
                entries.append(.object([
                    ("appearances", .array([.object([("appearance", .string("luminosity")), ("value", .string("dark"))])])),
                    ("color", xcodeColor(dark)),
                    ("idiom", .string("universal")),
                ]))
            }
            let contents = TokenJSON.object([("colors", .array(entries)), ("info", xcodeInfo)])
            files.append(("\(names[index]).colorset/Contents.json", data(contents.render(spaceBeforeColon: true))))
        }
        return files
    }

    /// A zip containing `<catalogName>.xcassets/…`, ready to unzip into an Xcode project.
    public static func xcassetsArchive(_ set: TokenSet, catalogName: String, date: Date = Date()) -> Data {
        let root = "\(catalogName).xcassets"
        let entries = xcassetsFiles(set).map { ZipEntry(path: "\(root)/\($0.path)", content: $0.data) }
        return ZipArchive.stored(entries: entries, date: date)
    }

    // MARK: Android

    private static func androidHex(_ c: RGBA) -> String {
        let s = c.srgbFallback
        return c.alpha < 1
            ? String(format: "#%02X%02X%02X%02X", s.alpha.byte, s.red.byte, s.green.byte, s.blue.byte)
            : s.hexString
    }

    /// `res/values/colors.xml`. Dark counterparts become `<name>_dark` entries (Android has no
    /// automatic pairing; copy them into `values-night` under the light names).
    public static func androidColorsXML(_ set: TokenSet) -> Data {
        let names = TokenNaming.uniqueNames(
            for: set.swatches, prefix: set.prefix, style: .snake, reserved: TokenNaming.androidReserved,
            companionSuffix: set.hasDark ? "_dark" : nil
        )
        var lines = [
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>",
            "<!-- \(commentSafe(set.title)) - Exported from Opalite -->",
            "<resources>",
        ]
        for (index, swatch) in set.swatches.enumerated() {
            var line = "    <color name=\"\(names[index])\">\(androidHex(swatch.rgba))</color>"
            if swatch.rgba.isWide { line += " <!-- sRGB approximation of a wide-gamut color -->" }
            lines.append(line)
        }
        if set.hasDark {
            lines.append("    <!-- Dark appearance: copy these into res/values-night/colors.xml and drop the _dark suffix. -->")
            for index in set.swatches.indices {
                guard let dark = set.dark(at: index) else { continue }
                lines.append("    <color name=\"\(names[index])_dark\">\(androidHex(dark))</color>")
            }
        }
        lines.append("</resources>")
        return data(lines.joined(separator: "\n"))
    }

    // MARK: Flutter

    private static func dartColor(_ c: RGBA) -> String {
        if c.isWide, c.displayP3.isInGamut {
            let p3 = c.displayP3
            return "Color.from(alpha: \(TokenNumber.format(c.alpha)), red: \(TokenNumber.format(p3.red)), green: \(TokenNumber.format(p3.green)), blue: \(TokenNumber.format(p3.blue)), colorSpace: ColorSpace.displayP3)"
        }
        let s = c.srgbFallback
        return String(format: "Color(0x%02X%02X%02X%02X)", s.alpha.byte, s.red.byte, s.green.byte, s.blue.byte)
    }

    /// A Dart class of `static const Color` members. Wide-gamut colors use `Color.from` in
    /// Display P3 (Flutter 3.27+). Dark counterparts are `<name>Dark` members.
    public static func flutter(_ set: TokenSet) -> Data {
        let names = TokenNaming.uniqueNames(
            for: set.swatches, prefix: set.prefix, style: .lowerCamel, reserved: TokenNaming.dartReserved,
            companionSuffix: set.hasDark ? "Dark" : nil
        )
        let className = TokenNaming.typeName(set.prefix, fallback: "Opalite") + "Colors"
        let allColors = set.swatches.map(\.rgba) + (0..<set.swatches.count).compactMap { set.dark(at: $0) }
        let usesColorSpace = allColors.contains { $0.isWide && $0.displayP3.isInGamut }
        var lines = [
            "// \(commentSafe(set.title)) - Exported from Opalite",
            usesColorSpace ? "import 'dart:ui' show Color, ColorSpace;" : "import 'dart:ui' show Color;",
            "",
            "abstract final class \(className) {",
        ]
        for (index, swatch) in set.swatches.enumerated() {
            lines.append("  static const Color \(names[index]) = \(dartColor(swatch.rgba));")
            if let dark = set.dark(at: index) {
                lines.append("  static const Color \(names[index])Dark = \(dartColor(dark));")
            }
        }
        lines.append("}")
        return data(lines.joined(separator: "\n"))
    }

    // MARK: Sass

    private static func scssValue(_ c: RGBA) -> String {
        let s = c.srgbFallback
        return c.alpha < 1
            ? "rgba(\(s.red.byte), \(s.green.byte), \(s.blue.byte), \(String(format: "%.2f", c.alpha)))"
            : s.hexString
    }

    /// Sass variables (`$palette-name: #RRGGBB;`). Dark counterparts are `<name>-dark`
    /// variables; wide-gamut colors keep an sRGB value plus a comment with the original.
    public static func scss(_ set: TokenSet) -> Data {
        let names = TokenNaming.uniqueNames(
            for: set.swatches, prefix: set.prefix, style: .kebab,
            companionSuffix: set.hasDark ? "-dark" : nil
        )
        func line(_ name: String, _ c: RGBA) -> String {
            var text = "$\(name): \(scssValue(c));"
            if c.isWide { text += " // sRGB approximation of \(c.displayP3String)" }
            return text
        }
        var lines = ["// \(commentSafe(set.title)) - Exported from Opalite"]
        for (index, swatch) in set.swatches.enumerated() {
            lines.append(line(names[index], swatch.rgba))
            if let dark = set.dark(at: index) { lines.append(line(names[index] + "-dark", dark)) }
        }
        return data(lines.joined(separator: "\n"))
    }

    // MARK: Plain JSON

    private static func jsonColor(_ c: RGBA) -> [(String, TokenJSON)] {
        let lch = c.oklch
        let p3 = c.displayP3
        let s = c.srgbFallback
        return [
            ("hex", .string(s.hexString)),
            ("rgb", .object([("red", .int(s.red.byte)), ("green", .int(s.green.byte)), ("blue", .int(s.blue.byte))])),
            ("alpha", .num(c.alpha, places: 3)),
            ("oklch", .object([("lightness", .num(lch.lightness)), ("chroma", .num(lch.chroma)), ("hue", .num(lch.hue, places: 2))])),
            ("displayP3", .object([("red", .num(p3.red)), ("green", .num(p3.green)), ("blue", .num(p3.blue))])),
            ("inSRGBGamut", .bool(!c.isWide)),
        ]
    }

    /// Plain, tool-agnostic JSON: every color with hex, RGB, OKLCH and Display P3.
    public static func json(_ set: TokenSet) -> Data {
        let names = TokenNaming.uniqueNames(for: set.swatches, prefix: nil, style: .kebab, leadingLetter: false)
        var colors: [TokenJSON] = []
        for (index, swatch) in set.swatches.enumerated() {
            var pairs: [(String, TokenJSON)] = [("key", .string(names[index])), ("name", .string(swatch.resolvedName))]
            pairs += jsonColor(swatch.rgba)
            if let dark = set.dark(at: index) { pairs.append(("dark", .object(jsonColor(dark)))) }
            colors.append(.object(pairs))
        }
        let root = TokenJSON.object([("name", .string(set.title)), ("generator", .string("Opalite")), ("colors", .array(colors))])
        return data(root.render())
    }

    // MARK: Figma variables

    private static func figmaValue(_ c: RGBA) -> TokenJSON {
        let s = c.srgbFallback
        return .object([
            ("hex", .string(s.hexString)),
            ("r", .num(s.red)), ("g", .num(s.green)), ("b", .num(s.blue)), ("a", .num(c.alpha, places: 3)),
        ])
    }

    /// A flat variable collection for Figma import plugins: one COLOR variable per color,
    /// `Light` (and `Dark`) modes, sRGB values only. Figma has no OKLCH, so wide-gamut
    /// colors are gamut-mapped to sRGB and their Display P3 original is kept in `description`.
    public static func figmaVariables(_ set: TokenSet) -> Data {
        let names = TokenNaming.uniqueNames(for: set.swatches, prefix: nil, style: .kebab, leadingLetter: false)
        let group = set.prefix.map { TokenNameStyle.kebab.join(TokenNaming.words($0)) }.flatMap { $0.isEmpty ? nil : $0 }
        let modes = set.hasDark ? ["Light", "Dark"] : ["Light"]
        var variables: [TokenJSON] = []
        for (index, swatch) in set.swatches.enumerated() {
            var values: [(String, TokenJSON)] = [("Light", figmaValue(swatch.rgba))]
            if let dark = set.dark(at: index) { values.append(("Dark", figmaValue(dark))) }
            var pairs: [(String, TokenJSON)] = [
                ("name", .string(group.map { "\($0)/\(names[index])" } ?? names[index])),
                ("type", .string("COLOR")),
                ("values", .object(values)),
            ]
            if swatch.rgba.isWide {
                pairs.append(("description", .string("Display P3 original: \(swatch.rgba.displayP3String). Figma variables hold the sRGB approximation.")))
            }
            variables.append(.object(pairs))
        }
        let root = TokenJSON.object([
            ("collection", .string(set.title)),
            ("note", .string("Colors are sRGB. Figma variables do not support OKLCH or Display P3, so wide-gamut colors are gamut-mapped and keep their Display P3 value in the description.")),
            ("modes", .array(modes.map { .string($0) })),
            ("variables", .array(variables)),
        ])
        return data(root.render())
    }
}
