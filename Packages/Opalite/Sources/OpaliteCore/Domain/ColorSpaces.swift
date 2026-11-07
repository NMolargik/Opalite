//
//  ColorSpaces.swift
//  OpaliteCore
//
//  Perceptual and wide-gamut color math: sRGB ↔ OKLab/OKLCH (Björn Ottosson's 2020 matrices)
//  and sRGB ↔ Display P3. All values are unclamped so out-of-gamut colors stay detectable.
//

import Foundation

/// OKLab: lightness 0...1 plus the a (green–red) and b (blue–yellow) axes.
nonisolated public struct OKLab: Hashable, Sendable {
    public var lightness: Double
    public var a: Double
    public var b: Double

    public init(lightness: Double, a: Double, b: Double) {
        self.lightness = lightness
        self.a = a
        self.b = b
    }

    public var oklch: OKLCH { ColorSpaces.oklch(from: self) }
    /// Unclamped sRGB components (may fall outside 0...1).
    public var extendedSRGB: RGBA { ColorSpaces.srgb(from: self) }
}

/// OKLCH: lightness 0...1, chroma (≈0...0.4), hue in degrees 0..<360.
nonisolated public struct OKLCH: Hashable, Sendable {
    public var lightness: Double
    public var chroma: Double
    public var hue: Double

    public init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    public var oklab: OKLab { ColorSpaces.oklab(from: self) }
    /// Unclamped sRGB components (may fall outside 0...1).
    public var extendedSRGB: RGBA { ColorSpaces.srgb(from: oklab) }
    /// Whether this color is displayable in sRGB.
    public var isInSRGBGamut: Bool { extendedSRGB.isInSRGBGamut }
    /// The sRGB color with chroma reduced (hue and lightness kept) until it fits the gamut.
    public var gamutMappedRGBA: RGBA { ColorSpaces.gamutMapped(self) }
}

/// Display P3 with the sRGB transfer curve, components nominally 0...1.
nonisolated public struct DisplayP3: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var isInGamut: Bool { ColorSpaces.inUnit(red) && ColorSpaces.inUnit(green) && ColorSpaces.inUnit(blue) }
    /// Unclamped sRGB components.
    public var extendedSRGB: RGBA { ColorSpaces.srgb(from: self) }
}

