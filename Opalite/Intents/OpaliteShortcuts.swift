//
//  OpaliteShortcuts.swift
//  Opalite
//
//  Registers App Shortcuts so the custom intents are discoverable in Spotlight, Siri,
//  and the Shortcuts app without any user setup. Phrases are localized in
//  AppShortcuts.xcstrings.
//

import AppIntents

struct OpaliteShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowColorIntent(),
            phrases: [
                "Show \(\.$color) in \(.applicationName)",
                "Open \(\.$color) in \(.applicationName)",
                "Show the color \(\.$color) in \(.applicationName)",
            ],
            shortTitle: "Show Color",
            systemImageName: "paintpalette"
        )
        AppShortcut(
            intent: ShowPaletteIntent(),
            phrases: [
                "Show \(\.$palette) in \(.applicationName)",
                "Open \(\.$palette) in \(.applicationName)",
                "Show the palette \(\.$palette) in \(.applicationName)",
            ],
            shortTitle: "Show Palette",
            systemImageName: "swatchpalette"
        )
        AppShortcut(
            intent: CreateColorIntent(),
            phrases: [
                "Create a color in \(.applicationName)",
                "Save a hex code in \(.applicationName)",
            ],
            shortTitle: "Create Color",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CopyColorHexIntent(),
            phrases: [
                "Copy \(\.$color) from \(.applicationName)",
                "What is the hex code of \(\.$color) in \(.applicationName)",
            ],
            shortTitle: "Copy Hex",
            systemImageName: "number"
        )
        AppShortcut(
            intent: RandomColorIntent(),
            phrases: [
                "Random color from \(.applicationName)",
                "Surprise me with a color from \(.applicationName)",
            ],
            shortTitle: "Random Color",
            systemImageName: "shuffle"
        )
        AppShortcut(
            intent: PortfolioSummaryIntent(),
            phrases: [
                "How many colors do I have in \(.applicationName)",
                "My \(.applicationName) portfolio summary",
            ],
            shortTitle: "Portfolio Summary",
            systemImageName: "chart.bar"
        )
    }
}
