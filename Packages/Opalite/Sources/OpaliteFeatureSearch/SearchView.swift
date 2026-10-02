//
//  SearchView.swift
//  OpaliteFeatureSearch
//
//  The Search tab: system search in the toolbar (minimizing on iOS 26), suggestion chips
//  (recent searches, then the color families actually in the portfolio) and recent colors
//  while idle, and grouped color / palette results while typing. Results open the same
//  Portfolio detail destinations; the engine behind it is pure and host-tested.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

public struct SearchView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(RecentSearches.storageKey) private var recentData = Data()
    @State private var query = ""
    @State private var isSearchPresented = false

    public init() {}

    // MARK: - Snapshots

    private var colors: [SearchableColor] {
        _ = portfolio.changeStamp
        return portfolio.colors.map { SearchableColor(id: $0.id, name: $0.name, notes: $0.notes, rgba: $0.rgba, updatedAt: $0.updatedAt) }
    }

    private var palettes: [SearchablePalette] {
        _ = portfolio.changeStamp
        return portfolio.orderedPalettes.map {
            SearchablePalette(id: $0.id, name: $0.name, notes: $0.notes, tags: $0.tags, colorValues: portfolio.colors(in: $0).map(\.rgba))
        }
    }

    private var recent: RecentSearches { RecentSearches.decode(recentData) }
    private var families: [String] { SearchEngine.familySuggestions(for: colors) }
    private var isIdle: Bool { SearchEngine.isBlank(query) }
    private var results: SearchResults { SearchEngine.results(query: query, colors: colors, palettes: palettes) }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 96 : 120), spacing: Brand.Space.md)]
    }

    public var body: some View {
        ScrollView {
            Group {
                if portfolio.isEmpty {
                    EmptyStateView(String(localized: "Nothing to Search Yet"), systemImage: "magnifyingglass", description: String(localized: "Save a few colors and palettes in your Portfolio, then find them here by name, hex code, notes, tag, or color family."))
                        .padding(.top, Brand.Space.xxl)
                } else if isIdle {
                    idle
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, Brand.Space.xxl)
                } else {
                    resultsContent
                }
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.bottom, Brand.Space.xxl)
            .frame(maxWidth: Brand.detailMaxWidth)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .snappy, value: isIdle)
        }
        .background(groupedBackground)
        .softScrollEdgesIfAvailable()
        .navigationTitle("Search")
        .searchable(text: $query, isPresented: $isSearchPresented, prompt: Text("Name, hex code, notes, or tag"))
        .searchSuggestions {
            ForEach(SearchEngine.completions(for: query, families: families), id: \.self) { completion in
                Label(completion, systemImage: "paintpalette")
                    .searchCompletion(completion)
            }
        }
        .onSubmit(of: .search) { remember(query) }
        .minimizingSearchIfAvailable()
        .accessibilityIdentifier("searchView")
    }

    // MARK: - Idle

    private var idle: some View {
        VStack(alignment: .leading, spacing: Brand.Space.xl) {
            let chips = SearchEngine.suggestions(recentQueries: recent.queries, families: families)
            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: Brand.Space.sm) {
                    HStack {
                        sectionTitle(String(localized: "Suggestions"))
                        Spacer()
                        if !recent.queries.isEmpty {
                            Button("Clear Recents") {
                                Haptics.selection()
                                var updated = recent
                                updated.clear()
                                recentData = updated.encoded()
                            }
                            .font(.subheadline)
                            .buttonStyle(.borderless)
                        }
                    }
                    FlowLayout(spacing: Brand.Space.sm) {
                        ForEach(chips) { chip in
                            Button {
                                Haptics.selection()
                                query = chip.text
                                isSearchPresented = true
                                remember(chip.text)
                            } label: {
                                Label(chip.text, systemImage: chip.systemImage)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, Brand.Space.md)
                                    .padding(.vertical, Brand.Space.sm)
                                    .background(secondaryGroupedBackground, in: Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .hoverLift()
                            .contextMenu {
                                if chip.kind == .recent {
                                    Button(role: .destructive) {
                                        var updated = recent
                                        updated.remove(chip.text)
                                        recentData = updated.encoded()
                                    } label: {
                                        Label("Remove from Recents", systemImage: "trash")
                                    }
                                    .destructiveMenuItem()
                                }
                            }
                            .accessibilityHint(Text("Searches for \(chip.text)"))
                        }
                    }
                }
            }

            let recentColors = SearchEngine.recentColors(colors)
            if !recentColors.isEmpty {
                VStack(alignment: .leading, spacing: Brand.Space.sm) {
                    sectionTitle(String(localized: "Recently Updated"))
                    colorGrid(recentColors)
                }
            }
        }
        .padding(.top, Brand.Space.sm)
    }

    // MARK: - Results

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: Brand.Space.xl) {
            if !results.colors.isEmpty {
                VStack(alignment: .leading, spacing: Brand.Space.sm) {
                    sectionTitle(String(localized: "Colors"), count: results.colors.count)
                    colorGrid(results.colors)
                }
            }
            if !results.palettes.isEmpty {
                VStack(alignment: .leading, spacing: Brand.Space.sm) {
                    sectionTitle(String(localized: "Palettes"), count: results.palettes.count)
                    VStack(spacing: 0) {
                        ForEach(results.palettes) { palette in
                            paletteRow(palette)
                            if palette.id != results.palettes.last?.id { Divider().padding(.leading, Brand.Space.lg) }
                        }
                    }
                    .background(secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
                }
            }
        }
        .padding(.top, Brand.Space.sm)
        .accessibilityIdentifier("searchResults")
    }

    private func colorGrid(_ items: [SearchableColor]) -> some View {
        LazyVGrid(columns: columns, spacing: Brand.Space.md) {
            ForEach(items) { color in
                NavigationLink(value: PortfolioDestination.color(color.id)) {
                    VStack(alignment: .leading, spacing: Brand.Space.xs) {
                        ZStack {
                            if color.rgba.alpha < 1 { Checkerboard() }
                            RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous)
                                .fill(color.rgba.color)
                        }
                        .frame(height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.control, style: .continuous).strokeBorder(.white.opacity(0.35)))
                        Text(color.displayName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(hexCopy.formatted(color.hex))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverLift()
                .contextMenu {
                    Button {
                        hexCopy.copy(hex: color.hex)
                    } label: {
                        Label("Copy Hex", systemImage: "number")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(color.hasName ? "\(color.displayName), \(color.hex)" : String(localized: "Unnamed color, \(color.hex)")))
                .accessibilityHint(Text("Opens the color"))
            }
        }
    }

    private func paletteRow(_ palette: SearchablePalette) -> some View {
        NavigationLink(value: PortfolioDestination.palette(palette.id)) {
            HStack(spacing: Brand.Space.md) {
                HStack(spacing: 0) {
                    if palette.colorValues.isEmpty {
                        Rectangle().fill(.quaternary)
                    } else {
                        ForEach(Array(palette.colorValues.prefix(4).enumerated()), id: \.offset) { _, rgba in
                            Rectangle().fill(rgba.color)
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous).strokeBorder(.quaternary))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(palette.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(paletteDetail(palette))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: Brand.Space.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Brand.Space.lg)
            .padding(.vertical, Brand.Space.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight()
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the palette"))
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, count: Int? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Brand.Space.sm) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let count {
                Text(count, format: .number)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func paletteDetail(_ palette: SearchablePalette) -> String {
        let count = palette.colorCount == 1 ? String(localized: "1 color") : String(localized: "\(palette.colorCount) colors")
        guard !palette.tags.isEmpty else { return count }
        return "\(count) · \(palette.tags.joined(separator: ", "))"
    }

    private func remember(_ text: String) {
        guard !SearchEngine.isBlank(text) else { return }
        var updated = recent
        updated.record(text)
        recentData = updated.encoded()
    }
}

#if DEBUG
#Preview("Search") {
    NavigationStack {
        SearchView()
    }
    .previewEnvironment()
}

#Preview("Empty portfolio") {
    NavigationStack {
        SearchView()
    }
    .previewEnvironment(seeded: false)
}
#endif
#endif
