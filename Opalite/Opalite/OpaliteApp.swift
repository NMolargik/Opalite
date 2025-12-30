import SwiftUI
import SwiftData
import Observation
import TipKit

@main
@MainActor
struct OpaliteApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow

    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"
    @AppStorage(AppStorageKeys.paletteOrder) private var paletteOrderData: Data = Data()

    let sharedModelContainer: ModelContainer
    let colorManager: ColorManager
    let canvasManager: CanvasManager
    let toastManager = ToastManager()
    let subscriptionManager = SubscriptionManager()
    let importCoordinator = ImportCoordinator()
    let quickActionManager = QuickActionManager()
    let hexCopyManager = HexCopyManager()

    #if os(iOS)
    /// Handles WatchConnectivity messages from Apple Watch for hex copying.
    let phoneSessionManager = PhoneSessionManager.shared
    #endif

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

        // Configure TipKit for user onboarding tips
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
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
                            AppDelegate.openSwatchBarWindow()
                        } else if shortcutType == "CreateNewColorAction" {
                            quickActionManager.requestCreateNewColor()
                        }
                    }

                    #endif
                }
                .task {
                    colorManager.author = userName
                }
                .onChange(of: userName) { _, newName in
                    colorManager.author = newName
                }
                .onOpenURL { url in
                    // Handle swatchBar URL scheme
                    if url.scheme == "opalite" && url.host == "swatchBar" {
                        #if os(iOS)
                        // Check if SwatchBar already exists and activate it
                        if AppDelegate.swatchBarSceneSession != nil {
                            AppDelegate.openSwatchBarWindow()
                        } else {
                            // No existing SwatchBar, create a new one
                            openWindow(id: "swatchBar")
                        }
                        #else
                        openWindow(id: "swatchBar")
                        #endif
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
        .environment(hexCopyManager)
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
                Button {
                    HapticsManager.shared.selection()
                    if !colorManager.isMainWindowOpen {
                        openWindow(id: "main")
                    }
                    quickActionManager.requestCreateNewColor()
                } label: {
                    Label("New Color", systemImage: "paintpalette.fill")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button {
                    HapticsManager.shared.selection()
                    if !colorManager.isMainWindowOpen {
                        openWindow(id: "main")
                    }
                    if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                        do {
                            let newPalette = try colorManager.createPalette(name: "New Palette")
                            prependPaletteToOrder(newPalette.id)
                            OpaliteTipActions.advanceTipsAfterContentCreation()
                        } catch {
                            toastManager.show(error: .paletteCreationFailed)
                        }
                    } else {
                        quickActionManager.requestPaywall(context: "Creating more palettes requires Onyx")
                    }
                } label: {
                    Label("New Palette", systemImage: "swatchpalette.fill")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button {
                    HapticsManager.shared.selection()
                    if !colorManager.isMainWindowOpen {
                        openWindow(id: "main")
                    }
                    if subscriptionManager.hasOnyxEntitlement {
                        do {
                            let newCanvas = try canvasManager.createCanvas()
                            canvasManager.pendingCanvasToOpen = newCanvas
                        } catch {
                            toastManager.show(error: .canvasCreationFailed)
                        }
                    } else {
                        quickActionManager.requestPaywall(context: "Canvas access requires Onyx")
                    }
                } label: {
                    Label("New Canvas", systemImage: "pencil.and.outline")
                }
                .keyboardShortcut("n", modifiers: [.command, .option])

                Divider()
            }

            // Add to the existing View menu (not creating a duplicate)
            CommandGroup(after: .toolbar) {
                Divider()

                Button {
                    HapticsManager.shared.selection()
                    #if os(iOS)
                    AppDelegate.openSwatchBarWindow()
                    #else
                    openWindow(id: "swatchBar")
                    #endif
                } label: {
                    Label("SwatchBar", systemImage: "square.stack.fill")
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button {
                    HapticsManager.shared.selection()
                    Task {
                        await colorManager.refreshAll()
                        await canvasManager.refreshAll()
                    }
                } label: {
                    Label("Refresh All", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            // Portfolio Menu
            CommandMenu("Portfolio") {
                Section("Colors") {
                    Button {
                        HapticsManager.shared.selection()
                        if !colorManager.isMainWindowOpen {
                            openWindow(id: "main")
                        }
                        quickActionManager.requestCreateNewColor()
                    } label: {
                        Label("New Color", systemImage: "paintpalette.fill")
                    }

                    Button {
                        Task { await colorManager.refreshAll() }
                    } label: {
                        Label("Refresh Colors", systemImage: "arrow.clockwise")
                    }
                }

                Divider()

                Section("Palettes") {
                    Button {
                        HapticsManager.shared.selection()
                        if !colorManager.isMainWindowOpen {
                            openWindow(id: "main")
                        }
                        if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                            do {
                                try colorManager.createPalette(name: "New Palette")
                                OpaliteTipActions.advanceTipsAfterContentCreation()
                            } catch {
                                toastManager.show(error: .paletteCreationFailed)
                            }
                        } else {
                            quickActionManager.requestPaywall(context: "Creating more palettes requires Onyx")
                        }
                    } label: {
                        Label("New Palette", systemImage: "swatchpalette.fill")
                    }
                }

                Divider()

                // Active Color Actions (only enabled when viewing a color detail)
                Section("Active Color") {
                    Button {
                        HapticsManager.shared.selection()
                        if let color = colorManager.activeColor {
                            hexCopyManager.copyHex(for: color)
                        }
                    } label: {
                        Label("Copy Hex", systemImage: "number")
                    }
                    .disabled(colorManager.activeColor == nil)
                    .keyboardShortcut("c", modifiers: [.command, .shift])

                    Button {
                        HapticsManager.shared.selection()
                        colorManager.editColorTrigger = UUID()
                    } label: {
                        Label("Edit Color", systemImage: "slider.horizontal.3")
                    }
                    .disabled(colorManager.activeColor == nil)
                    .keyboardShortcut("e", modifiers: .command)

                    Button {
                        HapticsManager.shared.selection()
                        colorManager.addToPaletteTrigger = UUID()
                    } label: {
                        Label("Add to Palette", systemImage: "swatchpalette")
                    }
                    .disabled(colorManager.activeColor == nil || colorManager.activeColor?.palette != nil)

                    Button {
                        HapticsManager.shared.selection()
                        colorManager.removeFromPaletteTrigger = UUID()
                    } label: {
                        Label("Remove from Palette", systemImage: "swatchpalette.fill")
                    }
                    .disabled(colorManager.activeColor == nil || colorManager.activeColor?.palette == nil)
                }

                Divider()

                // Active Palette Actions (only enabled when viewing a palette detail)
                Section("Active Palette") {
                    Button {
                        HapticsManager.shared.selection()
                        colorManager.renamePaletteTrigger = UUID()
                    } label: {
                        Label("Rename Palette", systemImage: "character.cursor.ibeam")
                    }
                    .disabled(colorManager.activePalette == nil)
                }
            }

            // Canvas Menu
            CommandMenu("Canvas") {
                Button {
                    HapticsManager.shared.selection()
                    if !colorManager.isMainWindowOpen {
                        openWindow(id: "main")
                    }
                    if subscriptionManager.hasOnyxEntitlement {
                        do {
                            let newCanvas = try canvasManager.createCanvas()
                            canvasManager.pendingCanvasToOpen = newCanvas
                        } catch {
                            toastManager.show(error: .canvasCreationFailed)
                        }
                    } else {
                        quickActionManager.requestPaywall(context: "Canvas access requires Onyx")
                    }
                } label: {
                    Label("New Canvas", systemImage: "pencil.and.outline")
                }

                Button {
                    Task { await canvasManager.refreshAll() }
                } label: {
                    Label("Refresh Canvases", systemImage: "arrow.clockwise")
                }

                Divider()

                Section("Shapes") {
                    Button {
                        HapticsManager.shared.selection()
                        canvasManager.pendingShape = .square
                    } label: {
                        Label("Square", systemImage: "square")
                    }
                    .keyboardShortcut("1", modifiers: [.command, .shift])

                    Button {
                        HapticsManager.shared.selection()
                        canvasManager.pendingShape = .circle
                    } label: {
                        Label("Circle", systemImage: "circle")
                    }
                    .keyboardShortcut("2", modifiers: [.command, .shift])

                    Button {
                        HapticsManager.shared.selection()
                        canvasManager.pendingShape = .triangle
                    } label: {
                        Label("Triangle", systemImage: "triangle")
                    }
                    .keyboardShortcut("3", modifiers: [.command, .shift])

                    Button {
                        HapticsManager.shared.selection()
                        canvasManager.pendingShape = .line
                    } label: {
                        Label("Line", systemImage: "line.diagonal")
                    }
                    .keyboardShortcut("4", modifiers: [.command, .shift])

                    Button {
                        HapticsManager.shared.selection()
                        canvasManager.pendingShape = .arrow
                    } label: {
                        Label("Arrow", systemImage: "arrow.right")
                    }
                    .keyboardShortcut("5", modifiers: [.command, .shift])
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
        .environment(hexCopyManager)
        .windowResizability(.contentSize)
        .defaultSize(width: 250, height: 1000)
#elseif os(iOS)
        WindowGroup(id: "swatchBar") {
            SwatchBarView()
                .toastContainer()
                .task {
                    await colorManager.refreshAll()
                }
                .onAppear {
                    colorManager.isSwatchBarOpen = true
                    AppDelegate.registerSwatchBarSceneSession()
                }
                .onDisappear {
                    colorManager.isSwatchBarOpen = false
                    AppDelegate.swatchBarSceneSession = nil
                }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "swatchBar"))
        .modelContainer(sharedModelContainer)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(toastManager)
        .environment(subscriptionManager)
        .environment(quickActionManager)
        .environment(hexCopyManager)
        .windowResizability(.contentSize)
        .defaultSize(width: 250, height: 1000)
#endif
    }
    
    private func prependPaletteToOrder(_ paletteID: UUID) {
        var currentOrder: [UUID] = []
        if !paletteOrderData.isEmpty,
           let decoded = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) {
            currentOrder = decoded
        }

        // Remove if already exists (shouldn't happen for new palettes, but safe)
        currentOrder.removeAll { $0 == paletteID }

        // Prepend to front
        currentOrder.insert(paletteID, at: 0)

        // Save
        if let encoded = try? JSONEncoder().encode(currentOrder) {
            paletteOrderData = encoded
        }
    }
}
