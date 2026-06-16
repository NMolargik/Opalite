//
//  MainView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openWindow) private var openWindow
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager
    @Environment(SubscriptionManager.self) private var subscriptionManager: SubscriptionManager

    // MARK: - Intent Navigation
    private var intentNavigationManager = IntentNavigationManager.shared

    @AppStorage(AppStorageKeys.skipSwatchBarConfirmation) private var skipSwatchBarConfirmation: Bool = false
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var settingsTabIcon: String {
        let mode = ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off
        return mode != .off ? "eye.trianglebadge.exclamationmark" : Tabs.settings.symbol
    }

    @State private var selectedTab: Tabs = .portfolio
    @State private var isShowingPaywall: Bool = false
    @State private var isShowingSwatchBarInfo: Bool = false

    // Rename canvas state
    @State private var canvasToRename: CanvasFile?
    @State private var renameText: String = ""

    var body: some View {
            TabView(selection: $selectedTab) {
                // MARK: - Portfolio Tab - All screens
                Tab(Tabs.portfolio.name, systemImage: Tabs.portfolio.symbol, value: .portfolio) {
                    PortfolioView()
                        .tint(.none)
                }
                
                // MARK: - Community Tab - All screens
                Tab(Tabs.community.name, systemImage: Tabs.community.symbol, value: .community) {
                    CommunityView()
                        .tint(.none)
                }
                
                // MARK: - Search Tab - All screens
                Tab(Tabs.search.name, systemImage: Tabs.search.symbol, value: .search, role: .search) {
                    SearchView(selectedTab: $selectedTab)
                        .tint(.none)
                }
                
                // MARK: - Canvas Tab - Compact Only, "regular" has a TabSection
                Tab(Tabs.canvas.name, systemImage: Tabs.canvas.symbol, value: .canvas) {
                    CanvasListView()
                        .tint(.none)
                }

                // MARK: - Settings Tab - All screens
                Tab(Tabs.settings.name, systemImage: settingsTabIcon, value: .settings) {
                    SettingsView()
                        .tint(.none)
                }
            }
            .tabViewStyle(.automatic)
            .modifier(TabBarMinimizeBehaviorModifier())
            .tint(selectedTab.symbolColor)
            .alert("Rename Canvas", isPresented: Binding(
                get: { canvasToRename != nil },
                set: { if !$0 { canvasToRename = nil } }
            )) {
                TextField("Canvas name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    HapticsManager.shared.selection()
                    canvasToRename = nil
                }
                Button("Rename") {
                    HapticsManager.shared.selection()
                    if let canvas = canvasToRename {
                        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            do {
                                try canvasManager.updateCanvas(canvas) { c in
                                    c.title = trimmed
                                }
                            } catch {
#if DEBUG
                                print("[MainView] Failed to rename canvas: \(error.localizedDescription)")
#endif
                            }
                        }
                    }
                    canvasToRename = nil
                }
            }
            .onChange(of: canvasManager.pendingCanvasToOpen) { _, newCanvas in
                if let canvas = newCanvas {
                    // Check if this canvas is accessible
                    if subscriptionManager.canAccessCanvas(canvas, oldestCanvasID: canvasManager.oldestCanvas?.id) {
                        selectedTab = .canvas
                    } else {
                        canvasManager.pendingCanvasToOpen = nil
                        isShowingPaywall = true
                    }
                }
            }
            .onChange(of: intentNavigationManager.pendingColorID, initial: true) { _, colorID in
                // Switch to Portfolio tab when intent requests color navigation.
                // `initial: true` handles the cold-launch case where a widget tap
                // sets pendingColorID before MainView mounts.
                if colorID != nil {
                    selectedTab = .portfolio
                }
            }
            .onChange(of: intentNavigationManager.pendingPaletteID, initial: true) { _, paletteID in
                // Switch to Portfolio tab when intent requests palette navigation.
                // `initial: true` handles the cold-launch case where an intent
                // sets pendingPaletteID before MainView mounts.
                if paletteID != nil {
                    selectedTab = .portfolio
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(featureContext: "Unlimited canvases require Onyx")
            }
            .sheet(isPresented: $isShowingSwatchBarInfo) {
                SwatchBarInfoSheet()
            }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: OpaliteColor.self,
        OpalitePalette.self,
        CanvasFile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let colorManager = ColorManager(context: container.mainContext)
    let canvasManager = CanvasManager(context: container.mainContext)
    do {
        try colorManager.loadSamples()
        try canvasManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }

    return MainView()
        .modelContainer(container)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(CommunityManager())
        .environment(QuickActionManager())
        .environment(HexCopyManager())
        .environment(SubscriptionManager())
        .environment(ReviewRequestManager())
        .environment(ImportCoordinator())
        .environment(ToastManager())
}
// MARK: - Tab Bar Minimize Behavior Modifier

private struct TabBarMinimizeBehaviorModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content
        #else
        if #available(iOS 26.0, macOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #endif
    }
}
