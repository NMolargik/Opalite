//
//  ShowColorIntent.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//

import AppIntents
import SwiftData

/// App Intent that opens a specific color in Opalite.
/// Triggered by Siri phrases like "Show me my [color name] in Opalite"
struct ShowColorIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Color"
    static var description = IntentDescription("Opens a specific color in Opalite")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Color")
    var color: OpaliteColorEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentNavigationManager.shared.navigateToColor(id: color.id)
        return .result()
    }
}
