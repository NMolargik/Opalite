//
//  OpaliteColor.swift
//  OpaliteCore
//
//  A single sRGB color with authoring metadata. CloudKit rules: every attribute has a
//  default, relationships are optional, no unique constraints; new properties must be
//  additive. SwiftUI/UIKit bridging lives in OpaliteDesignSystem so Core stays pure.
//

import Foundation
import SwiftData

@Model
public final class OpaliteColor {
    // MARK: - Identity
    public var id: UUID = UUID()

    // MARK: - Display
    public var name: String?
    public var notes: String?

    // MARK: - Author
    public var createdByDisplayName: String?
    public var createdOnDeviceName: String?
    public var updatedOnDeviceName: String?

    // MARK: - Timestamps
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    // MARK: - Color (sRGB 0...1)
    public var red: Double = 0.0
    public var green: Double = 0.0
    public var blue: Double = 0.0
    public var alpha: Double = 1.0

    // MARK: - Relationships
    @Relationship(inverse: \OpalitePalette.colors)
    public var palette: OpalitePalette?

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        notes: String? = nil,
        createdByDisplayName: String? = nil,
        createdOnDeviceName: String? = nil,
        updatedOnDeviceName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1.0,
        palette: OpalitePalette? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdByDisplayName = createdByDisplayName
        self.createdOnDeviceName = createdOnDeviceName
        self.updatedOnDeviceName = updatedOnDeviceName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.palette = palette
    }
}

// MARK: - Value snapshot

extension OpaliteColor {
    /// The color's components as a Sendable value (for math, rendering, and transfer).
    public var rgba: RGBA { RGBA(red: red, green: green, blue: blue, alpha: alpha) }

