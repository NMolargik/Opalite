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
    let toastManager = ToastManager()
    let importCoordinator = ImportCoordinator()

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
        WindowGroup(id: "main") {
            ContentView()
                .toastContainer()
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
                .onOpenURL { url in
                    importCoordinator.handleIncomingURL(url, colorManager: colorManager)
                }
                .sheet(isPresented: Binding(
                    get: { importCoordinator.isShowingColorImport },
                    set: { importCoordinator.isShowingColorImport = $0 }
                )) {
                    if let preview = importCoordinator.pendingColorImport {
                        ColorImportConfirmationSheet(preview: preview) {
                            Task { await colorManager.refreshAll() }
                        }
                        .environment(colorManager)
                    }
                }
                .sheet(isPresented: Binding(
                    get: { importCoordinator.isShowingPaletteImport },
                    set: { importCoordinator.isShowingPaletteImport = $0 }
                )) {
                    if let preview = importCoordinator.pendingPaletteImport {
                        PaletteImportConfirmationSheet(preview: preview) {
                            Task { await colorManager.refreshAll() }
                        }
                        .environment(colorManager)
                    }
                }
                .alert("Import Error", isPresented: Binding(
                    get: { importCoordinator.showingImportError },
                    set: { importCoordinator.showingImportError = $0 }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(importCoordinator.importError?.errorDescription ?? "An unknown error occurred.")
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(toastManager)
        .environment(importCoordinator)

#if os(macOS)
        Window("SwatchBar", id: "swatchBar") {
            SwatchBarView()
                .toastContainer()
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(toastManager)
        .windowResizability(.contentSize)
        .defaultSize(width: 232, height: 500)
#elseif os(iOS)
        WindowGroup(id: "swatchBar") {
            SwatchBarView()
                .toastContainer()
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
        .environment(toastManager)
        .windowResizability(.contentSize)
        .defaultSize(width: 232, height: 500)
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
