//
//  OpaliteShortcuts.swift
//  Opalite
//
//  Created by Nick Molargik on 1/18/26.
//

import AppIntents

/// Registers Siri phrases for Opalite's App Intents.
/// These phrases appear in the Shortcuts app and can be triggered by voice.
struct OpaliteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowColorIntent(),
            phrases: [
                "Show \(\.$color) in \(.applicationName)",
                "Show me \(\.$color) in \(.applicationName)",
                "Open \(\.$color) in \(.applicationName)",
                "Find \(\.$color) in \(.applicationName)",
                "Show the color \(\.$color) in \(.applicationName)",
                "Open the color \(\.$color) in \(.applicationName)"
            ],
            shortTitle: "Show Color",
            systemImageName: "paintpalette"
        )

        AppShortcut(
            intent: ShowPaletteIntent(),
            phrases: [
                "Show \(\.$palette) in \(.applicationName)",
                "Show me \(\.$palette) in \(.applicationName)",
                "Open \(\.$palette) in \(.applicationName)",
                "Find \(\.$palette) in \(.applicationName)",
                "Show the palette \(\.$palette) in \(.applicationName)",
                "Open the palette \(\.$palette) in \(.applicationName)"
            ],
            shortTitle: "Show Palette",
            systemImageName: "swatchpalette"
        )
    }
}
