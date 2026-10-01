//
//  ColorClassifier.swift
//  OpaliteCore
//
//  Names a color's family ("blue", "dark red", "pastel green") for search and for the
//  Apple Intelligence naming prompt. Pure HSL thresholds, host-tested.
//

import Foundation

nonisolated public enum ColorFamily: String, CaseIterable, Sendable {
    case red, orange, yellow, green, cyan, blue, purple, pink, brown, gray, black, white

    /// Alternate words a user might type for this family.
    public var aliases: [String] {
        switch self {
        case .gray: ["grey"]
        case .cyan: ["teal"]
        case .purple: ["violet"]
        case .pink: ["magenta"]
        case .brown: ["tan", "beige"]
        default: []
        }
    }

    public var isChromatic: Bool { ![.black, .white, .gray].contains(self) }
}

nonisolated public enum ColorClassifier {
    /// The dominant family for a color.
    public static func family(of color: RGBA) -> ColorFamily {
        let hsl = color.hsl
        let hue = hsl.hue
        let sat = hsl.saturation * 100
        let light = hsl.lightness * 100

        if light < 12 { return .black }
        if light > 92 && sat < 50 { return .white }
        if light > 85 && sat < 25 { return .white }
        if sat < 15 {
            if light < 20 { return .black }
            if light > 80 { return .white }
            return .gray
        }
        if light < 20 && sat < 40 { return .black }
        if (hue < 45 || hue >= 345) && sat >= 20 && sat <= 65 && light >= 15 && light <= 50 { return .brown }

        switch Int(hue) {
        case 0..<15, 345..<360: return .red
        case 15..<45: return .orange
        case 45..<75: return .yellow
        case 75..<150: return .green
        case 150..<195: return .cyan
        case 195..<255: return .blue
        case 255..<285: return .purple
        default: return .pink
        }
    }

    /// Every searchable term: family, aliases, and brightness/saturation modifiers.
    public static func searchTerms(for color: RGBA) -> [String] {
        let family = family(of: color)
        let hsl = color.hsl
        let sat = hsl.saturation * 100
        let light = hsl.lightness * 100

        var terms = [family.rawValue] + family.aliases
        let familyTerms = terms

        if family.isChromatic {
            if light < 35 {
                terms.append("dark")
                terms += familyTerms.map { "dark \($0)" }
            } else if light > 65 {
                terms += ["light", "pastel"]
                terms += familyTerms.flatMap { ["light \($0)", "pastel \($0)"] }
            }
            if sat >= 15 && sat < 45 {
                terms += ["muted", "dusty"]
            } else if sat > 75 {
                terms += ["vibrant", "bright"]
            }
        }
        return terms
    }

    /// Whether a free-text query ("blu", "dark blue") describes this color.
    public static func matches(_ color: RGBA, query: String) -> Bool {
        let query = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return false }
        return searchTerms(for: color).contains { term in
            if term == query { return true }
            if term.hasPrefix(query) { return true }
            if query.hasPrefix(term) && term.count >= 3 { return true }
            if query.contains(" ") {
                let queryWords = query.split(separator: " ").map(String.init)
                let termWords = term.split(separator: " ").map(String.init)
                if termWords.count >= queryWords.count {
                    return queryWords.allSatisfy { queryWord in
                        termWords.contains { $0.hasPrefix(queryWord) }
                    }
                }
            }
            return false
        }
    }

    /// A short human description for the naming prompt ("muted dark blue").
    public static func description(of color: RGBA) -> String {
        let hsl = color.hsl
        let sat = Int(hsl.saturation * 100)
        let light = Int(hsl.lightness * 100)
        if sat < 10 {
            if light < 20 { return "black/very dark gray" }
            if light > 80 { return "white/very light gray" }
            return "gray"
        }
        var modifiers: [String] = []
        if light < 30 { modifiers.append("dark") } else if light > 70 { modifiers.append("light") }
        if sat < 40 { modifiers.append("muted") } else if sat > 80 { modifiers.append("vibrant") }
        let base = family(of: color)
        let hueName = base == .pink ? "magenta/pink" : base.rawValue
        return modifiers.isEmpty ? hueName : "\(modifiers.joined(separator: " ")) \(hueName)"
    }
}
