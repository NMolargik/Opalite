//
//  ColorBlindnessSimulator.swift
//  Opalite
//
//  Shared color-vision-deficiency math used by both OpaliteColor and CommunityColor.
//

import Foundation

enum ColorBlindnessSimulator {

    /// Applies a color blindness transformation matrix to the given sRGB components.
    ///
    /// Based on Brettel, Vienot, and Mollon (1997) simulation algorithms.
    ///
    /// - Parameters:
    ///   - red: sRGB red component (0-1)
    ///   - green: sRGB green component (0-1)
    ///   - blue: sRGB blue component (0-1)
    ///   - mode: The color blindness type to simulate
    /// - Returns: Transformed sRGB components clamped to [0, 1]
    static func simulate(
        red: Double,
        green: Double,
        blue: Double,
        mode: ColorBlindnessMode
    ) -> (r: Double, g: Double, b: Double) {
        guard mode != .off else { return (red, green, blue) }

        // Convert sRGB to linear RGB for accurate transforms
        let rLin = sRGBToLinear(red)
        let gLin = sRGBToLinear(green)
        let bLin = sRGBToLinear(blue)

        let (rSim, gSim, bSim): (Double, Double, Double)

        switch mode {
        case .off:
            return (red, green, blue)

        case .protanopia:
            rSim = 0.56667 * rLin + 0.43333 * gLin + 0.0 * bLin
            gSim = 0.55833 * rLin + 0.44167 * gLin + 0.0 * bLin
            bSim = 0.0 * rLin + 0.24167 * gLin + 0.75833 * bLin

        case .deuteranopia:
            rSim = 0.625 * rLin + 0.375 * gLin + 0.0 * bLin
            gSim = 0.70 * rLin + 0.30 * gLin + 0.0 * bLin
            bSim = 0.0 * rLin + 0.30 * gLin + 0.70 * bLin

        case .tritanopia:
            rSim = 0.95 * rLin + 0.05 * gLin + 0.0 * bLin
            gSim = 0.0 * rLin + 0.43333 * gLin + 0.56667 * bLin
            bSim = 0.0 * rLin + 0.475 * gLin + 0.525 * bLin

        case .achromatopsia:
            let luminance = 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
            rSim = luminance
            gSim = luminance
            bSim = luminance
        }

        return (
            r: clamp(linearToSRGB(rSim)),
            g: clamp(linearToSRGB(gSim)),
            b: clamp(linearToSRGB(bSim))
        )
    }

    // MARK: - Color Space Conversion

    /// Converts an sRGB component to linear RGB.
    static func sRGBToLinear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    /// Converts a linear RGB component to sRGB.
    static func linearToSRGB(_ value: Double) -> Double {
        value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1.0 / 2.4) - 0.055
    }

    /// Clamps a value to the valid color range [0, 1].
    static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}
