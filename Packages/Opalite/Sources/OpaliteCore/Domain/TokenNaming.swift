//
//  TokenNaming.swift
//  OpaliteCore
//
//  Name sanitizing shared by the design-token exporters. A color name becomes a list of
//  lowercase ASCII words (diacritics folded, everything else dropped; a name with no
//  usable letters falls back to its hex), which each format then joins in its own style.
//  Names are made unique per file after sanitizing, so "Dusty Rose" and "dusty-rose" never
//  collapse into one token, and reserved words of the target language are avoided.
//

import Foundation

/// How a format spells a token name.
nonisolated public enum TokenNameStyle: Sendable {
    /// `dusty-rose` (CSS, Tailwind, Sass, DTCG, JSON, Figma).
    case kebab
    /// `dusty_rose` (Android resources).
    case snake
    /// `dustyRose` (Dart members).
    case lowerCamel
    /// `Dusty Rose`: Xcode asset names (spaces allowed, matched case-insensitively).
    case title

    /// Joins words in this style.
    func join(_ words: [String]) -> String {
        switch self {
        case .kebab: return words.joined(separator: "-")
        case .snake: return words.joined(separator: "_")
        case .lowerCamel:
            return words.enumerated().map { $0.offset == 0 ? $0.element : $0.element.capitalized }.joined()
        case .title: return words.map(\.capitalized).joined(separator: " ")
        }
    }

    /// The text appended to break a tie ("-2", "_2", "2", " 2").
    func tieBreaker(_ number: Int) -> String {
        switch self {
        case .kebab: "-\(number)"
        case .snake: "_\(number)"
        case .lowerCamel: "\(number)"
        case .title: " \(number)"
        }
    }

    var caseInsensitive: Bool { self == .title }
}

nonisolated public enum TokenNaming {

    /// Words reserved by Dart: a member with one of these names gets "Color" appended.
    public static let dartReserved: Set<String> = [
        "abstract", "as", "assert", "async", "await", "break", "case", "catch", "class", "const", "continue",
        "covariant", "default", "deferred", "do", "dynamic", "else", "enum", "export", "extends", "extension",
        "external", "factory", "false", "final", "finally", "for", "get", "hide", "if", "implements", "import",
        "in", "interface", "is", "late", "library", "mixin", "new", "null", "on", "operator", "part", "required",
        "rethrow", "return", "sealed", "set", "show", "static", "super", "switch", "sync", "this", "throw", "true",
        "try", "typedef", "var", "void", "when", "while", "with", "yield",
    ]

    /// Words reserved by Java and Kotlin: an Android resource with one of these names (which
    /// becomes `R.color.<name>`) gets "_color" appended.
    public static let androidReserved: Set<String> = [
        "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue",
        "default", "do", "double", "else", "enum", "extends", "false", "final", "finally", "float", "for", "goto",
        "if", "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "null", "package",
        "private", "protected", "public", "return", "short", "static", "strictfp", "super", "switch",
        "synchronized", "this", "throw", "throws", "transient", "true", "try", "void", "volatile", "while",
        "fun", "val", "var", "when", "object", "is", "in", "as",
    ]

    /// Lowercase ASCII words of `text`: "Crème Brûlée #2" → ["creme", "brulee", "2"].
    public static func words(_ text: String) -> [String] {
        let folded = text.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        var words: [String] = []
        var current = ""
        for scalar in folded.unicodeScalars {
            if scalar.isASCII, CharacterSet.alphanumerics.contains(scalar) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                words.append(current.lowercased())
                current = ""
            }
        }
        if !current.isEmpty { words.append(current.lowercased()) }
        return words
    }

    /// The words naming one swatch: the user's name, or the hex digits when the name has
    /// no usable letters or digits (an unnamed color, or a name in a script that can't be
    /// expressed in an identifier).
    public static func words(for swatch: ExportSwatch) -> [String] {
        let own = words(swatch.name ?? "")
        if !own.isEmpty { return own }
        return [swatch.rgba.hexString.replacingOccurrences(of: "#", with: "").lowercased()]
    }

    /// One unique name per swatch, in the given style.
    ///
    /// - Parameters:
    ///   - prefix: Words put in front of every name (a palette name).
    ///   - leadingLetter: Prepend "color" when a name would start with a digit.
    ///   - reserved: Lowercased words that can't be used as-is; "Color" (camel) or "_color" is appended.
    ///   - companionSuffix: A suffix that is also reserved for every name (the "_dark" twin), so no
    ///     two names can end up colliding with a companion.
    public static func uniqueNames(
        for swatches: [ExportSwatch],
        prefix: String? = nil,
        style: TokenNameStyle,
        leadingLetter: Bool = true,
        reserved: Set<String> = [],
        companionSuffix: String? = nil
    ) -> [String] {
        let prefixWords = prefix.map(words) ?? []
        var used = Set<String>()
        func key(_ name: String) -> String { style.caseInsensitive ? name.lowercased() : name }
        func isFree(_ name: String) -> Bool {
            if used.contains(key(name)) { return false }
            if let companionSuffix, used.contains(key(name + companionSuffix)) { return false }
            return true
        }
        func claim(_ name: String) {
            used.insert(key(name))
            if let companionSuffix { used.insert(key(name + companionSuffix)) }
        }

        return swatches.map { swatch in
            var parts = prefixWords + words(for: swatch)
            if leadingLetter, let first = parts.first?.first, first.isNumber { parts.insert("color", at: 0) }
            var base = style.join(parts)
            if reserved.contains(base.lowercased()) {
                switch style {
                case .lowerCamel: base += "Color"
                case .snake: base += "_color"
                case .kebab: base += "-color"
                case .title: base += " Color"
                }
            }
            var candidate = base
            var counter = 2
            while !isFree(candidate) {
                candidate = base + style.tieBreaker(counter)
                counter += 1
            }
            claim(candidate)
            return candidate
        }
    }

    /// "Summer Sunset" → "SummerSunset"; falls back to `fallback` when nothing usable remains
    /// or the result would start with a digit.
    public static func typeName(_ text: String?, fallback: String) -> String {
        guard let text else { return fallback }
        let joined = words(text).map(\.capitalized).joined()
        if joined.isEmpty { return fallback }
        return joined.first!.isNumber ? fallback + joined : joined
    }
}
