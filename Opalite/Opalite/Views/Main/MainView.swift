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
    @Environment(SubscriptionManager.self) private var subscriptionManager

    // MARK: - Intent Navigation
    private var intentNavigationManager = IntentNavigationManager.shared

    @AppStorage(AppStorageKeys.skipSwatchBarConfirmation) private var skipSwatchBarConfirmation: Bool = false

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

            // MARK: - Canvas Tab - Compact Only, "regular" has a TabSection
            Tab(Tabs.canvas.name, systemImage: Tabs.canvas.symbol, value: .canvas) {
                CanvasListView()
                    .tint(.none)
            }
            .hidden(horizontalSizeClass == .regular)

            // MARK: - Search Tab - All screens
            Tab(Tabs.search.name, systemImage: Tabs.search.symbol, value: .search, role: .search) {
                SearchView(selectedTab: $selectedTab)
                    .tint(.none)
            }

            // MARK: - SwatchBar Tab - Regular size class only (iPad/Mac), hidden when already open
            Tab(Tabs.swatchBar.name, systemImage: Tabs.swatchBar.symbol, value: .swatchBar) {
                // Empty view - this tab just opens the window
                Color.clear
            }
            .hidden(horizontalSizeClass == .compact || colorManager.isSwatchBarOpen)
            .defaultVisibility(.hidden, for: .tabBar)

            // MARK: - Settings Tab - All screens
            Tab(Tabs.settings.name, systemImage: Tabs.settings.symbol, value: .settings) {
                SettingsView()
                    .tint(.none)
            }

            // MARK: - Canvas Body Tab - All screens
            TabSection {
                if canvasManager.canvases.isEmpty {
                    // Keep the section visible so the "New Canvas" section action is always available.
                    Tab("No Canvases", systemImage: "scribble", value: Tabs.canvas) {
                        NavigationStack {
                            VStack(spacing: 12) {
                                Image(systemName: "scribble")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)

                                Text("No canvases yet")
                                    .font(.headline)
                                    .accessibilityAddTraits(.isHeader)

                                Text("Use the \"New Canvas\" button in the sidebar section to create one.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                            .navigationTitle("Canvas")
                        }
                    }
                    .disabled(true)
                } else {
                    ForEach(canvasManager.canvases) { canvasFile in
                        Tab(canvasFile.title, systemImage: "scribble", value: Tabs.canvasBody(canvasFile)) {
                            NavigationStack {
                                CanvasView(canvasFile: canvasFile)
                                    .tint(.none)
                            }
                        }
                        .contextMenu {
                            Button {
                                HapticsManager.shared.selection()
                                renameText = canvasFile.title
                                canvasToRename = canvasFile
                            } label: {
                                Label("Rename Canvas", systemImage: "pencil")
                            }
                            .tint(.none)

                            Button(role: .destructive) {
                                HapticsManager.shared.selection()
                                do {
                                    try canvasManager.deleteCanvas(canvasFile)
                                } catch {
                                    #if DEBUG
                                    print("[MainView] Failed to delete canvas '\(canvasFile.title)': \(error.localizedDescription)")
                                    #endif
                                }
                            } label: {
                                Label("Delete Canvas", systemImage: "trash.fill")
                            }
                            .tint(.red)
                        }
                    }
                }

            } header: {
                Label("Canvas", systemImage: "pencil")
            }
            .sectionActions {
                Button {
                    HapticsManager.shared.selection()
                    if subscriptionManager.hasOnyxEntitlement {
                        do {
                            let newCanvas = try canvasManager.createCanvas()
                            // Defer tab selection to allow view hierarchy to update first
                            DispatchQueue.main.async {
                                selectedTab = .canvasBody(newCanvas)
                            }
                        } catch {
                            #if DEBUG
                            print("[MainView] Failed to create canvas: \(error.localizedDescription)")
                            #endif
                        }
                    } else {
                        isShowingPaywall = true
                    }
                } label: {
                    Label("New Canvas", systemImage: "plus")
                }
                .accessibilityLabel("New Canvas")
                .accessibilityHint(subscriptionManager.hasOnyxEntitlement ? "Creates a new drawing canvas" : "Opens Onyx subscription options")
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(selectedTab.symbolColor())
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
        .onChange(of: selectedTab) { oldTab, newTab in
            // Check if user is trying to open a canvas without entitlement
            if case .canvasBody = newTab {
                if !subscriptionManager.hasOnyxEntitlement {
                    // Block access and show paywall
                    HapticsManager.shared.selection()
                    selectedTab = oldTab
                    isShowingPaywall = true
                    return
                }
            }

            if newTab == .swatchBar {
                selectedTab = oldTab
                if skipSwatchBarConfirmation {
                    // Skip the info sheet and launch directly
                    #if os(iOS)
                    AppDelegate.openSwatchBarWindow()
                    #else
                    openWindow(id: "swatchBar")
                    #endif
                } else {
                    // Show SwatchBar info sheet
                    isShowingSwatchBarInfo = true
                }
                return
            }

        }
        .onChange(of: canvasManager.pendingCanvasToOpen) { _, newCanvas in
            if let canvas = newCanvas {
                canvasManager.pendingCanvasToOpen = nil
                // Check entitlement before switching to canvas tab
                if subscriptionManager.hasOnyxEntitlement {
                    DispatchQueue.main.async {
                        selectedTab = .canvasBody(canvas)
                    }
                } else {
                    isShowingPaywall = true
                }
            }
        }
        .onChange(of: canvasManager.canvases) { _, newCanvases in
            handleCanvasListChange(newCanvases)
        }
        .onChange(of: intentNavigationManager.pendingColorID) { _, colorID in
            // Switch to Portfolio tab when intent requests color navigation
            if colorID != nil {
                selectedTab = .portfolio
            }
        }
        .onChange(of: intentNavigationManager.pendingPaletteID) { _, paletteID in
            // Switch to Portfolio tab when intent requests palette navigation
            if paletteID != nil {
                selectedTab = .portfolio
            }
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Canvas access requires Onyx")
        }
        .sheet(isPresented: $isShowingSwatchBarInfo) {
            SwatchBarInfoSheet()
        }
    }

    // MARK: - Helpers

    /// Handles canvas list changes - switches to portfolio if the current canvas was deleted
    private func handleCanvasListChange(_ canvases: [CanvasFile]) {
        if case .canvasBody(let optionalCanvas) = selectedTab, let canvas = optionalCanvas {
            let canvasID = canvas.id
            let canvasStillExists = canvases.contains { (file: CanvasFile) in file.id == canvasID }
            if !canvasStillExists {
                selectedTab = .portfolio
            }
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
        .environment(SubscriptionManager())
        .environment(ToastManager())
}
