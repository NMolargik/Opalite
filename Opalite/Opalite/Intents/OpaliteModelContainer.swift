//
//  OpaliteModelContainer.swift
//  Opalite
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftData

/// Shared ModelContainer for App Intents to access SwiftData models.
/// Uses the same CloudKit configuration as the main app.
enum OpaliteModelContainer {
    @MainActor
    static let shared: ModelContainer = {
        let schema = Schema([
            OpaliteColor.self,
            OpalitePalette.self,
            CanvasFile.self
        ])

        let cloudKitContainerID = "iCloud.com.molargiksoftware.Opalite"
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("[OpaliteModelContainer] Failed to initialize shared ModelContainer: \(error)")
        }
    }()
}
