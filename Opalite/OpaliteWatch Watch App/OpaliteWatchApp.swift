//
//  OpaliteWatchApp.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI
import SwiftData

@main
struct OpaliteWatchApp: App {
    let sharedModelContainer: ModelContainer
    let colorManager: WatchColorManager

    init() {
        let schema = Schema([
            OpaliteColor.self,
            OpalitePalette.self
        ])

        let cloudKitContainerID = "iCloud.com.molargiksoftware.Opalite"
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(cloudKitContainerID)
        )

        do {
            sharedModelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("[OpaliteWatch] Failed to initialize ModelContainer: \(error)")
        }

        colorManager = WatchColorManager(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await colorManager.refreshAll()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
    }
}