nonisolated public enum ColorSpaces {
    static let epsilon = 1e-4

    static func inUnit(_ v: Double) -> Bool { v >= -epsilon && v <= 1 + epsilon }

    // MARK: OKLab

    public static func oklab(from rgba: RGBA) -> OKLab {
        let r = ColorMath.sRGBToLinearExtended(rgba.red)
        let g = ColorMath.sRGBToLinearExtended(rgba.green)
        let b = ColorMath.sRGBToLinearExtended(rgba.blue)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return OKLab(
            lightness: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    public static func srgb(from lab: OKLab) -> RGBA {
        let l = pow3(lab.lightness + 0.3963377774 * lab.a + 0.2158037573 * lab.b)
        let m = pow3(lab.lightness - 0.1055613458 * lab.a - 0.0638541728 * lab.b)
        let s = pow3(lab.lightness - 0.0894841775 * lab.a - 1.2914855480 * lab.b)
        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        return RGBA(
            red: ColorMath.linearToSRGBExtended(r),
            green: ColorMath.linearToSRGBExtended(g),
            blue: ColorMath.linearToSRGBExtended(b)
        )
    }

    public static func oklch(from lab: OKLab) -> OKLCH {
        let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        var hue = atan2(lab.b, lab.a) * 180 / .pi
        if hue < 0 { hue += 360 }
        // Achromatic colors have no meaningful hue.
        if chroma < 1e-6 { hue = 0 }
        return OKLCH(lightness: lab.lightness, chroma: chroma, hue: hue)
    }

    public static func oklab(from lch: OKLCH) -> OKLab {
        let radians = lch.hue * .pi / 180
        return OKLab(lightness: lch.lightness, a: lch.chroma * cos(radians), b: lch.chroma * sin(radians))
    }

    /// Reduces chroma by bisection until the color fits sRGB; lightness and hue are preserved.
    public static func gamutMapped(_ lch: OKLCH) -> RGBA {
        let clampedL = ColorMath.clamp(lch.lightness)
        if clampedL <= 0 { return .black }
        if clampedL >= 1 { return .white }
        var candidate = OKLCH(lightness: clampedL, chroma: max(0, lch.chroma), hue: lch.hue)
        if candidate.isInSRGBGamut { return clip(candidate.extendedSRGB) }
        var low = 0.0, high = candidate.chroma
        for _ in 0..<24 {
            let mid = (low + high) / 2
            candidate.chroma = mid
            if candidate.isInSRGBGamut { low = mid } else { high = mid }
        }
        candidate.chroma = low
        return clip(candidate.extendedSRGB)
    }

    static func clip(_ rgba: RGBA) -> RGBA {
        RGBA(red: ColorMath.clamp(rgba.red), green: ColorMath.clamp(rgba.green), blue: ColorMath.clamp(rgba.blue), alpha: rgba.alpha)
    }

    private static func pow3(_ x: Double) -> Double { x * x * x }

    // MARK: Display P3

    public static func displayP3(from rgba: RGBA) -> DisplayP3 {
        let r = ColorMath.sRGBToLinearExtended(rgba.red)
        let g = ColorMath.sRGBToLinearExtended(rgba.green)
        let b = ColorMath.sRGBToLinearExtended(rgba.blue)
        let x = 0.4123907993 * r + 0.3575843394 * g + 0.1804807884 * b
        let y = 0.2126390059 * r + 0.7151686788 * g + 0.0721923154 * b
        let z = 0.0193308187 * r + 0.1191947798 * g + 0.9505321522 * b
        return DisplayP3(
            red: ColorMath.linearToSRGBExtended(2.4934969119 * x - 0.9313836179 * y - 0.4027107845 * z),
            green: ColorMath.linearToSRGBExtended(-0.8294889696 * x + 1.7626640603 * y + 0.0236246858 * z),
            blue: ColorMath.linearToSRGBExtended(0.0358458302 * x - 0.0761723893 * y + 0.9568845240 * z)
        )
    }

    public static func srgb(from p3: DisplayP3) -> RGBA {
        let r = ColorMath.sRGBToLinearExtended(p3.red)
        let g = ColorMath.sRGBToLinearExtended(p3.green)
        let b = ColorMath.sRGBToLinearExtended(p3.blue)
        let x = 0.4865709486 * r + 0.2656676932 * g + 0.1982172852 * b
        let y = 0.2289745641 * r + 0.6917385218 * g + 0.0792869141 * b
        let z = 0.0000000000 * r + 0.0451133819 * g + 1.0439443689 * b
        return RGBA(
            red: ColorMath.linearToSRGBExtended(3.2409699419 * x - 1.5373831776 * y - 0.4986107603 * z),
            green: ColorMath.linearToSRGBExtended(-0.9692436363 * x + 1.8759675015 * y + 0.0415550574 * z),
            blue: ColorMath.linearToSRGBExtended(0.0556300797 * x - 0.2039769589 * y + 1.0569715142 * z)
        )
    }
}

// MARK: - RGBA conveniences

nonisolated extension RGBA {
    public var oklab: OKLab { ColorSpaces.oklab(from: self) }
    public var oklch: OKLCH { oklab.oklch }
    public var displayP3: DisplayP3 { ColorSpaces.displayP3(from: self) }

    /// False when any channel lies outside 0...1 (an extended-range / wide-gamut sample).
    public var isInSRGBGamut: Bool {
        ColorSpaces.inUnit(red) && ColorSpaces.inUnit(green) && ColorSpaces.inUnit(blue)
    }

    /// "oklch(62.8% 0.258 29.23)" — CSS Color 4.
    public var oklchString: String {
        let lch = oklch
        let alphaPart = alpha < 1 ? " / \(ColorMath.trimmed(alpha))" : ""
        return "oklch(\(String(format: "%.1f", lch.lightness * 100))% \(String(format: "%.3f", lch.chroma)) \(String(format: "%.2f", lch.hue))\(alphaPart))"
    }

    /// "color(display-p3 0.9175 0.2003 0.1386)" — CSS Color 4.
    public var displayP3String: String {
        let p3 = displayP3
        let alphaPart = alpha < 1 ? " / \(ColorMath.trimmed(alpha))" : ""
        return "color(display-p3 \(String(format: "%.4f", p3.red)) \(String(format: "%.4f", p3.green)) \(String(format: "%.4f", p3.blue))\(alphaPart))"
    }
}

nonisolated extension ColorMath {
    /// sRGB → linear preserving sign, so out-of-range values round-trip.
    public static func sRGBToLinearExtended(_ value: Double) -> Double {
        let magnitude = abs(value)
        let linear = magnitude <= 0.04045 ? magnitude / 12.92 : pow((magnitude + 0.055) / 1.055, 2.4)
        return value < 0 ? -linear : linear
    }

    public static func linearToSRGBExtended(_ value: Double) -> Double {
        let magnitude = abs(value)
        let encoded = magnitude <= 0.0031308 ? magnitude * 12.92 : 1.055 * pow(magnitude, 1 / 2.4) - 0.055
        return value < 0 ? -encoded : encoded
    }
}
