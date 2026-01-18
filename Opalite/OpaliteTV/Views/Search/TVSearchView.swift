//
//  TVSearchView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Search view for tvOS with voice input support.
/// Allows searching colors and palettes..
struct TVSearchView: View {
    @Environment(ColorManager.self) private var colorManager

    @State private var searchText: String = ""
    @State private var selectedFilter: SearchFilter = .all

    private var filteredColors: [OpaliteColor] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return colorManager.colors.filter { color in
            (color.name?.lowercased().contains(query) ?? false) ||
            color.hexString.lowercased().contains(query)
        }
    }

    private var filteredPalettes: [OpalitePalette] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return colorManager.palettes.filter { palette in
            palette.name.lowercased().contains(query) ||
            palette.tags.contains { $0.lowercased().contains(query) }
        }
    }

    private var hasResults: Bool {
        !filteredColors.isEmpty || !filteredPalettes.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Tabs
                HStack(spacing: 20) {
                    ForEach(SearchFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.headline)
                                .foregroundStyle(selectedFilter == filter ? .primary : .secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    selectedFilter == filter ?
                                    Color.accentColor.opacity(0.2) :
                                    Color.clear,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)

                Divider()
                    .padding(.vertical, 16)

                // Results
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Opalite",
                        systemImage: "magnifyingglass",
                        description: Text("Search for colors by name or hex code or palettes by name.")
                    )
                    .frame(maxHeight: .infinity)
                } else if !hasResults {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No matches found for \"\(searchText)\"")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            // Colors Results
                            if (selectedFilter == .all || selectedFilter == .colors) && !filteredColors.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Colors (\(filteredColors.count))")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .padding(.leading, 48)

                                    TVSwatchRowView(
                                        colors: filteredColors,
                                        swatchSize: .medium
                                    )
                                }
                            }

                            // Palettes Results
                            if (selectedFilter == .all || selectedFilter == .palettes) && !filteredPalettes.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Palettes (\(filteredPalettes.count))")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .padding(.leading, 48)

                                    ForEach(filteredPalettes) { palette in
                                        TVPaletteRowView(palette: palette, swatchSize: .medium)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search colors, or palettes...")
            .navigationTitle("Search")
        }
    }
}

// MARK: - Search Filter

enum SearchFilter: CaseIterable {
    case all
    case colors
    case palettes

    var title: String {
        switch self {
        case .all: return "All"
        case .colors: return "Colors"
        case .palettes: return "Palettes"
        }
    }
}

#Preview {
    TVSearchView()
}
