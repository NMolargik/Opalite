//
//  CommunityColor+ColorBlindness.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

extension CommunityColor {
    /// Returns a SwiftUI Color with color blindness simulation applied.
    ///
    /// - Parameter mode: The color blindness type to simulate
    /// - Returns: A Color with transformed RGB values for display
    func simulatedSwiftUIColor(_ mode: ColorBlindnessMode) -> Color {
        guard mode != .off else { return swiftUIColor }

        let (r, g, b) = applyColorBlindnessMatrix(
            red: red,
            green: green,
            blue: blue,
            mode: mode
        )

        return Color(red: r, green: g, blue: b, opacity: alpha)
    }

    /// Applies the appropriate color blindness transformation matrix.
    private func applyColorBlindnessMatrix(
        red: Double,
        green: Double,
        blue: Double,
        mode: ColorBlindnessMode
    ) -> (r: Double, g: Double, b: Double) {
        // Convert sRGB to linear RGB for accurate transforms
        let rLin = sRGBToLinear(red)
        let gLin = sRGBToLinear(green)
        let bLin = sRGBToLinear(blue)

        let (rSim, gSim, bSim): (Double, Double, Double)

        switch mode {
        case .off:
            return (red, green, blue)

        case .protanopia:
            // Protanopia simulation matrix (red-blind)
            rSim = 0.56667 * rLin + 0.43333 * gLin + 0.0 * bLin
            gSim = 0.55833 * rLin + 0.44167 * gLin + 0.0 * bLin
            bSim = 0.0 * rLin + 0.24167 * gLin + 0.75833 * bLin

        case .deuteranopia:
            // Deuteranopia simulation matrix (green-blind)
            rSim = 0.625 * rLin + 0.375 * gLin + 0.0 * bLin
            gSim = 0.70 * rLin + 0.30 * gLin + 0.0 * bLin
            bSim = 0.0 * rLin + 0.30 * gLin + 0.70 * bLin

        case .tritanopia:
            // Tritanopia simulation matrix (blue-blind)
            rSim = 0.95 * rLin + 0.05 * gLin + 0.0 * bLin
            gSim = 0.0 * rLin + 0.43333 * gLin + 0.56667 * bLin
            bSim = 0.0 * rLin + 0.475 * gLin + 0.525 * bLin

        case .achromatopsia:
            // Achromatopsia (monochromacy) - complete color blindness
            let luminance = 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
            rSim = luminance
            gSim = luminance
            bSim = luminance
        }

        // Convert back to sRGB and clamp to valid range
        return (
            r: clamp(linearToSRGB(rSim)),
            g: clamp(linearToSRGB(gSim)),
            b: clamp(linearToSRGB(bSim))
        )
    }

    /// Converts sRGB component to linear RGB.
    private func sRGBToLinear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    /// Converts linear RGB component to sRGB.
    private func linearToSRGB(_ value: Double) -> Double {
        value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1.0 / 2.4) - 0.055
    }

    /// Clamps value to valid color range [0, 1].
    private func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}
