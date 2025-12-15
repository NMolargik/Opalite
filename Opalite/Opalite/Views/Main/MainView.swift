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
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @State private var viewModel: MainView.ViewModel = ViewModel()
    
    var body: some View {
        if hSizeClass == .compact { compactWidthView() } else { regularWidthView() }
    }
    
    // MARK: - Compact View
    @ViewBuilder
    private func compactWidthView() -> some View {
        TabView(selection: $viewModel.appTab) {
            // MARK: Palette Tab
            NavigationStack {
                PortfolioView()
                    .navigationTitle("Palettes")
            }
            .tabItem {
                Label("Palettes", systemImage: "swatchpalette.fill")
            }
            .tag(AppTab.portfolio)
            
            // MARK: Colors Tab
            NavigationStack {
                Text("Colors")
                    .navigationTitle("Colors")
            }
            .tabItem {
                Label("Colors", systemImage: AppTab.portfolio.iconName())
            }
            .tag(AppTab.swatch)
            
            // MARK: Canvas Tab
            NavigationStack {
                Text("Canvas")
                    .navigationTitle(AppTab.canvas.rawValue)
            }
            .tabItem {
                Label(AppTab.canvas.rawValue, systemImage: AppTab.canvas.iconName())
            }
            .tag(AppTab.canvas)
            
            // MARK: Settings Tab
            NavigationStack {
                Text("Settings")
                    .navigationTitle(AppTab.settings.rawValue)
            }
            .tabItem {
                Label(AppTab.settings.rawValue, systemImage: AppTab.settings.iconName())
            }
            .tag(AppTab.settings)
        }
    }
    
    // MARK: - Regular View
    @ViewBuilder
    private func regularWidthView() -> some View {
        NavigationSplitView {
            List {
                
                // TODO: remove Swatch and expand Canvas
                Button {
                    viewModel.appTab = .portfolio
                } label: {
                    Label(AppTab.portfolio.rawValue, systemImage: AppTab.portfolio.iconName())
                }
//                Button {
//                    viewModel.appTab = .swatch
//                } label: {
//                    Label(AppTab.swatch.rawValue, systemImage: AppTab.swatch.iconName())
//                }
//                Button {
//                    viewModel.appTab = .canvas
//                } label: {
//                    Label(AppTab.canvas.rawValue, systemImage: AppTab.canvas.iconName())
//                }
                Button {
                    viewModel.appTab = .settings
                } label: {
                    Label(AppTab.settings.rawValue, systemImage: AppTab.settings.iconName())
                }
            }
            .navigationTitle("Opalite")
        } detail: {
            NavigationStack {
                Group {
                    switch viewModel.appTab {
                    case .portfolio:
                        PortfolioView()
                    case .swatch:
                        Text("Swatches")
                            .navigationTitle(AppTab.swatch.rawValue)
                    case .canvas:
                        CanvasView()
                            .navigationTitle(AppTab.canvas.rawValue)
                    case .settings:
                        SettingsView()
                            .navigationTitle(AppTab.settings.rawValue)
                    }
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: OpaliteColor.self,
        OpalitePalette.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let colorManager = ColorManager(context: container.mainContext)
    do {
        try colorManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }


    return MainView()
        .modelContainer(container)
        .environment(colorManager)
}
