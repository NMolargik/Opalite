//
//  CommunityFeedGrid.swift
//  OpaliteFeatureCommunity
//
//  The adaptive card grids shared by the Community feed and publisher profiles: each
//  card pushes a `CommunityDestination` and carries a context menu with the secondary
//  actions (save, view publisher, report, and unpublish for the user's own items).
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

// MARK: - Grids

struct CommunityColorGrid: View {
    let colors: [CommunityColor]
    let onReport: (CommunityFeedModel.ReportTarget) -> Void
    var footer: (() -> CommunityLoadingFooter)? = nil

    @Environment(CommunityModel.self) private var community
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var pendingRemoval: CommunityColor?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: CommunityGridMetrics.columnMinimum(for: .colors, isRegularWidth: horizontalSizeClass == .regular), maximum: 320), spacing: Brand.Space.lg)]
    }

    var body: some View {
        // A lazy stack so the footer's `.task` fires only when it scrolls into view.
        LazyVStack(spacing: Brand.Space.lg) {
            LazyVGrid(columns: columns, spacing: Brand.Space.lg) {
                ForEach(colors) { color in
                    NavigationLink(value: CommunityDestination.color(color)) {
                        CommunityColorCard(color: color)
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                    .contextMenu {
                        CommunityColorMenuItems(color: color, includesViewPublisher: true, onUnpublish: { pendingRemoval = color }) {
                            onReport(.init(id: color.id, type: .color))
                        }
                    }
                }
            }
            if let footer {
                footer()
            }
        }
        .communityRemovalDialog(item: $pendingRemoval, title: Text("Remove this color from the Community?")) { color in
            await community.unpublish(color)
        }
    }
}

struct CommunityPaletteGrid: View {
    let palettes: [CommunityPalette]
    let onReport: (CommunityFeedModel.ReportTarget) -> Void
    var footer: (() -> CommunityLoadingFooter)? = nil

    @Environment(CommunityModel.self) private var community
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var pendingRemoval: CommunityPalette?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: CommunityGridMetrics.columnMinimum(for: .palettes, isRegularWidth: horizontalSizeClass == .regular), maximum: 520), spacing: Brand.Space.lg)]
    }

    var body: some View {
        LazyVStack(spacing: Brand.Space.lg) {
            LazyVGrid(columns: columns, spacing: Brand.Space.lg) {
                ForEach(palettes) { palette in
                    NavigationLink(value: CommunityDestination.palette(palette)) {
                        CommunityPaletteCard(palette: palette)
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                    .contextMenu {
                        CommunityPaletteMenuItems(palette: palette, includesViewPublisher: true, onUnpublish: { pendingRemoval = palette }) {
                            onReport(.init(id: palette.id, type: .palette))
                        }
                    }
                }
            }
            if let footer {
                footer()
            }
        }
        .communityRemovalDialog(item: $pendingRemoval, title: Text("Remove this palette from the Community?")) { palette in
            await community.unpublish(palette)
        }
    }
}

struct CommunitySkeletonGrid: View {
    let segment: CommunitySegment

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: CommunityGridMetrics.columnMinimum(for: segment, isRegularWidth: horizontalSizeClass == .regular), maximum: segment == .colors ? 320 : 520), spacing: Brand.Space.lg)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: Brand.Space.lg) {
            ForEach(0..<CommunityGridMetrics.placeholderCount(for: segment), id: \.self) { _ in
                CommunitySkeletonCard(segment: segment)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading"))
    }
}

// MARK: - Menu items

/// The secondary actions for a published color (context menus and the detail's More menu).
struct CommunityColorMenuItems: View {
    let color: CommunityColor
    var includesViewPublisher = true
    var onUnpublish: (() -> Void)? = nil
    let onReport: () -> Void

    @Environment(CommunityModel.self) private var community
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(HexCopyModel.self) private var hexCopy

    var body: some View {
        Button {
            Haptics.selection()
            community.save(color, into: portfolio, router: router)
        } label: {
            Label("Save to Portfolio", systemImage: "square.and.arrow.down")
        }

        Button {
            hexCopy.copy(hex: color.hexString)
        } label: {
            Label("Copy Hex", systemImage: "doc.on.doc")
        }

        if includesViewPublisher {
            NavigationLink(value: CommunityDestination.publisher(id: color.publisherUserRecordID, displayName: color.publisherName)) {
                Label("View Publisher", systemImage: "person.crop.circle")
            }
        }

        Divider()

        if community.isMine(color), let onUnpublish {
            Button(role: .destructive, action: onUnpublish) {
                Label("Remove from Community", systemImage: "trash")
            }
            .destructiveMenuItem()
        } else if !community.isMine(color) {
            Button(role: .destructive) {
                Haptics.selection()
                onReport()
            } label: {
                Label("Report…", systemImage: "flag")
            }
            .destructiveMenuItem()
        }
    }
}

struct CommunityPaletteMenuItems: View {
    let palette: CommunityPalette
    var includesViewPublisher = true
    var onUnpublish: (() -> Void)? = nil
    let onReport: () -> Void

    @Environment(CommunityModel.self) private var community
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            Haptics.selection()
            Task { await community.save(palette, into: portfolio, router: router) }
        } label: {
            Label("Save to Portfolio", systemImage: "square.and.arrow.down")
        }

        if includesViewPublisher {
            NavigationLink(value: CommunityDestination.publisher(id: palette.publisherUserRecordID, displayName: palette.publisherName)) {
                Label("View Publisher", systemImage: "person.crop.circle")
            }
        }

        Divider()

        if community.isMine(palette), let onUnpublish {
            Button(role: .destructive, action: onUnpublish) {
                Label("Remove from Community", systemImage: "trash")
            }
            .destructiveMenuItem()
        } else if !community.isMine(palette) {
            Button(role: .destructive) {
                Haptics.selection()
                onReport()
            } label: {
                Label("Report…", systemImage: "flag")
            }
            .destructiveMenuItem()
        }
    }
}

// MARK: - Removal confirmation

extension View {
    /// The destructive confirmation before unpublishing one of the user's own items.
    func communityRemovalDialog<Item: Identifiable & Equatable & Sendable>(
        item: Binding<Item?>,
        title: Text,
        onConfirm: @escaping (Item) async -> Void
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: item.wrappedValue
        ) { pending in
            Button("Remove", role: .destructive) {
                Task { await onConfirm(pending) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("It will no longer appear for anyone. Your copy in your Portfolio is unaffected.")
        }
    }
}

#if DEBUG
#Preview("Grids") {
    NavigationStack {
        ScrollView {
            VStack(spacing: 24) {
                CommunityColorGrid(colors: [.sample, .sample2]) { _ in }
                CommunityPaletteGrid(palettes: [.sample]) { _ in }
                CommunitySkeletonGrid(segment: .colors)
            }
            .padding()
        }
        .background(groupedBackground)
    }
    .previewEnvironment()
}
#endif
#endif
