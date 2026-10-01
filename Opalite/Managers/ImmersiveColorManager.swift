//
//  ImmersiveColorManager.swift
//  Opalite
//
//  Created by Nick Molargik on 2/12/26.
//

import SwiftUI

/// Holds the color data that the visionOS ImmersiveSpace reads when opened.
/// Cross-platform (no RealityKit dependency). Set colors before calling openImmersiveSpace.
@Observable
final class ImmersiveColorManager {

    /// The mode determines sphere layout in the immersive view.
    enum Mode {
        /// Single hero color + harmony orbs
        case singleColor
        /// Palette colors arranged in an arc
        case palette
    }

    /// The colors to render. For singleColor mode, index 0 is the hero;
    /// indices 1...6 are harmonies. For palette mode, all colors are equal.
    var colors: [ImmersiveColorData] = []

    /// Current display mode.
    var mode: Mode = .singleColor

    /// Whether the immersive space is currently open.
    var isImmersed: Bool = false

    /// Prepares for single-color immersion: hero + 6 harmony orbs.
    func prepareForSingleColor(_ color: OpaliteColor) {
        mode = .singleColor

        var data: [ImmersiveColorData] = []

        // Hero
        data.append(ImmersiveColorData(red: color.red, green: color.green, blue: color.blue))

        // Complementary
        let comp = color.complementaryColor()
        data.append(ImmersiveColorData(red: comp.red, green: comp.green, blue: comp.blue))

        // Analogous (2)
        for c in color.analogousColors() {
            data.append(ImmersiveColorData(red: c.red, green: c.green, blue: c.blue))
        }

        // Split-Complementary (2)
        for c in color.splitComplementaryColors() {
            data.append(ImmersiveColorData(red: c.red, green: c.green, blue: c.blue))
        }

        // Triadic (first of pair)
        if let first = color.triadicColors().first {
            data.append(ImmersiveColorData(red: first.red, green: first.green, blue: first.blue))
        }

        colors = data
    }

    /// Prepares for palette immersion: all colors as equal spheres.
    func prepareForPalette(_ paletteColors: [OpaliteColor]) {
        mode = .palette
        colors = paletteColors.map {
            ImmersiveColorData(red: $0.red, green: $0.green, blue: $0.blue)
        }
    }
}

/// Lightweight value-type copy of color components for the immersive scene.
/// Avoids SwiftData context issues across scenes.
struct ImmersiveColorData: Identifiable, Equatable {
    let id = UUID()
    let red: Double
    let green: Double
    let blue: Double

    static func == (lhs: ImmersiveColorData, rhs: ImmersiveColorData) -> Bool {
        lhs.id == rhs.id
    }
}
