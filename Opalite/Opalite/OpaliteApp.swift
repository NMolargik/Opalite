import SwiftUI
import SwiftData
import Observation

@main
@MainActor
struct OpaliteApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow

    @AppStorage("userName") private var userName: String = "User"

    let sharedModelContainer: ModelContainer
    let colorManager: ColorManager
    let canvasManager: CanvasManager
    let toastManager = ToastManager()
    let subscriptionManager = SubscriptionManager()
    let importCoordinator = ImportCoordinator()
    let quickActionManager = QuickActionManager()

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
                        } else if shortcutType == "CreateNewColorAction" {
                            quickActionManager.requestCreateNewColor()
                        }
                    }
                    #endif
                }
                .onChange(of: userName) { _, newName in
                    colorManager.author = userName
                }
                .onOpenURL { url in
                    // Handle swatchBar URL scheme
                    if url.scheme == "opalite" && url.host == "swatchBar" {
                        openWindow(id: "swatchBar")
                        return
                    }
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
                    Button("OK", role: .cancel) {
                        HapticsManager.shared.selection()
                    }
                } message: {
                    Text(importCoordinator.importError?.errorDescription ?? "An unknown error occurred.")
                }
                .environment(quickActionManager)
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(toastManager)
        .environment(subscriptionManager)
        .environment(importCoordinator)
        .commands {
            // Replace the New Item command group (Cmd+N)
            CommandGroup(replacing: .newItem) {
                Button("New Color") {
                    HapticsManager.shared.selection()
                    quickActionManager.requestCreateNewColor()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Palette") {
                    HapticsManager.shared.selection()
                    if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                        do {
                            try colorManager.createPalette(name: "New Palette")
                        } catch {
                            toastManager.show(error: .paletteCreationFailed)
                        }
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Canvas") {
                    HapticsManager.shared.selection()
                    do {
                        let newCanvas = try canvasManager.createCanvas()
                        canvasManager.pendingCanvasToOpen = newCanvas
                    } catch {
                        toastManager.show(error: .canvasCreationFailed)
                    }
                }
                .keyboardShortcut("n", modifiers: [.command, .option])

                Divider()
            }

            // View Menu
            CommandMenu("View") {
                Button("Open SwatchBar") {
                    HapticsManager.shared.selection()
                    #if targetEnvironment(macCatalyst)
                    AppDelegate.openSwatchBarWindow()
                    #else
                    openWindow(id: "swatchBar")
                    #endif
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button("Refresh") {
                    HapticsManager.shared.selection()
                    Task {
                        await colorManager.refreshAll()
                        await canvasManager.refreshAll()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            // Portfolio Menu
            CommandMenu("Portfolio") {
                Section("Colors") {
                    Button("Create New Color") {
                        HapticsManager.shared.selection()
                        quickActionManager.requestCreateNewColor()
                    }

                    Button("Refresh Colors") {
                        Task { await colorManager.refreshAll() }
                    }
                }

                Divider()

                Section("Palettes") {
                    Button("Create New Palette") {
                        HapticsManager.shared.selection()
                        if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                            do {
                                try colorManager.createPalette(name: "New Palette")
                            } catch {
                                toastManager.show(error: .paletteCreationFailed)
                            }
                        }
                    }
                }
            }

            // Canvas Menu
            CommandMenu("Canvas") {
                Button("New Canvas") {
                    HapticsManager.shared.selection()
                    do {
                        let newCanvas = try canvasManager.createCanvas()
                        canvasManager.pendingCanvasToOpen = newCanvas
                    } catch {
                        toastManager.show(error: .canvasCreationFailed)
                    }
                }

                Button("Refresh Canvases") {
                    Task { await canvasManager.refreshAll() }
                }
            }
        }

#if os(macOS)
        Window("SwatchBar", id: "swatchBar") {
            SwatchBarView()
                .toastContainer()
                .task {
                    await colorManager.refreshAll()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(toastManager)
        .environment(subscriptionManager)
        .environment(quickActionManager)
        .windowResizability(.contentSize)
        .defaultSize(width: 180, height: 500)
#elseif os(iOS)
        WindowGroup(id: "swatchBar") {
            SwatchBarView()
                .toastContainer()
                .task {
                    await colorManager.refreshAll()
                }
                .onAppear {
                    colorManager.isSwatchBarOpen = true
                }
                .onDisappear {
                    colorManager.isSwatchBarOpen = false
                }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "swatchBar"))
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(toastManager)
        .environment(subscriptionManager)
        .environment(quickActionManager)
        .windowResizability(.contentSize)
        .defaultSize(width: 180, height: 500)
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
