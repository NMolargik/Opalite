//
//  OpaliteApp.swift
//  Opalite
//
//  Thin shell: builds the SessionController (composition root in OpaliteComposition),
//  registers it for App Intents, hosts the main window, the SwatchBar window, and the
//  visionOS immersive space, and owns what only an app process can: scene-phase work,
//  Home Screen quick actions, and TipKit configuration. All feature code lives in
//  Packages/Opalite.
//

import AppIntents
import SwiftData
import SwiftUI
import TipKit
import OpaliteComposition
import OpaliteCore
import OpaliteData
import OpaliteDesignSystem
import os
#if os(visionOS)
import OpaliteFeatureImmersive
#endif

@main
struct OpaliteApp: App {
    @UIApplicationDelegateAdaptor(QuickActionAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var quickActions = QuickActionRelay.shared
    private let session: SessionController
    #if os(visionOS)
    @State private var immersive = ImmersiveColorModel()
    #endif

    /// True when the process is hosting a unit-test bundle. Under the test host the app
    /// must avoid CloudKit (which traps on a simulator with no signed-in iCloud account).
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    /// One CloudKit-free container for the whole test-host process, backed by a unique
    /// on-disk temp store (in-memory stores crash SwiftData on the first fetch in the
    /// simulator, and SwiftUI may construct the `App` value more than once at launch).
    private static let testContainer: ModelContainer = (try? OpaliteStore.makeTemporaryContainer()) ?? OpaliteStore.makeContainer(inMemory: true)

    init() {
        let session = SessionController(
            container: Self.isRunningTests ? Self.testContainer : nil,
            indexer: Self.isRunningTests ? nil : SpotlightIndexer(),
            reviewRequester: AppStoreReviewRequester(),
            intentDonor: Self.isRunningTests ? nil : IntentDonor(),
            activityAnnotator: EntityActivityAnnotator(),
            vocabulary: Self.isRunningTests ? nil : ShortcutVocabularyUpdater()
        )
        self.session = session

        // Expose the session to App Intents (Siri, Shortcuts, Spotlight).
        AppDependencyManager.shared.add(dependency: session)

        if !Self.isRunningTests {
            try? Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(session: session)
                .modelContainer(session.container)
                .onOpenURL { url in session.handle(url: url) }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await session.becameActive() }
                    consumeQuickAction()
                }
                .onChange(of: quickActions.url) { _, _ in consumeQuickAction() }
                .task {
                    session.start()
                    consumeQuickAction()
                }
                #if os(visionOS)
                .environment(immersive)
                #endif
        }
        .handlesExternalEvents(matching: ["main", "color", "palette", "canvas", "create", "sample", "shared", "community", "search", "settings", "onyx"])
        .commands {
            OpaliteCommands(session: session)
        }
        .windowResizability(.contentMinSize)

        WindowGroup(id: SwatchBarScene.windowID) {
            SwatchBarRootView(session: session)
                .modelContainer(session.container)
                #if os(visionOS)
                .environment(immersive)
                #endif
        }
        .handlesExternalEvents(matching: ["swatchBar"])
        .defaultSize(width: SwatchBarScene.defaultSize.width, height: SwatchBarScene.defaultSize.height)
        .windowResizability(.contentMinSize)

        #if os(visionOS)
        ImmersiveSpace(id: "colorConstellation") {
            ColorConstellationView()
                .environment(immersive)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
        #endif
    }

    /// Routes a Home Screen quick action through the same deep-link path as URLs.
    private func consumeQuickAction() {
        guard let url = quickActions.url else { return }
        quickActions.url = nil
        session.handle(url: url)
    }
}
