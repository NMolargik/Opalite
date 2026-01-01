//
//  OpaliteColor.swift
//  Opalite
//
//  Created by Nick Molargik on 12/6/25.
//

import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

@Model
final class OpaliteColor {
    // MARK: - Identity
    var id: UUID = UUID()
    
    // MARK: - Display
    var name: String?
    var notes: String?
    
    // MARK: - Author
    var createdByDisplayName: String?
    var createdOnDeviceName: String?
    
    // MARK: - Timestamps
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var updatedOnDeviceName: String?
    
    // MARK: - Color (sRGB 0...1)
    var red: Double = 0.0
    var green: Double = 0.0
    var blue: Double = 0.0
    var alpha: Double = 1.0
    
    // MARK: - Relationships
    @Relationship(inverse: \OpalitePalette.colors)
    var palette: OpalitePalette?
    
    // MARK: - Transient / Computed
    
    /// SwiftUI Color for rendering (not persisted)
    @Transient
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    /// UIColor version (useful for UIKit integrations). Only available when UIKit can be imported.
    #if canImport(UIKit)
    @Transient
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif

    /// NSColor version (useful for AppKit/macOS integrations). Only available when AppKit can be imported.
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Transient
    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
    
    // MARK: - Init
    
    init(
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

// MARK: - Color Code Representations

extension OpaliteColor {
    /// Canonical hex string (no alpha) based on sRGB components
    var hexString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    /// Hex string including alpha (e.g., #RRGGBBAA)
    var hexWithAlphaString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        let a = Int(round(alpha * 255))
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }

    /// RGB string (0–255)
    var rgbString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return "rgb(\(r), \(g), \(b))"
    }

