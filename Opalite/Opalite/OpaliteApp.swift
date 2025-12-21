import SwiftUI
import SwiftData

@main
@MainActor
struct OpaliteApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    
    @AppStorage("userName") private var userName: String = "User"
    @AppStorage("appTheme") private var appThemeRaw: String = AppThemeOption.system.rawValue

    private var preferredColorScheme: ColorScheme? {
        let option = AppThemeOption(rawValue: appThemeRaw) ?? .system
        switch option {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    let sharedModelContainer: ModelContainer
    let colorManager: ColorManager
    let canvasManager: CanvasManager

    init() {
        let schema = Schema([
            OpaliteColor.self,
            OpalitePalette.self,
            CanvasFile.self,
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
        canvasManager = CanvasManager(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    Task { @MainActor in
                        await colorManager.refreshAll()
                        await canvasManager.refreshAll()
                    }

                    #if os(iOS)
                    // Handle pending quick action when app becomes active
                    if newPhase == .active, let shortcutType = AppDelegate.pendingShortcutType {
                        AppDelegate.pendingShortcutType = nil
                        if shortcutType == "OpenSwatchBarAction" {
                            if !colorManager.isSwatchBarOpen {
                                openWindow(id: "swatchBar")
                            }
                        }
                    }
                    #endif
                }
                .onChange(of: userName) { _, newName in
                    colorManager.author = userName
                }
                .preferredColorScheme(preferredColorScheme)
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)

#if os(macOS)
        Window("SwatchBar", id: "swatchBar") {
            SwatchBarView()
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 56, height: 400)
#elseif os(iOS)
        WindowGroup(id: "swatchBar") {
            SwatchBarView()
                .onAppear {
                    colorManager.isSwatchBarOpen = true
                }
                .onDisappear {
                    colorManager.isSwatchBarOpen = false
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 56, height: 400)
#endif
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
