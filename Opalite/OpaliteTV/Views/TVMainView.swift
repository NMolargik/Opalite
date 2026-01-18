//
//  TVMainView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Main tab-based navigation for OpaliteTV.
/// Provides access to Portfolio, Search, and Settings.
struct TVMainView: View {
    @State private var selectedTab: TVTab = .portfolio

    var body: some View {
        TabView(selection: $selectedTab) {
            TVPortfolioView()
                .tabItem {
                    Label("Portfolio", systemImage: "paintpalette.fill")
                }
                .tag(TVTab.portfolio)

            TVSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(TVTab.search)

            TVSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(TVTab.settings)
        }
    }
}

// MARK: - Tab Enum

enum TVTab: Hashable {
    case portfolio
    case search
    case settings
}

#Preview {
    TVMainView()
}
