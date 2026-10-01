//
//  QuickAddHexInput.swift
//  OpaliteFeaturePortfolio
//
//  The "Add by Hex" field's rules: only hex digits, upper-cased, at most eight, valid at
//  exactly six (RRGGBB) or eight (RRGGBBAA). Pure so the validation is host-tested.
//

import Foundation
import OpaliteCore

nonisolated public struct QuickAddHexInput: Equatable, Sendable {
    public static let maximumLength = 8

    /// The sanitized text as shown in the field (no "#", upper-case hex digits).
    public private(set) var text: String

    public init(_ raw: String = "") {
        text = Self.sanitize(raw)
    }

    /// Keeps hex digits only, upper-cased, capped at eight characters.
    public static func sanitize(_ raw: String) -> String {
        let digits = raw.filter(\.isHexDigit)
        return String(digits.prefix(maximumLength)).uppercased()
    }

    public mutating func update(_ raw: String) {
        text = Self.sanitize(raw)
    }

    /// The parsed color once six or eight digits are present.
    public var rgba: RGBA? {
        guard text.count == 6 || text.count == 8 else { return nil }
        return RGBA(hex: text)
    }

    public var isValid: Bool { rgba != nil }
    public var isEmpty: Bool { text.isEmpty }
    public var includesAlpha: Bool { text.count == 8 }

    /// Non-empty but not yet a complete code.
    public var isIncomplete: Bool { !text.isEmpty && !isValid }

    /// The inline guidance under the field while the code is incomplete.
    public var validationMessage: String? {
        guard isIncomplete else { return nil }
        return String(localized: "Enter 6 characters, or 8 to include opacity")
    }

    /// "#RRGGBB" or "#RRGGBBAA" for the preview.
    public var displayHex: String? {
        guard let rgba else { return nil }
        return includesAlpha ? rgba.hexWithAlphaString : rgba.hexString
    }
}
