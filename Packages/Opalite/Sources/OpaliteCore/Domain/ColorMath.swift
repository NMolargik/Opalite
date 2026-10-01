//
//  ColorMath.swift
//  OpaliteCore
//
//  The pure color-space math every surface shares: sRGB ↔ HSL/HSV/CMYK, hex formatting,
//  WCAG luminance/contrast, and the `RGBA` value type that models, community colors,
//  widgets, and the watch all convert to.
//

import Foundation

// MARK: - Value types

/// sRGB components in 0...1.
nonisolated public struct RGBA: Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses "#RRGGBB", "RRGGBB", "#RGB", "#RRGGBBAA" (case-insensitive).
    public init?(hex: String) {
        guard let parsed = ColorMath.parseHex(hex) else { return nil }
        self = parsed
    }

    public var hexString: String { ColorMath.hexString(red: red, green: green, blue: blue) }
    public var hexWithAlphaString: String { ColorMath.hexString(red: red, green: green, blue: blue, alpha: alpha) }
    public var rgbString: String { "rgb(\(red.byte), \(green.byte), \(blue.byte))" }
    public var rgbaString: String { "rgba(\(red.byte), \(green.byte), \(blue.byte), \(ColorMath.trimmed(alpha)))" }
    public var hslString: String {
        let hsl = hsl
        return "hsl(\(Int(round(hsl.hue))), \(Int(round(hsl.saturation * 100)))%, \(Int(round(hsl.lightness * 100)))%)"
    }

    public var hsl: HSL { ColorMath.hsl(from: self) }
    public var hsv: HSV { ColorMath.hsv(from: self) }
    public var cmyk: CMYK { ColorMath.cmyk(from: self) }

    public var relativeLuminance: Double { ColorMath.relativeLuminance(red: red, green: green, blue: blue) }
    public func contrastRatio(against other: RGBA) -> Double { ColorMath.contrastRatio(relativeLuminance, other.relativeLuminance) }
    /// Whether dark (black) text reads better on this color than white.
    public var prefersDarkText: Bool { relativeLuminance > ColorMath.darkTextLuminanceThreshold }

    public static let black = RGBA(red: 0, green: 0, blue: 0)
    public static let white = RGBA(red: 1, green: 1, blue: 1)
}

/// Hue in degrees 0..<360, saturation and lightness 0...1.
nonisolated public struct HSL: Hashable, Sendable {
    public var hue: Double
    public var saturation: Double
    public var lightness: Double

    public init(hue: Double, saturation: Double, lightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }

    public var rgba: RGBA { ColorMath.rgba(from: self) }
}

/// Hue in degrees 0..<360, saturation and value 0...1.
nonisolated public struct HSV: Hashable, Sendable {
    public var hue: Double
    public var saturation: Double
    public var value: Double

    public init(hue: Double, saturation: Double, value: Double) {
        self.hue = hue
        self.saturation = saturation
        self.value = value
    }

    public var rgba: RGBA { ColorMath.rgba(from: self) }
}

/// Components 0...1.
nonisolated public struct CMYK: Hashable, Sendable {
    public var cyan: Double
    public var magenta: Double
    public var yellow: Double
    public var key: Double

    public init(cyan: Double, magenta: Double, yellow: Double, key: Double) {
        self.cyan = cyan
        self.magenta = magenta
        self.yellow = yellow
        self.key = key
    }
}

// MARK: - Math

