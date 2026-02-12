import SwiftUI
import SwiftData
import TipKit
import WidgetKit

@main
@MainActor
struct OpaliteApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow

    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"

    let sharedModelContainer: ModelContainer
    let colorManager: ColorManager
    let canvasManager: CanvasManager
    let communityManager = CommunityManager()
    let toastManager = ToastManager()
    let subscriptionManager = SubscriptionManager()
    let reviewRequestManager = ReviewRequestManager()
    let importCoordinator = ImportCoordinator()
    let quickActionManager = QuickActionManager()
    let hexCopyManager = HexCopyManager()
    let immersiveColorManager = ImmersiveColorManager()

    #if os(iOS)
    let phoneSessionManager = PhoneSessionManager.shared
    #endif

    init() {
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
            sharedModelContainer = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("[Opalite] Failed to initialize ModelContainer: \(error)")
        }

        colorManager = ColorManager(context: sharedModelContainer.mainContext)
        canvasManager = CanvasManager(context: sharedModelContainer.mainContext)

        #if os(iOS)
        phoneSessionManager.colorManager = colorManager
        #endif

        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .toastContainer()
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .task {
                    colorManager.author = userName
                    communityManager.publisherName = userName
                    syncColorsToWidgetStorage()
                    #if os(iOS)
                    phoneSessionManager.syncToWatch()
                    #endif
                }
                .onChange(of: userName) { _, newName in
                    colorManager.author = newName
                    communityManager.publisherName = newName
                }
                .onOpenURL { url in
                    handleDeepLink(url)
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
        }
        .opaliteEnvironment(
            modelContainer: sharedModelContainer,
            colorManager: colorManager,
            canvasManager: canvasManager,
            communityManager: communityManager,
            toastManager: toastManager,
            subscriptionManager: subscriptionManager,
            quickActionManager: quickActionManager,
            hexCopyManager: hexCopyManager,
            reviewRequestManager: reviewRequestManager,
            importCoordinator: importCoordinator,
            immersiveColorManager: immersiveColorManager
        )
        .commands {
            OpaliteCommands(
                colorManager: colorManager,
                canvasManager: canvasManager,
                subscriptionManager: subscriptionManager,
                toastManager: toastManager,
                quickActionManager: quickActionManager,
                hexCopyManager: hexCopyManager,
                reviewRequestManager: reviewRequestManager
            )
        }

#if os(macOS)
        Window("SwatchBar", id: "swatchBar") {
            SwatchBarView()
                .toastContainer()
                .task {
                    await colorManager.refreshAll()
                }
        }
        .opaliteEnvironment(
            modelContainer: sharedModelContainer,
            colorManager: colorManager,
            canvasManager: canvasManager,
            communityManager: communityManager,
            toastManager: toastManager,
            subscriptionManager: subscriptionManager,
            quickActionManager: quickActionManager,
            hexCopyManager: hexCopyManager,
            reviewRequestManager: reviewRequestManager,
            importCoordinator: importCoordinator,
            immersiveColorManager: immersiveColorManager
        )
        .windowResizability(.contentSize)
        .defaultSize(width: 250, height: 1000)
#elseif os(iOS) || os(visionOS)
        WindowGroup(id: "swatchBar") {
            SwatchBarView()
                .toastContainer()
                .task {
                    await colorManager.refreshAll()
                }
                #if os(iOS)
                .onAppear {
                    colorManager.isSwatchBarOpen = true
                    AppDelegate.registerSwatchBarSceneSession()
                }
                .onDisappear {
                    colorManager.isSwatchBarOpen = false
                    AppDelegate.swatchBarSceneSession = nil
                }
                #endif
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "swatchBar"))
        .opaliteEnvironment(
            modelContainer: sharedModelContainer,
            colorManager: colorManager,
            canvasManager: canvasManager,
            communityManager: communityManager,
            toastManager: toastManager,
            subscriptionManager: subscriptionManager,
            quickActionManager: quickActionManager,
            hexCopyManager: hexCopyManager,
            reviewRequestManager: reviewRequestManager,
            importCoordinator: importCoordinator,
            immersiveColorManager: immersiveColorManager
        )
        .windowResizability(.contentSize)
        .defaultSize(width: 250, height: 1000)
#endif

#if os(visionOS)
        ImmersiveSpace(id: "colorConstellation") {
            ColorConstellationView()
        }
        .immersionStyle(selection: .constant(.full), in: .full)
        .opaliteEnvironment(
            modelContainer: sharedModelContainer,
            colorManager: colorManager,
            canvasManager: canvasManager,
            communityManager: communityManager,
            toastManager: toastManager,
            subscriptionManager: subscriptionManager,
            quickActionManager: quickActionManager,
            hexCopyManager: hexCopyManager,
            reviewRequestManager: reviewRequestManager,
            importCoordinator: importCoordinator,
            immersiveColorManager: immersiveColorManager
        )
#endif
    }

    // MARK: - Scene Phase

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        Task { @MainActor in
            await colorManager.refreshAll()
            await canvasManager.refreshAll()
            syncColorsToWidgetStorage()

            #if os(iOS)
            phoneSessionManager.syncToWatch()
            #endif
        }

        #if os(iOS)
        if newPhase == .active {
            if let copiedHex = phoneSessionManager.processPendingHexCopy() {
                toastManager.showSuccess("Copied \(copiedHex) from Watch")
            }

            if let shortcutType = AppDelegate.pendingShortcutType {
                AppDelegate.pendingShortcutType = nil
                if shortcutType == "OpenSwatchBarAction" {
                    AppDelegate.openSwatchBarWindow()
                } else if shortcutType == "CreateNewColorAction" {
                    quickActionManager.requestCreateNewColor()
                }
            }
        }
        #endif
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        if url.scheme == "opalite" && url.host == "swatchBar" {
            #if os(iOS)
            if AppDelegate.swatchBarSceneSession != nil {
                AppDelegate.openSwatchBarWindow()
            } else {
                openWindow(id: "swatchBar")
            }
            #else
            openWindow(id: "swatchBar")
            #endif
            return
        }

        if url.scheme == "opalite" && url.host == "sharedImage" {
            return
        }

        if url.scheme == "opalite" && url.host == "color" {
            let pathComponents = url.pathComponents
            if pathComponents.count >= 2,
               let colorID = UUID(uuidString: pathComponents[1]) {
                IntentNavigationManager.shared.navigateToColor(id: colorID)
            }
            return
        }

        if url.scheme == "opalite" && url.host == "createColor" {
            IntentNavigationManager.shared.showColorEditor()
            return
        }

        importCoordinator.handleIncomingURL(url, colorManager: colorManager)
    }

    // MARK: - Widget Sync

    private func syncColorsToWidgetStorage() {
        let widgetColors = colorManager.colors.map { color in
            WidgetColor(
                id: color.id,
                name: color.name,
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
        }
        WidgetColorStorage.saveColors(widgetColors)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
