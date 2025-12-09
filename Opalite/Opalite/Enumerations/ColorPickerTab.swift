//
//  ColorPickerTab.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

enum ColorPickerTab: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case spectrum = "Spectrum"
    case sliders = "Channels"
    case codes = "Codes"
    case image = "Image"
    
    var id: String { rawValue }
    
    /// SF Symbol representing this mode. Not yet used in the UI, but ready for future enhancements.
    var symbol: Image {
        switch self {
        case .grid:
            return Image(systemName: "square.grid.2x2")
        case .spectrum:
            return Image(systemName: "lightspectrum.horizontal")
        case .sliders:
            return Image(systemName: "slider.horizontal.3")
        case .codes:
            return Image(systemName: "chevron.left.slash.chevron.right")
        case .image:
            return Image(systemName: "eyedropper.halffull")
        }
    }
}
