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

    // Rename canvas state
    @State private var canvasToRename: CanvasFile? = nil
    @State private var renameText: String = ""

    
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
                if canvasManager.canvases.isEmpty {
                    // Keep the section visible so the "New Canvas" section action is always available.
                    Tab("No Canvases", systemImage: "scribble", value: Tabs.canvas) {
                        NavigationStack {
                            VStack(spacing: 12) {
                                Image(systemName: "scribble")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.secondary)

                                Text("No canvases yet")
                                    .font(.headline)

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
                                renameText = canvasFile.title
                                canvasToRename = canvasFile
                            } label: {
                                Label("Rename Canvas", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                try? canvasManager.deleteCanvas(canvasFile)
                            } label: {
                                Label("Delete Canvas", systemImage: "trash")
                            }
                        }
                    }
                }

            } header: {
                Label("Canvas", systemImage: "pencil")
            }
            .sectionActions {
                Button {
                    let newCanvas = try? canvasManager.createCanvas()
                    if let newCanvas {
                        selectedTab = .canvasBody(newCanvas)
                    }
                } label: {
                    Label("New Canvas", systemImage: "plus")
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)
            .hidden(horizontalSizeClass == .compact)
#endif
            
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(selectedTab.symbolColor())
        .alert("Rename Canvas", isPresented: Binding(
            get: { canvasToRename != nil },
            set: { if !$0 { canvasToRename = nil } }
        )) {
            TextField("Canvas name", text: $renameText)
            Button("Cancel", role: .cancel) {
                canvasToRename = nil
            }
            Button("Rename") {
                if let canvas = canvasToRename {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        try? canvasManager.updateCanvas(canvas) { c in
                            c.title = trimmed
                        }
                    }
                }
                canvasToRename = nil
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
}