nonisolated public enum ColorMath {
    /// Luminance above which black text has better contrast than white (WCAG-derived).
    public static let darkTextLuminanceThreshold = 0.179

    public static func clamp(_ value: Double) -> Double { max(0, min(1, value)) }

    // MARK: Hex

    public static func hexString(red: Double, green: Double, blue: Double) -> String {
        String(format: "#%02X%02X%02X", red.byte, green.byte, blue.byte)
    }

    public static func hexString(red: Double, green: Double, blue: Double, alpha: Double) -> String {
        String(format: "#%02X%02X%02X%02X", red.byte, green.byte, blue.byte, alpha.byte)
    }

    public static func parseHex(_ text: String) -> RGBA? {
        var hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") { hex.removeFirst(2) }
        guard !hex.isEmpty, hex.allSatisfy(\.isHexDigit) else { return nil }

        if hex.count == 3 || hex.count == 4 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else { return nil }

        if hex.count == 8 {
            return RGBA(
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                alpha: Double(value & 0xFF) / 255
            )
        }
        return RGBA(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// True when `text` is a complete 3/4/6/8-digit hex code (with or without "#").
    public static func isValidHex(_ text: String) -> Bool { parseHex(text) != nil }

    // MARK: HSL

    public static func hsl(from rgba: RGBA) -> HSL {
        let r = rgba.red, g = rgba.green, b = rgba.blue
        let maxVal = max(r, g, b), minVal = min(r, g, b)
        let delta = maxVal - minVal
        let l = (maxVal + minVal) / 2
        var h = 0.0, s = 0.0

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
        return HSL(hue: h * 360, saturation: s, lightness: l)
    }

    public static func rgba(from hsl: HSL) -> RGBA {
        let h = ((hsl.hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360
        let s = clamp(hsl.saturation), l = clamp(hsl.lightness)
        if s == 0 { return RGBA(red: l, green: l, blue: l) }

        func hueToRGB(_ p: Double, _ q: Double, _ t: Double) -> Double {
            var t = t
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }

        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        return RGBA(red: hueToRGB(p, q, h + 1 / 3), green: hueToRGB(p, q, h), blue: hueToRGB(p, q, h - 1 / 3))
    }

    // MARK: HSV

    public static func hsv(from rgba: RGBA) -> HSV {
        let r = rgba.red, g = rgba.green, b = rgba.blue
        let maxVal = max(r, g, b), minVal = min(r, g, b)
        let delta = maxVal - minVal
        var h = 0.0
        let s = maxVal == 0 ? 0 : delta / maxVal
        if delta != 0 {
            if maxVal == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxVal == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
        }
        return HSV(hue: h * 360, saturation: s, value: maxVal)
    }

    public static func rgba(from hsv: HSV) -> RGBA {
        let h = ((hsv.hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 60
        let s = clamp(hsv.saturation), v = clamp(hsv.value)
        let i = floor(h)
        let f = h - i
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch Int(i) % 6 {
        case 0: return RGBA(red: v, green: t, blue: p)
        case 1: return RGBA(red: q, green: v, blue: p)
        case 2: return RGBA(red: p, green: v, blue: t)
        case 3: return RGBA(red: p, green: q, blue: v)
        case 4: return RGBA(red: t, green: p, blue: v)
        default: return RGBA(red: v, green: p, blue: q)
        }
    }

    // MARK: CMYK

    public static func cmyk(from rgba: RGBA) -> CMYK {
        let k = 1 - max(rgba.red, rgba.green, rgba.blue)
        guard k < 1 else { return CMYK(cyan: 0, magenta: 0, yellow: 0, key: 1) }
        return CMYK(
            cyan: (1 - rgba.red - k) / (1 - k),
            magenta: (1 - rgba.green - k) / (1 - k),
            yellow: (1 - rgba.blue - k) / (1 - k),
            key: k
        )
    }

    // MARK: WCAG

    /// sRGB → linear.
    public static func sRGBToLinear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    /// Linear → sRGB.
    public static func linearToSRGB(_ value: Double) -> Double {
        value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
    }

    /// WCAG relative luminance (0 = dark, 1 = light).
    public static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG contrast ratio between two luminances (1...21).
    public static func contrastRatio(_ l1: Double, _ l2: Double) -> Double {
        let lighter = max(l1, l2), darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Formats an alpha/fraction without trailing zeros ("1", "0.5", "0.25").
    public static func trimmed(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        var result = formatted
        while result.contains(".") && (result.hasSuffix("0") || result.hasSuffix(".")) {
            result.removeLast()
        }
        return result.isEmpty ? "0" : result
    }
}

// MARK: - WCAG levels

/// WCAG 2.x conformance for a contrast ratio.
nonisolated public struct WCAGConformance: Equatable, Sendable {
    public let ratio: Double

    public init(ratio: Double) { self.ratio = ratio }

    public var passesAANormalText: Bool { ratio >= 4.5 }
    public var passesAALargeText: Bool { ratio >= 3.0 }
    public var passesAAANormalText: Bool { ratio >= 7.0 }
    public var passesAAALargeText: Bool { ratio >= 4.5 }
    public var passesUIComponents: Bool { ratio >= 3.0 }

    /// The best level reached for normal text.
    public var level: Level {
        if passesAAANormalText { return .aaa }
        if passesAANormalText { return .aa }
        if passesAALargeText { return .aaLarge }
        return .fail
    }

    public enum Level: String, Sendable {
        case aaa = "AAA"
        case aa = "AA"
        case aaLarge = "AA Large"
        case fail = "Fail"
    }

    /// "4.5:1"-style text.
    public var ratioText: String { String(format: "%.2f:1", ratio) }
}

// MARK: - Helpers

nonisolated extension Double {
    /// This 0...1 channel as a 0...255 byte.
    public var byte: Int { Int((ColorMath.clamp(self) * 255).rounded()) }
}
