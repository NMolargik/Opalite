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
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager
        
    @Namespace private var namespace
    @State private var selectedTab: Tabs = .portfolio

    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - Portfolio Tab - All screens
            Tab(Tabs.portfolio.name, systemImage: Tabs.portfolio.symbol, value: .portfolio) {
                PortfolioView()
                    .tint(.none)
            }
            
            // MARK: - SwatchBoard Tab - Compact Only, "regular" has a whole Window
            Tab(Tabs.swatchBoard.name, systemImage: Tabs.swatchBoard.symbol, value: .swatchBoard) {
                SwatchBoardTabView()
                    .tint(.none)
            }
            .hidden(horizontalSizeClass == .regular)
            
            // MARK: - Canvas Tab - Compact Only, "regular" has a TabSection
            Tab(Tabs.canvas.name, systemImage: Tabs.canvas.symbol, value: .canvas) {
                CanvasListView()
                    .tint(.none)
            }
            .hidden(horizontalSizeClass == .regular)
            
            // MARK: - Search Tab - All screens
            Tab(Tabs.search.name, systemImage: Tabs.search.symbol, value: .search, role: .search) {
                Text("Search View")
                    .tint(.none)
            }
            
            // MARK: - Settings Tab - All screens
            Tab(Tabs.settings.name, systemImage: Tabs.settings.symbol, value: .settings) {
                SettingsView()
                    .tint(.none)
            }
            
            // MARK: - Canvas Body Tab - All screens
#if !os(visionOS)
            TabSection {
                ForEach(canvasManager.canvases) { canvasFile in
                    Tab(canvasFile.title, systemImage: "scribble", value: Tabs.canvasBody(canvasFile)) {
                        NavigationStack {
                            CanvasView(canvasFile: canvasFile)
                                .tint(.none)
                        }
                    }
                }
                
            } header: {
                Label("Canvas", systemImage: "pencil")
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)
#endif
            
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(selectedTab.symbolColor())
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
}

