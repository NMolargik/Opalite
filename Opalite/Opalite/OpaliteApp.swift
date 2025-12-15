import SwiftUI
import SwiftData

@main
@MainActor
struct OpaliteApp: App {
    let sharedModelContainer: ModelContainer
    let colorManager: ColorManager

    init() {
        let schema = Schema([
            OpaliteColor.self,
            OpalitePalette.self,
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
            fatalError("[Opalite] Failed to initialize ModelContainer: \(error)")
        }

        colorManager = ColorManager(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
    }
}
