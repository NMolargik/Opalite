//
//  ColorBlindnessSimulator.swift
//  OpaliteCore
//
//  Color-vision-deficiency simulation (Brettel, Viénot & Mollon, 1997) in linear RGB.
//

import Foundation

nonisolated public enum ColorBlindnessSimulator {
    public static func simulate(_ color: RGBA, mode: ColorBlindnessMode) -> RGBA {
        guard mode != .off else { return color }
        let result = simulate(red: color.red, green: color.green, blue: color.blue, mode: mode)
        return RGBA(red: result.r, green: result.g, blue: result.b, alpha: color.alpha)
    }

    public static func simulate(red: Double, green: Double, blue: Double, mode: ColorBlindnessMode) -> (r: Double, g: Double, b: Double) {
        guard mode != .off else { return (red, green, blue) }

        let rLin = ColorMath.sRGBToLinear(red)
        let gLin = ColorMath.sRGBToLinear(green)
        let bLin = ColorMath.sRGBToLinear(blue)

        let rSim: Double, gSim: Double, bSim: Double
        switch mode {
        case .off:
            return (red, green, blue)
        case .protanopia:
            rSim = 0.56667 * rLin + 0.43333 * gLin
            gSim = 0.55833 * rLin + 0.44167 * gLin
            bSim = 0.24167 * gLin + 0.75833 * bLin
        case .deuteranopia:
            rSim = 0.625 * rLin + 0.375 * gLin
            gSim = 0.70 * rLin + 0.30 * gLin
            bSim = 0.30 * gLin + 0.70 * bLin
        case .tritanopia:
            rSim = 0.95 * rLin + 0.05 * gLin
            gSim = 0.43333 * gLin + 0.56667 * bLin
            bSim = 0.475 * gLin + 0.525 * bLin
        case .achromatopsia:
            let luminance = 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
            rSim = luminance
            gSim = luminance
            bSim = luminance
        }

        return (
            ColorMath.clamp(ColorMath.linearToSRGB(rSim)),
            ColorMath.clamp(ColorMath.linearToSRGB(gSim)),
            ColorMath.clamp(ColorMath.linearToSRGB(bSim))
        )
    }
}
