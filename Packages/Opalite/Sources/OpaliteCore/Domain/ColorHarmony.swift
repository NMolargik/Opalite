//
//  ColorHarmony.swift
//  OpaliteCore
//
//  Color-wheel relationships (complementary, analogous, triadic, tetradic, split) and
//  tint/shade/tone ladders — all over `RGBA`, so the rules are host-tested.
//

import Foundation

nonisolated public enum ColorHarmony {
    /// A copy rotated `degrees` around the hue wheel (saturation/lightness preserved).
    public static func rotated(_ color: RGBA, by degrees: Double) -> RGBA {
        var hsl = color.hsl
        hsl.hue = (hsl.hue + degrees).truncatingRemainder(dividingBy: 360)
        if hsl.hue < 0 { hsl.hue += 360 }
        var result = hsl.rgba
        result.alpha = color.alpha
        return result
    }

    public static func complementary(of color: RGBA) -> RGBA { rotated(color, by: 180) }
    public static func analogous(of color: RGBA) -> [RGBA] { [rotated(color, by: -30), rotated(color, by: 30)] }
    public static func triadic(of color: RGBA) -> [RGBA] { [rotated(color, by: 120), rotated(color, by: 240)] }
    public static func tetradic(of color: RGBA) -> [RGBA] { [rotated(color, by: 90), rotated(color, by: 180), rotated(color, by: 270)] }
    public static func splitComplementary(of color: RGBA) -> [RGBA] { [rotated(color, by: 150), rotated(color, by: 210)] }

    /// Lighter steps toward white (excludes the base color).
    public static func tints(of color: RGBA, count: Int = 5) -> [RGBA] {
        guard count > 0 else { return [] }
        return (1...count).map { step in
            let t = Double(step) / Double(count + 1)
            return mix(color, .white, t)
        }
    }

    /// Darker steps toward black (excludes the base color).
    public static func shades(of color: RGBA, count: Int = 5) -> [RGBA] {
        guard count > 0 else { return [] }
        return (1...count).map { step in
            let t = Double(step) / Double(count + 1)
            return mix(color, .black, t)
        }
    }

    /// Desaturated steps toward mid-gray (excludes the base color).
    public static func tones(of color: RGBA, count: Int = 5) -> [RGBA] {
        guard count > 0 else { return [] }
        let gray = RGBA(red: 0.5, green: 0.5, blue: 0.5)
        return (1...count).map { step in
            let t = Double(step) / Double(count + 1)
            return mix(color, gray, t)
        }
    }

    /// Linear interpolation in sRGB; `t` = 0 returns `a`, 1 returns `b`.
    public static func mix(_ a: RGBA, _ b: RGBA, _ t: Double) -> RGBA {
        let t = ColorMath.clamp(t)
        return RGBA(
            red: a.red + (b.red - a.red) * t,
            green: a.green + (b.green - a.green) * t,
            blue: a.blue + (b.blue - a.blue) * t,
            alpha: a.alpha
        )
    }
}
