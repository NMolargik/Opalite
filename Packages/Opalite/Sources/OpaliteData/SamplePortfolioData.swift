//
//  SamplePortfolioData.swift
//  OpaliteData
//
//  DEBUG-only demo content: four themed palettes, four loose colors, and three canvases,
//  inserted through the repositories so the change stream fires like a real import.
//

#if DEBUG
import Foundation
import OpaliteCore

public struct SamplePortfolioData: GenerateSampleData {
    private let colors: any ColorRepository
    private let palettes: any PaletteRepository
    private let canvases: any CanvasRepository
    private let authorship: Authorship

    public init(colors: any ColorRepository, palettes: any PaletteRepository, canvases: any CanvasRepository, authorship: Authorship = Authorship(displayName: "Sample Sam", deviceName: "Preview Device")) {
        self.colors = colors
        self.palettes = palettes
        self.canvases = canvases
        self.authorship = authorship
    }

    public func callAsFunction() throws(PersistenceError) {
        for (name, notes, tags, swatches) in Self.palettes {
            let palette = OpalitePalette(name: name, createdByDisplayName: authorship.displayName, notes: notes, tags: tags, colors: swatches.map(Self.color))
            try palettes.insert(palette, authorship: authorship)
        }
        for swatch in Self.looseColors {
            try colors.insert(Self.color(swatch), authorship: authorship)
        }
        for title in ["Sketch", "Ideas", "Storyboard"] {
            try canvases.insert(CanvasFile(title: title), deviceName: authorship.deviceName)
        }
    }

    private static func color(_ swatch: (String, Double, Double, Double)) -> OpaliteColor {
        OpaliteColor(name: swatch.0, red: swatch.1, green: swatch.2, blue: swatch.3)
    }

    static let palettes: [(String, String, [String], [(String, Double, Double, Double)])] = [
        ("Sunrise", "Warm hues inspired by a sunrise.", ["sample", "warm"], [("Dawn", 0.98, 0.77, 0.36), ("Amber", 0.95, 0.60, 0.18), ("Coral", 0.95, 0.45, 0.30)]),
        ("Ocean", "Cool blues and teals.", ["sample", "cool"], [("Deep Blue", 0.05, 0.20, 0.45), ("Sea", 0.00, 0.55, 0.65), ("Foam", 0.80, 0.95, 0.95), ("Lagoon", 0.00, 0.70, 0.55)]),
        ("Neon", "High-contrast neon accents.", ["sample", "neon"], [("Neon Pink", 1.00, 0.20, 0.65), ("Electric Blue", 0.10, 0.45, 1.00), ("Lime", 0.70, 1.00, 0.20), ("Laser", 0.95, 1.00, 0.30)]),
        ("Grayscale", "Neutral grays for UI.", ["sample", "neutral"], [("Almost Black", 0.05, 0.05, 0.06), ("Charcoal", 0.10, 0.10, 0.11), ("Graphite", 0.16, 0.17, 0.19), ("Slate", 0.20, 0.22, 0.25), ("Steel", 0.40, 0.43, 0.47), ("Pewter", 0.52, 0.54, 0.57), ("Ash", 0.58, 0.59, 0.61), ("Smoke", 0.66, 0.67, 0.69), ("Silver", 0.70, 0.73, 0.76), ("Cloud", 0.82, 0.84, 0.86), ("Platinum", 0.90, 0.91, 0.92), ("Off White", 0.93, 0.94, 0.95), ("Snow", 0.97, 0.98, 0.99)]),
    ]

    static let looseColors: [(String, Double, Double, Double)] = [
        ("Moss", 0.35, 0.55, 0.30), ("Pine", 0.10, 0.35, 0.20), ("Bark", 0.45, 0.30, 0.20), ("Fern", 0.30, 0.70, 0.35),
    ]
}
#endif
