//
//  TVRootView.swift
//  OpaliteFeatureTV
//
//  The whole Apple TV interface: a top tab bar over Portfolio, Search and Settings. The
//  tvOS app target is a thin shell that builds the environment models and hosts this view.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct TVRootView: View {
    @Environment(AppRouter.self) private var router

    public init() {}

    public var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            ForEach(AppTab.available) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    content(for: tab)
                }
            }
        }
        .toastContainer()
        .accessibilityIdentifier("tvRoot")
    }

    @ContentBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .portfolio: TVPortfolioView()
        case .search: TVSearchView()
        case .settings: TVSettingsView()
        case .community, .canvas: EmptyView()
        }
    }
}

#if DEBUG
#Preview("Root") {
    TVRootView()
        .previewEnvironment()
}

#Preview("Root — empty") {
    TVRootView()
        .previewEnvironment(seeded: false)
}
#endif
#endif