    /// RGBA string (0–255)
    var rgbaString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return "rgba(\(r), \(g), \(b), \(alpha))"
    }

    /// HSL representation
    var hslString: String {
        let r = red
        let g = green
        let b = blue

        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal

        var h: Double = 0
        var s: Double = 0
        let l: Double = (maxVal + minVal) / 2

        if delta != 0 {
            s = l > 0.5 ? delta / (2 - maxVal - minVal) : delta / (maxVal + minVal)

            if maxVal == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxVal == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }

            h /= 6
        }

        let hDeg = Int(round(h * 360))
        let sPerc = Int(round(s * 100))
        let lPerc = Int(round(l * 100))

        return "hsl(\(hDeg), \(sPerc)%, \(lPerc)%)"
    }

    // MARK: - HSL Helpers
    
    static func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal

        var h: Double = 0
        var s: Double = 0
        let l: Double = (maxVal + minVal) / 2

        if delta != 0 {
            s = l > 0.5 ? delta / (2 - maxVal - minVal) : delta / (maxVal + minVal)

            if maxVal == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxVal == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }

            h /= 6
        }

        return (h, s, l)
    }

    static func hslToRGB(h: Double, s: Double, l: Double) -> (r: Double, g: Double, b: Double) {
        func hueToRGB(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1/6 { return p + (q - p) * 6 * t }
            if t < 1/2 { return q }
            if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
            return p
        }

        if s == 0 {
            return (l, l, l)
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q

        let r = hueToRGB(p, q, h + 1/3)
        let g = hueToRGB(p, q, h)
        let b = hueToRGB(p, q, h - 1/3)

        return (r, g, b)
    }

    // MARK: - Color Harmony

    /// Helper to create a color at a given hue offset (in degrees)
    private func colorAtHueOffset(_ degrees: Double, name: String) -> OpaliteColor {
        let (h, s, l) = Self.rgbToHSL(r: red, g: green, b: blue)
        var newHue = h + (degrees / 360.0)
        if newHue > 1 { newHue -= 1 }
        if newHue < 0 { newHue += 1 }
        let rgb = Self.hslToRGB(h: newHue, s: s, l: l)
        return OpaliteColor(name: name, red: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha)
    }

    /// Complementary: 180° opposite on the color wheel
    func complementaryColor() -> OpaliteColor {
        colorAtHueOffset(180, name: "Complementary")
    }

    /// Analogous: ±30° from base (adjacent colors)
    func analogousColors() -> [OpaliteColor] {
        [
            colorAtHueOffset(-30, name: "Analogous"),
            colorAtHueOffset(30, name: "Analogous")
        ]
    }

    /// Triadic: 120° apart (3 evenly spaced colors)
    func triadicColors() -> [OpaliteColor] {
        [
            colorAtHueOffset(120, name: "Triadic"),
            colorAtHueOffset(240, name: "Triadic")
        ]
    }

    /// Tetradic/Square: 90° apart (4 evenly spaced colors)
    func tetradicColors() -> [OpaliteColor] {
        [
            colorAtHueOffset(90, name: "Tetradic"),
            colorAtHueOffset(180, name: "Tetradic"),
            colorAtHueOffset(270, name: "Tetradic")
        ]
    }

    /// Split-Complementary: base + two colors adjacent to the complement (±30° from 180°)
    func splitComplementaryColors() -> [OpaliteColor] {
        [
            colorAtHueOffset(150, name: "Split-Comp"),
            colorAtHueOffset(210, name: "Split-Comp")
        ]
    }

    /// Legacy alias for analogousColors()
    func harmoniousColors() -> [OpaliteColor] {
        analogousColors()
    }

    // MARK: - Accessibility

    /// WCAG relative luminance (0 = dark, 1 = light)
    var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            // sRGB → linear
            return c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        
        let rLin = channel(red)
        let gLin = channel(green)
        let bLin = channel(blue)
        
        // Rec. 709 / WCAG coefficients
        return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
    }
    
    /// Contrast ratio vs another color (1.0–21.0 per WCAG)
    func contrastRatio(against other: OpaliteColor) -> Double {
        let l1 = relativeLuminance
        let l2 = other.relativeLuminance
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Returns black or white depending on which has better contrast on this color
    func idealTextColor() -> Color {
        let black = OpaliteColor(name: "Black", red: 0, green: 0, blue: 0, alpha: 1)
        let white = OpaliteColor(name: "White", red: 1, green: 1, blue: 1, alpha: 1)
        
        let blackContrast = black.contrastRatio(against: self)
        let whiteContrast = white.contrastRatio(against: self)
        
        return blackContrast >= whiteContrast ? Color.black : Color.white
    }
    
    /// Returns a copy of this color with a different alpha
    func withAlpha(_ newAlpha: Double) -> OpaliteColor {
        let clampedAlpha = max(0, min(1, newAlpha))
        return OpaliteColor(
            name: name,
            notes: notes,
            createdByDisplayName: createdByDisplayName,
            createdAt: createdAt,
            updatedAt: Date(),
            red: red,
            green: green,
            blue: blue,
            alpha: clampedAlpha,
            palette: palette
        )
    }
}

// MARK: - Export / Serialization

extension OpaliteColor {
    /// Dictionary representation for flexible exporting
    var dictionaryRepresentation: [String: Any] {
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
            "updatedOnDeviceName": updatedOnDeviceName ?? "Unknown"
        ]
    }

    /// JSON representation (throws if encoding fails)
    func jsonRepresentation() throws -> Data {
        let exportStruct = dictionaryRepresentation
        return try JSONSerialization.data(withJSONObject: exportStruct, options: .prettyPrinted)
    }
}

extension OpaliteColor {
    /// A convenient sample color for SwiftUI previews
    static let sample: OpaliteColor = OpaliteColor(
        id: UUID(),
        name: "Sample Blue Blue Blue Blue",
        notes: "A nice blue color",
        createdByDisplayName: "Nick Molargik",
        createdOnDeviceName: "iPhone 17 Pro",
        updatedOnDeviceName: "iPhone 17 Pro",
        createdAt: Date(),
        updatedAt: Date(),
        red: 0.20,
        green: 0.50,
        blue: 0.80,
        alpha: 1.0
    )
    
    static let sample2: OpaliteColor = OpaliteColor(
        id: UUID(),
        name: "Sample Red",
        notes: "A nice red color",
        createdByDisplayName: "Nick Molargik",
        createdOnDeviceName: "iPhone 17 Pro",
        updatedOnDeviceName: "iPhone 17 Pro",
        createdAt: Date(),
        updatedAt: Date(),
        red: 0.80,
        green: 0.20,
        blue: 0.50,
        alpha: 1.0
    )
}
