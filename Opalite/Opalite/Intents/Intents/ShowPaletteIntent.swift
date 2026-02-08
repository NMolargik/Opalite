//
//  ShowPaletteIntent.swift
//  Opalite
//
//  Created by Nick Molargik on 1/18/26.
//

import AppIntents

/// App Intent that opens a specific palette in Opalite.
/// Triggered by Siri phrases like "Show me my [palette name] in Opalite"
struct ShowPaletteIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Palette"
    static var description = IntentDescription("Opens a specific palette in Opalite")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Palette")
    var palette: OpalitePaletteEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentNavigationManager.shared.navigateToPalette(id: palette.id)
        return .result()
    }
}
