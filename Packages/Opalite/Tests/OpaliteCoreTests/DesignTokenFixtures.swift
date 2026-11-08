//
//  DesignTokenFixtures.swift
//  OpaliteCoreTests
//

import Foundation
@testable import OpaliteCore

/// A palette that exercises naming (collisions, diacritics, reserved words, non-Latin names,
/// unnamed colors), wide gamut, alpha, and a paired dark palette.
enum DesignTokenFixtures {
    static let swatches: [ExportSwatch] = [
        ExportSwatch(name: "Dusty Rose", rgba: RGBA(red: 0.8, green: 0.5, blue: 0.55)),
        ExportSwatch(name: "dusty-rose", rgba: RGBA(red: 0.2, green: 0.4, blue: 0.6)),
        ExportSwatch(name: nil, rgba: RGBA(red: 1, green: 0.34, blue: 0.2)),
        ExportSwatch(name: "Neon Lime", rgba: RGBA(red: -0.1, green: 1.0, blue: 0.1)),
        ExportSwatch(name: "default", rgba: RGBA(red: 0.1, green: 0.1, blue: 0.1)),
        ExportSwatch(name: "Crème Brûlée", rgba: RGBA(red: 0.95, green: 0.85, blue: 0.6)),
        ExportSwatch(name: "夕焼け", rgba: RGBA(red: 0.9, green: 0.4, blue: 0.2)),
        ExportSwatch(name: "Glass", rgba: RGBA(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.5)),
    ]

    static let darkSwatches: [ExportSwatch] = [
        ExportSwatch(name: "Dusty Rose", rgba: RGBA(red: 0.4, green: 0.2, blue: 0.25)),
        ExportSwatch(name: "dusty-rose", rgba: RGBA(red: 0.1, green: 0.2, blue: 0.3)),
        ExportSwatch(name: nil, rgba: RGBA(red: 0.5, green: 0.17, blue: 0.1)),
    ]

    static func set(dark: Bool, prefix: String? = "Summer Sunset") -> TokenSet {
        TokenSet(title: prefix ?? "Dusty Rose", prefix: prefix, swatches: swatches, darkSwatches: dark ? darkSwatches : nil)
    }

    /// A two-color palette (one wide-gamut) with a dark counterpart for the first, for the JSON goldens.
    static let compact = TokenSet(
        title: "Summer Sunset",
        prefix: "Summer Sunset",
        swatches: [swatches[0], swatches[3]],
        darkSwatches: [darkSwatches[0]]
    )
}