    /// The name shown when the user hasn't typed one.
    public var displayName: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return hexString
    }

    /// Whether the user has given this color a name.
    public var hasName: Bool {
        !(name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

// MARK: - Color code representations

extension OpaliteColor {
    /// Canonical "#RRGGBB".
    public var hexString: String { rgba.hexString }
    /// "#RRGGBBAA".
    public var hexWithAlphaString: String { rgba.hexWithAlphaString }
    /// "rgb(r, g, b)" with 0–255 channels.
    public var rgbString: String { rgba.rgbString }
    /// "rgba(r, g, b, a)".
    public var rgbaString: String { rgba.rgbaString }
    /// "hsl(h, s%, l%)".
    public var hslString: String { rgba.hslString }

    public var hsl: HSL { rgba.hsl }
    public var hsv: HSV { rgba.hsv }
    public var cmyk: CMYK { rgba.cmyk }

    /// WCAG relative luminance (0 = dark, 1 = light).
    public var relativeLuminance: Double { rgba.relativeLuminance }

    /// Contrast ratio vs another color (1.0–21.0 per WCAG).
    public func contrastRatio(against other: OpaliteColor) -> Double {
        rgba.contrastRatio(against: other.rgba)
    }

    /// Whether black text reads better on this color than white.
    public var prefersDarkText: Bool { rgba.prefersDarkText }

    /// A copy with a different alpha (clamped to 0...1); keeps the same identity metadata
    /// but a fresh `updatedAt`.
    public func withAlpha(_ newAlpha: Double) -> OpaliteColor {
        OpaliteColor(
            name: name,
            notes: notes,
            createdByDisplayName: createdByDisplayName,
            createdAt: createdAt,
            updatedAt: Date(),
            red: red,
            green: green,
            blue: blue,
            alpha: ColorMath.clamp(newAlpha),
            palette: palette
        )
    }
}

// MARK: - Harmony

extension OpaliteColor {
    private func detached(_ components: RGBA, name: String) -> OpaliteColor {
        OpaliteColor(name: name, red: components.red, green: components.green, blue: components.blue, alpha: alpha)
    }

    /// Complementary: 180° opposite on the color wheel.
    public func complementaryColor() -> OpaliteColor {
        detached(ColorHarmony.complementary(of: rgba), name: "Complementary")
    }

    /// Analogous: ±30° from base.
    public func analogousColors() -> [OpaliteColor] {
        ColorHarmony.analogous(of: rgba).map { detached($0, name: "Analogous") }
    }

    /// Triadic: 120° apart.
    public func triadicColors() -> [OpaliteColor] {
        ColorHarmony.triadic(of: rgba).map { detached($0, name: "Triadic") }
    }

    /// Tetradic/Square: 90° apart.
    public func tetradicColors() -> [OpaliteColor] {
        ColorHarmony.tetradic(of: rgba).map { detached($0, name: "Tetradic") }
    }

    /// Split-complementary: ±30° from the complement.
    public func splitComplementaryColors() -> [OpaliteColor] {
        ColorHarmony.splitComplementary(of: rgba).map { detached($0, name: "Split-Comp") }
    }

    /// A display-only copy with color-vision-deficiency simulation applied (no palette).
    public func simulatingColorBlindness(_ mode: ColorBlindnessMode) -> OpaliteColor {
        guard mode != .off else { return self }
        let simulated = ColorBlindnessSimulator.simulate(rgba, mode: mode)
        return OpaliteColor(
            id: id,
            name: name,
            notes: notes,
            createdByDisplayName: createdByDisplayName,
            createdOnDeviceName: createdOnDeviceName,
            updatedOnDeviceName: updatedOnDeviceName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            red: simulated.red,
            green: simulated.green,
            blue: simulated.blue,
            alpha: alpha,
            palette: nil
        )
    }
}

extension Array where Element == OpaliteColor {
    /// Display-only copies with color-vision-deficiency simulation applied.
    public func simulatingColorBlindness(_ mode: ColorBlindnessMode) -> [OpaliteColor] {
        guard mode != .off else { return self }
        return map { $0.simulatingColorBlindness(mode) }
    }
}

// MARK: - Export / serialization

extension OpaliteColor {
    /// Dictionary representation for the native `.opalitecolor` format.
    public var dictionaryRepresentation: [String: Any] {
        [
            "id": id.uuidString,
            "name": name as Any,
            "notes": notes as Any,
            "hex": hexString,
            "hexWithAlpha": hexWithAlphaString,
            "rgb": rgbString,
            "rgba": rgbaString,
            "hsl": hslString,
            "red": red,
            "green": green,
            "blue": blue,
            "alpha": alpha,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
            "createdOnDeviceName": createdOnDeviceName ?? "Unknown",
            "createdByDisplayName": createdByDisplayName ?? "Unknown",
            "updatedOnDeviceName": updatedOnDeviceName ?? "Unknown",
        ]
    }

    /// Pretty-printed JSON for the native `.opalitecolor` format.
    public func jsonRepresentation() throws -> Data {
        try JSONSerialization.data(withJSONObject: dictionaryRepresentation, options: [.prettyPrinted, .sortedKeys])
    }
}

// MARK: - Samples (previews)

extension OpaliteColor {
    public static var sample: OpaliteColor {
        OpaliteColor(name: "Sample Blue", notes: "A nice blue color", createdByDisplayName: "Nick Molargik", createdOnDeviceName: "iPhone 17 Pro", updatedOnDeviceName: "iPhone 17 Pro", red: 0.20, green: 0.50, blue: 0.80)
    }
    public static var sample2: OpaliteColor {
        OpaliteColor(name: "Sample Red", notes: "A nice red color", createdByDisplayName: "Nick Molargik", createdOnDeviceName: "iPhone 17 Pro", updatedOnDeviceName: "iPhone 17 Pro", red: 0.80, green: 0.20, blue: 0.50)
    }
    public static var sample3: OpaliteColor {
        OpaliteColor(name: "Sample Green", notes: "A fresh green color", createdByDisplayName: "Nick Molargik", createdOnDeviceName: "iPhone 17 Pro", updatedOnDeviceName: "iPhone 17 Pro", red: 0.20, green: 0.70, blue: 0.30)
    }
    public static var sample4: OpaliteColor {
        OpaliteColor(name: "Sample Yellow", notes: "A vibrant yellow color", createdByDisplayName: "Nick Molargik", createdOnDeviceName: "iPhone 17 Pro", updatedOnDeviceName: "iPhone 17 Pro", red: 0.95, green: 0.82, blue: 0.20)
    }
    public static var sample5: OpaliteColor {
        OpaliteColor(name: "Sample Purple", notes: "A rich purple color", createdByDisplayName: "Nick Molargik", createdOnDeviceName: "iPhone 17 Pro", updatedOnDeviceName: "iPhone 17 Pro", red: 0.55, green: 0.30, blue: 0.75)
    }
    public static var samples: [OpaliteColor] { [sample, sample2, sample3, sample4, sample5] }
}
