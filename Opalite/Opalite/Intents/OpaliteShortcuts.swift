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
                "Show me my \(\.$color) in \(.applicationName)",
                "Open \(\.$color) in \(.applicationName)",
                "Show \(\.$color) color in \(.applicationName)"
            ],
            shortTitle: "Show Color",
            systemImageName: "paintpalette"
        )

        AppShortcut(
            intent: ShowPaletteIntent(),
            phrases: [
                "Show me my \(\.$palette) in \(.applicationName)",
                "Open \(\.$palette) in \(.applicationName)",
                "Show \(\.$palette) palette in \(.applicationName)"
            ],
            shortTitle: "Show Palette",
            systemImageName: "swatchpalette"
        )
    }
}
