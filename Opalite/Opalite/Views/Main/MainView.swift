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
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack {
                    tab.destinationView()
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.iconName())
                }
                .tag(tab)
            }
        }
    }
    
    // MARK: - Regular View
    @ViewBuilder
    private func regularWidthView() -> some View {
        NavigationSplitView {
            List(AppTab.allCases, id: \.self) { tab in
                Button {
                    viewModel.appTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.iconName())
                }
            }
            .navigationTitle("Opalite")
        } detail: {
            NavigationStack {
                viewModel.appTab.destinationView()
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
