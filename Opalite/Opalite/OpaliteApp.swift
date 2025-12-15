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

func copyHex(for color: OpaliteColor) {
    let hex = color.hexString
    #if os(iOS) || os(visionOS)
    UIPasteboard.general.string = hex
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(hex, forType: .string)
    #else
    _ = hex // No-op for unsupported platforms
    #endif
}
