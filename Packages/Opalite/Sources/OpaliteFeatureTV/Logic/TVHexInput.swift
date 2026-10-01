//
//  TVHexInput.swift
//  OpaliteFeatureTV
//
//  Normalizes what the user types into the quick-add hex field on the Siri Remote keyboard.
//

import Foundation
import OpaliteCore

nonisolated public enum TVHexInput {
    /// Keeps only hex digits, uppercases, limits to 8 digits, and restores the leading "#".
    public static func normalized(_ raw: String) -> String {
        let digits = raw.uppercased().filter { $0.isHexDigit }
        return "#" + String(digits.prefix(8))
    }

    /// The parsed color for a normalized string, or nil until it is a valid 3/6/8-digit hex.
    public static func parse(_ text: String) -> RGBA? {
        ColorMath.parseHex(text)
    }

    /// A trimmed name, or nil when empty.
    public static func cleanName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
