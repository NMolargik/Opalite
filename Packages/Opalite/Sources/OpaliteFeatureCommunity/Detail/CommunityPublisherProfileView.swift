//
//  CommunityPublisherProfileView.swift
//  OpaliteFeatureCommunity
//
//  Everything one creator has shared: a header with their counts, a Colors/Palettes
//  segment, and the same card grids as the feed. Palette colors load after the records.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureSharing

public struct CommunityPublisherProfileView: View {
    let id: CommunityRecordID
    let displayName: String

    @Environment(CommunityModel.self) private var community
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var colors: [CommunityColor] = []
    @State private var palettes: [CommunityPalette] = []
    @State private var hasLoaded = false
    @State private var didFail = false
    @State private var segment: CommunitySegment = .colors
    @State private var reportTarget: CommunityFeedModel.ReportTarget?

    public init(id: CommunityRecordID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    private var isMine: Bool { community.currentUserRecordID == id }

    private var status: CommunityFeedStatus {
        CommunityFeedStatus.resolve(
            isConnected: community.isConnected,
            isSignedIn: community.isUserSignedIn,
            isLoading: !hasLoaded,
            itemCount: segment == .colors ? colors.count : palettes.count,
            hasError: didFail,
            isSearching: false
        )
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.lg) {
                header
                segmentPicker
                content
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.bottom, Brand.Space.xxl)
            .frame(maxWidth: .infinity)
        }
        .background(groupedBackground)
        .softScrollEdgesIfAvailable()
        .refreshable { await load() }
        .navigationTitle(displayName)
        .toolbarTitleDisplayMode(.inline)
        .task(id: id) { await load() }
        .sheet(item: $reportTarget) { target in
            ReportItemSheet(id: target.id, type: target.type)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: status)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Brand.Space.md) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(.largeTitle, weight: .semibold))
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient.opaliteHorizontal)
                .padding(Brand.Space.md)
                .background(Circle().fill(.ultraThinMaterial))
                .accessibilityHidden(true)

            VStack(spacing: Brand.Space.xs) {
                Text(displayName)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                if isMine {
                    Text("This is you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: Brand.Space.md) {
                statPill(Text("^[\(colors.count) color](inflect: true)"), systemImage: "paintpalette.fill", tint: .opalitePurple)
                statPill(Text("^[\(palettes.count) palette](inflect: true)"), systemImage: "swatchpalette.fill", tint: .opaliteBlue)
            }
        }
        .padding(.vertical, Brand.Space.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func statPill(_ text: Text, systemImage: String, tint: Color) -> some View {
        Label {
            text
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint.gradient)
        }
        .padding(.horizontal, Brand.Space.md)
        .padding(.vertical, Brand.Space.sm)
        .statPillBackground()
        .accessibilityElement(children: .combine)
    }

    private var segmentPicker: some View {
        Picker("Content", selection: $segment) {
            ForEach(CommunitySegment.allCases) { segment in
                Label(segment.title, systemImage: segment.systemImage)
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: Brand.readableWidth)
        .onChange(of: segment) { Haptics.selection() }
        .accessibilityIdentifier("community.publisher.segmentPicker")
    }

    // MARK: - Content

    @ContentBuilder
    private var content: some View {
        switch status {
        case .loading:
            CommunitySkeletonGrid(segment: segment)
                .transition(.opacity)
        case .content:
            switch segment {
            case .colors:
                CommunityColorGrid(colors: colors) { reportTarget = $0 }
            case .palettes:
                CommunityPaletteGrid(palettes: palettes) { reportTarget = $0 }
            }
        case .empty:
            switch segment {
            case .colors:
                EmptyStateView("No Colors", systemImage: "paintpalette", description: String(localized: "\(displayName) hasn't shared any colors yet."))
                    .padding(.top, Brand.Space.xl)
            case .palettes:
                EmptyStateView("No Palettes", systemImage: "swatchpalette", description: String(localized: "\(displayName) hasn't shared any palettes yet."))
                    .padding(.top, Brand.Space.xl)
            }
        case .offline, .signedOut, .failed, .noResults:
            CommunityStateView(status: status, segment: segment, searchText: "", onRetry: { await load() }, onGoToPortfolio: {})
        }
    }

    // MARK: - Loading

    private func load() async {
        didFail = false
        guard let content = await community.publisherContent(id) else {
            didFail = true
            hasLoaded = true
            return
        }
        colors = content.colors
        palettes = content.palettes
        hasLoaded = true
        for palette in content.palettes where !palette.hasLoadedColors {
            let loaded = await community.paletteColors(palette)
            guard !Task.isCancelled else { return }
            if let index = palettes.firstIndex(where: { $0.id == palette.id }) {
                palettes[index].colors = loaded
            }
        }
    }
}

#if DEBUG
#Preview("Publisher") {
    NavigationStack {
        CommunityPublisherProfileView(id: CommunityRecordID(recordName: "sample-user-1"), displayName: "Sample User")
            .navigationDestination(for: CommunityDestination.self) { CommunityDestinationView(destination: $0) }
    }
    .previewEnvironment()
}
#endif
#endif
