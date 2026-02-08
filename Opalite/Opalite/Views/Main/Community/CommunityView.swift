//
//  CommunityView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import SwiftData
import CloudKit

struct CommunityView: View {
    @Environment(CommunityManager.self) private var communityManager
    @Environment(ColorManager.self) private var colorManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(ToastManager.self) private var toastManager

    @State private var viewModel = ViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            VStack(spacing: 0) {
                // Segment Picker
                Picker("Content Type", selection: $viewModel.selectedSegment) {
                    
                    ForEach(CommunitySegment.allCases) { segment in
                        Label(segment.rawValue, systemImage: segment.icon)
                            .tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Content
                Group {
                    if !communityManager.isConnectedToNetwork {
                        noNetworkView
                    } else if !communityManager.isUserSignedIn {
                        iCloudSignInView
                    } else if viewModel.selectedSegment == .colors {
                        colorsContent
                    } else {
                        palettesContent
                    }
                }
            }
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticsManager.shared.selection()
                        viewModel.isShowingCommunityInfo = true
                    } label: {
                        Label("About Community", systemImage: "info.circle")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    sortMenu
                }
            }
            .sheet(isPresented: $viewModel.isShowingCommunityInfo) {
                CommunityInfoSheet()
            }
            .searchable(text: $viewModel.searchText, prompt: "Search \(viewModel.selectedSegment.rawValue)")
            .onSubmit(of: .search) {
                Task {
                    await performSearch()
                }
            }
            .onChange(of: viewModel.searchText) { _, newValue in
                if newValue.isEmpty {
                    // Use search function with empty query to properly restore from cache
                    Task {
                        await performSearch()
                    }
                }
            }
            .onChange(of: viewModel.selectedSegment) { _, _ in
                // Refresh when switching tabs
                Task {
                    await refreshContentForCurrentSegment()
                }
            }
            .task {
                await initialLoad()
            }
            .navigationDestination(for: CommunityNavigationNode.self) { node in
                switch node {
                case .colorDetail(let color):
                    CommunityColorDetailView(color: color)
                case .paletteDetail(let palette):
                    CommunityPaletteDetailView(initialPalette: palette)
                case .publisherProfile(let userRecordID, let displayName):
                    CommunityPublisherProfileView(userRecordID: userRecordID, displayName: displayName)
                }
            }
        }
    }

    // MARK: - No Network View

    private var noNetworkView: some View {
        ScrollView {
            ContentUnavailableView {
                Label("No Internet Connection", systemImage: "wifi.slash")
            } description: {
                Text("Connect to the internet to browse colors and palettes from the community.")
            } actions: {
                Button {
                    HapticsManager.shared.selection()
                    Task {
                        await forceRefreshContent()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 400)
        }
        .refreshable {
            await forceRefreshContent()
        }
    }

    // MARK: - iCloud Sign In View

    private var iCloudSignInView: some View {
        ContentUnavailableView {
            Label("Sign in to iCloud", systemImage: "icloud.slash")
        } description: {
            Text("Sign in to iCloud in Settings to browse and share colors with the community.")
        } actions: {
            Button {
                HapticsManager.shared.selection()
                Task {
                    await communityManager.fetchCurrentUserRecordID()
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Colors Content

    private var colorsContent: some View {
        ScrollView {
            if communityManager.colors.isEmpty && !communityManager.isLoading {
                CommunityEmptyStateView(segment: .colors)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(communityManager.colors) { color in
                        Button {
                            HapticsManager.shared.selection()
                            viewModel.navigationPath.append(CommunityNavigationNode.colorDetail(color))
                        } label: {
                            CommunityColorCardView(color: color)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            colorContextMenu(for: color)
                        }
                    }

                    // Load more indicator
                    if communityManager.hasMoreColors && !communityManager.colors.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .onAppear {
                                Task {
                                    try? await communityManager.fetchMoreColors(sortBy: viewModel.sortOption)
                                }
                            }
                    }
                }
                .padding()
                .padding(.top, 8)
            }
        }
        .refreshable {
            await forceRefreshContent()
        }
        .overlay {
            if communityManager.isLoading && communityManager.colors.isEmpty {
                ProgressView("Gathering Colors...")
            }
        }
    }

    // MARK: - Palettes Content

    private var palettesContent: some View {
        ScrollView {
            if communityManager.palettes.isEmpty && !communityManager.isLoading {
                CommunityEmptyStateView(segment: .palettes)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(communityManager.palettes) { palette in
                        Button {
                            HapticsManager.shared.selection()
                            viewModel.navigationPath.append(CommunityNavigationNode.paletteDetail(palette))
                        } label: {
                            CommunityPaletteCardView(palette: palette)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            paletteContextMenu(for: palette)
                        }
                    }

                    // Load more indicator
                    if communityManager.hasMorePalettes && !communityManager.palettes.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .onAppear {
                                Task {
                                    try? await communityManager.fetchMorePalettes(sortBy: viewModel.sortOption)
                                }
                            }
                    }
                }
                .padding()
                .padding(.top, 8)
            }
        }
        .refreshable {
            await forceRefreshContent()
        }
        .overlay {
            if communityManager.isLoading && communityManager.palettes.isEmpty {
                ProgressView("Curating Palettes...")
            }
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(CommunitySortOption.allCases) { option in
                Button {
                    HapticsManager.shared.selection()
                    viewModel.sortOption = option
                    // Sort cached data locally instead of re-fetching
                    sortCachedContent()
                } label: {
                    HStack {
                        Label(option.rawValue, systemImage: option.icon)
                        if viewModel.sortOption == option {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    /// Sorts the cached colors/palettes locally without network fetch
    private func sortCachedContent() {
        if viewModel.selectedSegment == .colors {
            communityManager.sortColors(by: viewModel.sortOption)
        } else {
            communityManager.sortPalettes(by: viewModel.sortOption)
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private func colorContextMenu(for color: CommunityColor) -> some View {
        Button {
            HapticsManager.shared.selection()
            viewModel.navigationPath.append(CommunityNavigationNode.colorDetail(color))
        } label: {
            Label("View Details", systemImage: "info.circle")
        }
        
        Button {
            HapticsManager.shared.selection()
            viewModel.navigationPath.append(CommunityNavigationNode.publisherProfile(color.publisherUserRecordID, color.publisherName))
        } label: {
            Label("View Publisher", systemImage: "person")
        }

        Divider()

        Button(role: .destructive) {
            HapticsManager.shared.selection()
            viewModel.itemToReport = (color.id, .color)
            viewModel.isShowingReportSheet = true
        } label: {
            Label("Report", systemImage: "flag")
        }
    }

    @ViewBuilder
    private func paletteContextMenu(for palette: CommunityPalette) -> some View {
        Button {
            HapticsManager.shared.selection()
            viewModel.navigationPath.append(CommunityNavigationNode.paletteDetail(palette))
        } label: {
            Label("View Details", systemImage: "info.circle")
        }

        Button {
            HapticsManager.shared.selection()
            viewModel.navigationPath.append(CommunityNavigationNode.publisherProfile(palette.publisherUserRecordID, palette.publisherName))
        } label: {
            Label("View Publisher", systemImage: "person")
        }

        Divider()

        Button(role: .destructive) {
            HapticsManager.shared.selection()
            viewModel.itemToReport = (palette.id, .palette)
            viewModel.isShowingReportSheet = true
        } label: {
            Label("Report", systemImage: "flag")
        }
    }

    // MARK: - Actions

    private func initialLoad() async {
        // Load initial data for colors on first launch
        if communityManager.colors.isEmpty {
            await refreshColorsIfNeeded(force: true)
        }
    }

    /// Refreshes content for current segment, using cache when available
    private func refreshContentForCurrentSegment() async {
        if viewModel.selectedSegment == .colors {
            await refreshColorsIfNeeded(force: false)
        } else {
            await refreshPalettesIfNeeded(force: false)
        }
    }

    /// Force refresh (pull-to-refresh) - always fetches fresh data
    private func forceRefreshContent() async {
        if viewModel.selectedSegment == .colors {
            await refreshColorsIfNeeded(force: true)
        } else {
            await refreshPalettesIfNeeded(force: true)
        }
    }

    /// Refreshes colors, using cache if still valid
    private func refreshColorsIfNeeded(force: Bool) async {
        // Skip if cache is still valid (unless forced)
        if !force && !viewModel.isColorsCacheStale() && !communityManager.colors.isEmpty {
            return
        }

        do {
            try await communityManager.fetchPublishedColors(sortBy: viewModel.sortOption, refresh: true)
            communityManager.cacheFullDataset() // Cache for search filtering
            viewModel.markColorsFetched()
        } catch {
            toastManager.show(error: .communityFetchFailed(reason: error.localizedDescription))
        }
    }

    /// Refreshes palettes, using cache if still valid
    private func refreshPalettesIfNeeded(force: Bool) async {
        // Skip if cache is still valid (unless forced)
        if !force && !viewModel.isPalettesCacheStale() && !communityManager.palettes.isEmpty {
            return
        }

        do {
            try await communityManager.fetchPublishedPalettes(sortBy: viewModel.sortOption, refresh: true)
            communityManager.cacheFullDataset() // Cache for search filtering
            viewModel.markPalettesFetched()
        } catch {
            toastManager.show(error: .communityFetchFailed(reason: error.localizedDescription))
        }
    }

    /// Legacy refreshContent for search clear and sort changes
    private func refreshContent() async {
        await forceRefreshContent()
    }

    private func performSearch() async {
        do {
            if viewModel.selectedSegment == .colors {
                try await communityManager.searchColors(query: viewModel.searchText, sortBy: viewModel.sortOption)
                viewModel.markColorsFetched()
            } else {
                try await communityManager.searchPalettes(query: viewModel.searchText, sortBy: viewModel.sortOption)
                viewModel.markPalettesFetched()
            }
        } catch {
            toastManager.show(error: .communityFetchFailed(reason: error.localizedDescription))
        }
    }

    private func saveColorToPortfolio(_ color: CommunityColor) {
        guard subscriptionManager.hasOnyxEntitlement else {
            viewModel.isShowingPaywall = true
            viewModel.paywallContext = "Save colors from the community to your portfolio!"
            return
        }

        do {
            try communityManager.saveColorToPortfolio(color, colorManager: colorManager, subscriptionManager: subscriptionManager)
            toastManager.showSuccess("Saved to Portfolio")
        } catch let error as OpaliteError {
            toastManager.show(error: error)
        } catch {
            toastManager.show(error: .unknownError(error.localizedDescription))
        }
    }

    private func savePaletteToPortfolio(_ palette: CommunityPalette) {
        guard subscriptionManager.hasOnyxEntitlement else {
            viewModel.isShowingPaywall = true
            viewModel.paywallContext = "Save palettes from the community to your portfolio!"
            return
        }

        Task {
            do {
                try await communityManager.savePaletteToPortfolio(palette, colorManager: colorManager, subscriptionManager: subscriptionManager)
                await MainActor.run {
                    toastManager.showSuccess("Saved to Portfolio")
                }
            } catch let error as OpaliteError {
                await MainActor.run {
                    toastManager.show(error: error)
                }
            } catch {
                await MainActor.run {
                    toastManager.show(error: .unknownError(error.localizedDescription))
                }
            }
        }
    }

}

// MARK: - Preview

#Preview {
    CommunityView()
        .environment(CommunityManager())
        .environment(ColorManager(context: try! ModelContainer(for: OpaliteColor.self, OpalitePalette.self, CanvasFile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
        .environment(SubscriptionManager())
        .environment(ToastManager())
}
