//
//  ColorPickerTab.swift
//  OpaliteCore
//
//  The six color-picking modes of the editor and their keyboard shortcuts.
//

import Foundation

nonisolated public enum ColorPickerTab: String, CaseIterable, Identifiable, Sendable {
    case spectrum
    case grid
    case shuffle
    case sliders
    case codes
    case image

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .spectrum: "lightspectrum.horizontal"
        case .shuffle: "shuffle"
        case .sliders: "slider.horizontal.3"
        case .codes: "number"
        case .image: "eyedropper.halffull"
        }
    }

    /// Keyboard shortcut key (1–6) for switching modes on iPad/Mac.
    public var keyboardShortcutKey: Character {
        switch self {
        case .spectrum: "1"
        case .grid: "2"
        case .shuffle: "3"
        case .sliders: "4"
        case .codes: "5"
        case .image: "6"
        }
    }

    public init?(fromKey key: Character) {
        guard let match = Self.allCases.first(where: { $0.keyboardShortcutKey == key }) else { return nil }
        self = match
    }
}
