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

        let (r, g, b) = ColorBlindnessSimulator.simulate(
            red: red,
            green: green,
            blue: blue,
            mode: mode
        )

        return Color(red: r, green: g, blue: b, opacity: alpha)
    }
}
