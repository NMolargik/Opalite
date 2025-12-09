//
//  MainView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.scenePhase) private var scenePhase
    
    @Environment(ColorManager.self) private var colorManager: ColorManager
    
    @State private var viewModel: MainView.ViewModel = ViewModel()
    
    private var isCompactWidth: Bool {
        hSizeClass == .compact
    }
    
    var body: some View {
        Group {
            if isCompactWidth {
                compactWidthView()
            } else {
                regularWidthView()
            }
        }
    }
    
    // MARK: - Compact View
    @ViewBuilder
    private func compactWidthView() -> some View {
        TabView(selection: $viewModel.appTab) {
            // MARK: Palette Tab
            NavigationStack {
                PaletteTabView()
                    .navigationTitle(AppTab.palette.rawValue)
            }
            .tabItem {
                AppTab.palette.icon()
                Text(AppTab.palette.rawValue)
            }
            
            // MARK: Swatches Tab
            NavigationStack {
                Text("Swatches")
                    .navigationTitle(AppTab.swatch.rawValue)
            }
            .tabItem {
                AppTab.swatch.icon()
                Text(AppTab.swatch.rawValue)
            }
            
            // MARK: Canvas Tab
            NavigationStack {
                Text("Canvas")
                    .navigationTitle(AppTab.canvas.rawValue)
            }
            .tabItem {
                AppTab.canvas.icon()
                Text(AppTab.canvas.rawValue)
            }
            
            // MARK: Settings Tab
            NavigationStack {
                Text("Settings")
                    .navigationTitle(AppTab.settings.rawValue)
            }
            .tabItem {
                AppTab.settings.icon()
                Text(AppTab.settings.rawValue)
            }
        }
    }
    
    // MARK: - Regular View
    @ViewBuilder
    private func regularWidthView() -> some View {
        TabView {
            PaletteTabView()
                .tabItem {
                    AppTab.palette.icon()
                    Text(AppTab.palette.rawValue)
                }
            
            Text("Swatches")
                .tabItem {
                    AppTab.swatch.icon()
                    Text(AppTab.swatch.rawValue)
                }
            
            CanvasTabView()
                .tabItem {
                    AppTab.canvas.icon()
                    Text(AppTab.canvas.rawValue)
                }
            
            SettingsTabView()
                .tabItem {
                    AppTab.settings.icon()
                    Text(AppTab.settings.rawValue)
                }
        }
        .tabViewStyle(.sidebarAdaptable)
        
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: OpaliteColor.self, OpalitePalette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let colorManager = ColorManager(context: container.mainContext)

    // Insert sample data into the in-memory context for previews
    // Assumes `OpalitePalette.sample` and `OpaliteColor.sample` static properties exist
    let paletteSample = OpalitePalette.sample
    let colorSample = OpaliteColor.sample
    let colorSample2 = OpaliteColor.sample2

    // Associate the sample color with the sample palette if not already associated
    colorSample.palette = paletteSample
    if paletteSample.colors == nil { paletteSample.colors = [] }
    if !(paletteSample.colors?.contains(where: { $0.id == colorSample.id }) ?? false) {
        paletteSample.colors?.append(colorSample)
    }

    // Insert into the context
    container.mainContext.insert(paletteSample)
    container.mainContext.insert(colorSample)
    container.mainContext.insert(colorSample2)

    // Optionally refresh the manager's caches for immediate display
    Task { await colorManager.refresh() }

    return MainView()
        .modelContainer(container)
        .environment(colorManager)
}
