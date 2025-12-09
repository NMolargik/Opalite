//
//  OpaliteApp.swift
//  Opalite
//
//  Created by Nick Molargik on 12/6/25.
//

import SwiftUI
import SwiftData

@main
struct OpaliteApp: App {
    private let colorManager: ColorManager
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            OpaliteColor.self, OpalitePalette.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        let cloudKitContainerID = "iCloud.com.molargiksoftware.Opalite"

        do {
            let config = ModelConfiguration(
                cloudKitDatabase: .private(cloudKitContainerID)
            )

            sharedModelContainer = try ModelContainer(
                for: OpaliteColor.self, OpalitePalette.self,
                configurations: config
            )
        } catch {
            fatalError("[Opalite] Failed to initialize ModelContainer: \(error)")
        }
        
        colorManager = ColorManager(context: sharedModelContainer.mainContext)
    }
    
    // MARK: Entrypoint

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
    }
}
