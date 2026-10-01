//
//  TVSearchView.swift
//  OpaliteFeatureTV
//
//  Search the portfolio by name, hex, notes or tag, with a scope for colors or palettes.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVSearchView: View {
    @Environment(PortfolioModel.self) private var portfolio

    @State private var query = ""
    @State private var scope: TVSearchScope = .all

    private var colorResults: [OpaliteColor] {
        scope.includesColors ? TVSearchFilter.colors(portfolio.colors, matching: query) : []
    }

    private var paletteResults: [OpalitePalette] {
        scope.includesPalettes ? TVSearchFilter.palettes(portfolio.activePalettes, matching: query) : []
    }

    var body: some View {
        NavigationStack {
            Group {
                if PortfolioSearch.normalized(query).isEmpty {
                    ContentUnavailableView(
                        "Search Your Portfolio",
                        systemImage: "magnifyingglass",
                        description: Text("Find colors by name, hex code or notes, and palettes by name or tag.")
                    )
                } else if colorResults.isEmpty && paletteResults.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    results
                }
            }
            .searchable(text: $query, prompt: Text("Name, hex code, or tag"))
            .navigationTitle("Search")
            .navigationDestination(for: PortfolioDestination.self) { destination in
                TVDestinationView(destination: destination)
            }
        }
    }

    private var results: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Brand.Space.xxl) {
                Picker("Show", selection: $scope) {
                    Text("All").tag(TVSearchScope.all)
                    Text("Colors").tag(TVSearchScope.colors)
                    Text("Palettes").tag(TVSearchScope.palettes)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 640)
                .padding(.horizontal, TVLayout.gutter)
                .accessibilityIdentifier("searchScope")

                if !colorResults.isEmpty {
                    VStack(alignment: .leading, spacing: Brand.Space.xs) {
                        TVSectionHeader(title: "Colors", subtitle: "\(colorResults.count)")
                        TVSwatchRow(colors: colorResults)
                    }
                }

                if !paletteResults.isEmpty {
                    VStack(alignment: .leading, spacing: Brand.Space.xl) {
                        TVSectionHeader(title: "Palettes", subtitle: "\(paletteResults.count)")
                        ForEach(paletteResults) { palette in
                            TVPaletteRow(palette: palette)
                        }
                    }
                }
            }
            .padding(.vertical, Brand.Space.xl)
        }
        .scrollClipDisabled()
    }
}

#if DEBUG
#Preview {
    TVSearchView()
        .previewEnvironment()
}
#endif
#endif
