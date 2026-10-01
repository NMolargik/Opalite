//
//  OpaliteColor+ColorBlindness.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import Foundation

extension OpaliteColor {
    /// Returns a new OpaliteColor with color blindness simulation applied.
    ///
    /// Uses standard color vision deficiency simulation matrices based on
    /// Brettel, Vienot, and Mollon (1997) research.
    ///
    /// - Parameter mode: The color blindness type to simulate
    /// - Returns: A new OpaliteColor with transformed RGB values for display
    func simulatingColorBlindness(_ mode: ColorBlindnessMode) -> OpaliteColor {
        guard mode != .off else { return self }

        let (r, g, b) = ColorBlindnessSimulator.simulate(
            red: red,
            green: green,
            blue: blue,
            mode: mode
        )

        return OpaliteColor(
            id: id,
            name: name,
            notes: notes,
            createdByDisplayName: createdByDisplayName,
            createdOnDeviceName: createdOnDeviceName,
            updatedOnDeviceName: updatedOnDeviceName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            red: r,
            green: g,
            blue: b,
            alpha: alpha,
            palette: nil // Don't preserve relationship for simulated colors
        )
    }
}

// MARK: - Array Extension

extension Array where Element == OpaliteColor {
    /// Applies color blindness simulation to all colors in the array.
    ///
    /// - Parameter mode: The color blindness type to simulate
    /// - Returns: Array of colors with simulation applied
    func simulatingColorBlindness(_ mode: ColorBlindnessMode) -> [OpaliteColor] {
        guard mode != .off else { return self }
        return map { $0.simulatingColorBlindness(mode) }
    }
}
