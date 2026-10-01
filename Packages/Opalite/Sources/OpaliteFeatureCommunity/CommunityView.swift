//
//  CommunityView.swift
//  OpaliteFeatureCommunity
//
//  The Community tab's root content: a browse feed of published colors and palettes.
//  A segmented Colors/Palettes control sits under the large title, the toolbar groups a
//  sort menu with the info button, search minimizes into the bar, and the adaptive card
//  grid pages in as it scrolls. The shell owns the NavigationStack and registers
//  `CommunityDestinationView` for `CommunityDestination`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureSharing

public struct CommunityView: View {
    @Environment(CommunityModel.self) private var community
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(AppStorageKeys.hasPromptedForCommunityName) private var hasPromptedForCommunityName = false

    @State private var model = CommunityFeedModel()

    public init() {}

    private var status: CommunityFeedStatus { model.status(in: community) }

    public var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.lg) {
                segmentPicker
                feedBody
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.bottom, Brand.Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .background(groupedBackground)
        .softScrollEdgesIfAvailable()
        .refreshable { await model.refresh(in: community) }
        .navigationTitle("Community")
        .navigationSubtitleIfAvailable(subtitle)
        .toolbar { toolbarContent }
        .searchable(text: $model.searchText, prompt: Text(searchPrompt))
        .minimizingSearchIfAvailable()
        .onSubmit(of: .search) { Task { await model.submitSearch(in: community) } }
        .onChange(of: model.searchText) { model.searchTextChanged(in: community) }
        .task(id: model.segment) { await model.ensureLoaded(in: community) }
        .task {
            if CommunityNameDraft.shouldPrompt(hasPrompted: hasPromptedForCommunityName) {
                model.isShowingNamePrompt = true
            }
        }
        .sheet(isPresented: $model.isShowingInfo) {
            CommunityInfoSheet()
        }
        .sheet(isPresented: $model.isShowingNamePrompt, onDismiss: { hasPromptedForCommunityName = true }) {
            CommunityNamePromptSheet()
        }
        .sheet(item: $model.reportTarget) { target in
            ReportItemSheet(id: target.id, type: target.type)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: status)
    }

    // MARK: - Chrome

    private var subtitle: String {
        community.isShowingSearchResults
            ? String(localized: "Search results")
            : String(localized: "Sorted by \(community.sortOption.title)")
    }

    private var searchPrompt: String {
        switch model.segment {
        case .colors: String(localized: "Search colors")
        case .palettes: String(localized: "Search palettes")
        }
    }

    private var segmentPicker: some View {
        Picker("Content", selection: $model.segment) {
            ForEach(CommunitySegment.allCases) { segment in
                Label(segment.title, systemImage: segment.systemImage)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: Brand.readableWidth)
        .padding(.top, Brand.Space.sm)
        .onChange(of: model.segment) { Haptics.selection() }
        .accessibilityIdentifier("community.segmentPicker")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            sortMenu
        }
        ToolbarSpacerIfAvailable(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.selection()
                model.isShowingInfo = true
            } label: {
                Label("About the Community", systemImage: "info.circle")
            }
            .toolbarButtonTint()
            .accessibilityIdentifier("community.infoButton")
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: Binding(
                get: { community.sortOption },
                set: { option in
                    Haptics.selection()
                    model.sort(by: option, in: community)
                }
            )) {
                ForEach(CommunitySortOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .toolbarButtonTint()
        .accessibilityLabel(Text("Sort"))
        .accessibilityValue(Text(community.sortOption.title))
        .accessibilityHint(Text("Changes the order of community content"))
        .accessibilityIdentifier("community.sortMenu")
    }

    // MARK: - Feed

    @ContentBuilder
    private var feedBody: some View {
        switch status {
        case .loading:
            CommunitySkeletonGrid(segment: model.segment)
                .transition(.opacity)
        case .content:
            switch model.segment {
            case .colors:
                CommunityColorGrid(colors: community.colors, onReport: { model.reportTarget = $0 }, footer: loadingFooter)
            case .palettes:
                CommunityPaletteGrid(palettes: community.palettes, onReport: { model.reportTarget = $0 }, footer: loadingFooter)
            }
        case .offline, .signedOut, .failed, .empty, .noResults:
            CommunityStateView(
                status: status,
                segment: model.segment,
                searchText: model.searchText,
                onRetry: { await model.refresh(in: community) },
                onGoToPortfolio: { router.select(.portfolio) }
            )
            .transition(.opacity)
        }
    }

    private var loadingFooter: (() -> CommunityLoadingFooter)? {
        guard model.hasMore(in: community) else { return nil }
        return { CommunityLoadingFooter { await model.loadMore(in: community) } }
    }
}

#if DEBUG
#Preview("Community") {
    NavigationStack {
        CommunityView()
            .navigationDestination(for: CommunityDestination.self) { CommunityDestinationView(destination: $0) }
    }
    .previewEnvironment()
}

#Preview("Signed out") {
    let environment = PreviewEnvironment()
    environment.communityService.userID = nil
    return NavigationStack {
        CommunityView()
    }
    .previewEnvironment(environment)
}
#endif
#endif
