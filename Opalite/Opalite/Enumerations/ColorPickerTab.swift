//
//  ColorPickerTab.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI

enum ColorPickerTab: String, CaseIterable, Identifiable {
    case spectrum = "Spectrum"
    case grid = "Grid"
    case shuffle = "Shuffle"
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
        case .shuffle:
            return Image(systemName: "shuffle")
        case .sliders:
            return Image(systemName: "slider.horizontal.3")
        case .codes:
            return Image(systemName: "number")
        case .image:
            return Image(systemName: "eyedropper.halffull")
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .grid:
            return "Color grid"
        case .spectrum:
            return "Color spectrum"
        case .shuffle:
            return "Shuffle color"
        case .sliders:
            return "Channel sliders"
        case .codes:
            return "Color codes"
        case .image:
            return "Sample from image"
        }
    }

    /// Keyboard shortcut key (1-6) for switching modes on iPad/Mac
    var keyboardShortcutKey: Character {
        switch self {
        case .spectrum: return "1"
        case .grid: return "2"
        case .shuffle: return "3"
        case .sliders: return "4"
        case .codes: return "5"
        case .image: return "6"
        }
    }

    /// Initialize from a keyboard character (1-6), derived from `keyboardShortcutKey`.
    init?(fromKey key: Character) {
        guard let match = Self.allCases.first(where: { $0.keyboardShortcutKey == key }) else {
            return nil
        }
        self = match
    }
}
