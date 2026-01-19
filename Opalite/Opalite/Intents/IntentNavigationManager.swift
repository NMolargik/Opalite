//
//  IntentNavigationManager.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//

import SwiftUI

/// Coordinates navigation from App Intents to the UI.
/// Intents write pending navigation targets here, and views observe for changes.
@MainActor
@Observable
final class IntentNavigationManager {
    static let shared = IntentNavigationManager()

    /// Pending color to navigate to (set by ShowColorIntent)
    var pendingColorID: UUID?

    /// Pending palette to navigate to (set by ShowPaletteIntent)
    var pendingPaletteID: UUID?

    /// Trigger to show the color editor for creating a new color (set by deep link)
    var shouldShowColorEditor: Bool = false

    private init() {}

    func navigateToColor(id: UUID) {
        pendingColorID = id
    }

    func navigateToPalette(id: UUID) {
        pendingPaletteID = id
    }

    /// Triggers the color editor to create a new color
    func showColorEditor() {
        shouldShowColorEditor = true
    }

    func clearNavigation() {
        pendingColorID = nil
        pendingPaletteID = nil
        shouldShowColorEditor = false
    }
}
