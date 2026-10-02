//
//  CommunityPaletteDetailView.swift
//  OpaliteFeatureCommunity
//
//  A published palette: a large swatch-grid hero (each swatch opens its color), info
//  tiles, the color list with copyable hex codes, tags, notes, and the publisher row.
//  Colors arrive after the palette record, so the hero shows placeholders until they do.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureSharing

public struct CommunityPaletteDetailView: View {
    let initialPalette: CommunityPalette

    @Environment(CommunityModel.self) private var community
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ScaledMetric(relativeTo: .largeTitle) private var heroHeight: CGFloat = 280
    @ScaledMetric(relativeTo: .body) private var chipSize: CGFloat = 40

    @State private var loadedColors: [CommunityColor]?
    @State private var isShowingReportSheet = false
    @State private var isConfirmingRemoval = false
    @State private var isColorsExpanded = true
    @State private var isPublisherExpanded = true
    @State private var isTagsExpanded = true

    public init(palette: CommunityPalette) {
        self.initialPalette = palette
    }

    /// The freshest copy: the feed's (colors load in place) or whatever this screen fetched.
    private var palette: CommunityPalette {
        var current = community.palettes.first { $0.id == initialPalette.id } ?? initialPalette
        if !current.hasLoadedColors, let loadedColors, !loadedColors.isEmpty {
            current.colors = loadedColors
        }
        return current
    }

    private var isMine: Bool { community.isMine(palette) }
    private var canSave: Bool { palette.hasLoadedColors }

    public var body: some View {
        ScrollView {
            VStack(spacing: Brand.Space.lg) {
                hero
                tiles
                colorsCard
                if !palette.tags.isEmpty {
                    tagsCard
                }
                if let notes = palette.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CommunityNotesCard(notes: notes)
                }
                publisherCard
                CommunitySaveButton(isEnabled: canSave) {
                    await community.save(palette, into: portfolio, router: router)
                }
                .padding(.top, Brand.Space.sm)
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.top, Brand.Space.sm)
            .padding(.bottom, Brand.Space.xxl)
            .communityDetailWidth()
        }
        .background(groupedBackground)
        .softScrollEdgesIfAvailable()
        .navigationTitle(palette.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
        .task(id: initialPalette.id) {
            guard !palette.hasLoadedColors else { return }
            loadedColors = await community.paletteColors(initialPalette)
        }
        .sharedSheet(isPresented: $isShowingReportSheet) {
            ReportItemSheet(id: palette.id, type: .palette)
        }
        .confirmationDialog("Remove this palette from the Community?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                Task {
                    await community.unpublish(palette)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It will no longer appear for anyone. Your copy in your Portfolio is unaffected.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
        CommunityPalettePreview(
            colors: palette.colors,
            colorCount: palette.colorCount,
            hasLoadedColors: palette.hasLoadedColors,
            maxRows: 3,
            badgeMinimumSize: horizontalSizeClass == .regular ? 96 : 120,
            opensColors: true
        )
        .padding(Brand.Space.md)
        .frame(height: heroHeight)
        .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
        .accessibilityLabel(Text("Palette preview, \(palette.name), \(palette.colorCount) colors"))
    }

    // MARK: - Tiles

    private var tiles: some View {
        CommunityInfoTileStrip(tiles: [
            .init(id: "count", title: String(localized: "Colors"), value: palette.colorCount.formatted(), systemImage: "swatchpalette.fill", tint: .opaliteBlue),
            .init(id: "publisher", title: String(localized: "Publisher"), value: palette.publisherName, systemImage: "person.fill", tint: .opalitePurple),
            .init(id: "published", title: String(localized: "Published"), value: palette.publishedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar", tint: .opaliteTan),
        ])
    }

    // MARK: - Cards

    private var colorsCard: some View {
        SectionCard(String(localized: "Colors"), systemImage: "paintpalette", isExpanded: $isColorsExpanded, trailing: {
            Text(palette.colorCount.formatted())
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }) {
            if palette.hasLoadedColors {
                VStack(spacing: 0) {
                    ForEach(Array(palette.colors.enumerated()), id: \.element.id) { index, color in
                        colorRow(color)
                        if index < palette.colors.count - 1 {
                            Divider().padding(.leading, chipSize + Brand.Space.md)
                        }
                    }
                }
            } else {
                HStack(spacing: Brand.Space.md) {
                    ProgressView().controlSize(.small)
                    Text("Loading colors…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Brand.Space.sm)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func colorRow(_ color: CommunityColor) -> some View {
        HStack(spacing: Brand.Space.md) {
            NavigationLink(value: CommunityDestination.color(color)) {
                HStack(spacing: Brand.Space.md) {
                    CommunitySwatch(color: color, cornerRadius: Brand.Radius.chip, showsBadge: false)
                        .frame(width: chipSize, height: chipSize)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(color.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(hexCopy.formatted(color.hexString))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverHighlight()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(color.displayName), \(color.hexString)"))
            .accessibilityHint(Text("Opens the color"))

            Button {
                hexCopy.copy(hex: color.hexString)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.footnote)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Copy hex for \(color.displayName)"))
        }
        .padding(.vertical, Brand.Space.sm)
    }

    private var tagsCard: some View {
        SectionCard(String(localized: "Tags"), systemImage: "tag", tint: .opaliteBlue, isExpanded: $isTagsExpanded) {
            FlowLayout(spacing: Brand.Space.sm) {
                ForEach(palette.tags, id: \.self) { tag in
                    CommunityTagChip(tag: tag)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Tags: \(palette.tags.joined(separator: ", "))"))
        }
    }

    private var publisherCard: some View {
        SectionCard(String(localized: "Publisher"), systemImage: "person", isExpanded: $isPublisherExpanded) {
            CommunityPublisherRow(id: palette.publisherUserRecordID, displayName: palette.publisherName, isMine: isMine)
        }
    }

    // MARK: - Toolbar

    private var moreMenu: some View {
        Menu {
            CommunityPaletteMenuItems(palette: palette, includesViewPublisher: true, onUnpublish: { isConfirmingRemoval = true }) {
                isShowingReportSheet = true
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .toolbarButtonTint()
        .accessibilityLabel(Text("More actions"))
        .accessibilityIdentifier("community.moreMenu")
    }
}

#if DEBUG
#Preview("Palette detail") {
    NavigationStack {
        CommunityPaletteDetailView(palette: .sample)
            .navigationDestination(for: CommunityDestination.self) { CommunityDestinationView(destination: $0) }
    }
    .previewEnvironment()
}
#endif
#endif
