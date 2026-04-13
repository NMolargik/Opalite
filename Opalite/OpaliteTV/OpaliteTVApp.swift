//
//  OpaliteTVApp.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI
import SwiftData
import CoreData

@main
@MainActor
struct OpaliteTVApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer
    let colorManager: ColorManager
    let toastManager = ToastManager()
    let hexCopyManager = HexCopyManager()

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
            fatalError("[OpaliteTV] Failed to initialize ModelContainer: \(error)")
        }

        colorManager = ColorManager(context: sharedModelContainer.mainContext)

        // Listen for remote CloudKit changes so the in-memory cache stays current
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [colorManager] _ in
            Task { @MainActor in
                await colorManager.refreshAll()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            TVContentView()
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { @MainActor in
                            await colorManager.refreshAll()
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(toastManager)
        .environment(hexCopyManager)
    }
}
