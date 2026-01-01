//
//  SearchView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var selectedTab: Tabs

    @State private var searchText: String = ""
    @State private var isShowingPaywall: Bool = false
    @State private var isSearchPresented: Bool = false
    @FocusState private var isSearchFocused: Bool

    // MARK: - Filtered Results

    private var filteredColors: [OpaliteColor] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return colorManager.colors.filter { color in
            if let name = color.name, name.lowercased().contains(query) {
                return true
            }
            if color.hexString.lowercased().contains(query) {
                return true
            }
            return false
        }
    }

    private var filteredPalettes: [OpalitePalette] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return colorManager.palettes.filter { palette in
            palette.name.lowercased().contains(query)
        }
    }

    private var filteredCanvases: [CanvasFile] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return canvasManager.canvases.filter { canvas in
            canvas.title.lowercased().contains(query)
        }
    }

    private var hasResults: Bool {
        !filteredColors.isEmpty || !filteredPalettes.isEmpty || !filteredCanvases.isEmpty
    }

    // MARK: - Navigation

    private func openCanvas(_ canvas: CanvasFile) {
        guard subscriptionManager.hasOnyxEntitlement else {
            isShowingPaywall = true
            return
        }

        if horizontalSizeClass == .compact {
            // On iPhone, switch to canvas tab and request opening the canvas
            canvasManager.pendingCanvasToOpen = canvas
            selectedTab = .canvas
        } else {
            // On iPad, directly switch to the canvas body tab
            selectedTab = .canvasBody(canvas)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Opalite",
                        systemImage: "magnifyingglass",
                        description: Text("Search for colors, palettes, or canvases")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if !hasResults {
                    ContentUnavailableView.search(text: searchText)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    // MARK: - Colors Section
                    if !filteredColors.isEmpty {
                        Section {
                            ForEach(filteredColors) { color in
                                NavigationLink {
                                    ColorDetailView(color: color)
                                        .tint(.none)
                                } label: {
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(
                                                red: color.red,
                                                green: color.green,
                                                blue: color.blue,
                                                opacity: color.alpha
                                            ))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(color.name ?? color.hexString)
                                                .font(.body)
                                            if color.name != nil {
                                                Text(color.hexString)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            Label("Colors", systemImage: "paintpalette.fill")
                                .foregroundStyle(.blue)
                        }
                    }

                    // MARK: - Palettes Section
                    if !filteredPalettes.isEmpty {
                        Section {
                            ForEach(filteredPalettes) { palette in
                                NavigationLink {
                                    PaletteDetailView(palette: palette)
                                        .tint(.none)
                                } label: {
                                    HStack(spacing: 12) {
                                        // Mini palette preview
                                        HStack(spacing: 0) {
                                            ForEach(Array(palette.sortedColors.prefix(4)), id: \.id) { color in
                                                Rectangle()
                                                    .fill(Color(
                                                        red: color.red,
                                                        green: color.green,
                                                        blue: color.blue,
                                                        opacity: color.alpha
                                                    ))
                                            }
                                        }
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                                        )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(palette.name)
                                                .font(.body)
                                            Text("\(palette.colors?.count ?? 0) colors")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Label("Palettes", systemImage: "swatchpalette.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.purple, .orange, .red)
                        }
                    }

                    // MARK: - Canvases Section
                    if !filteredCanvases.isEmpty {
                        Section {
                            ForEach(filteredCanvases) { canvas in
                                Button {
                                    HapticsManager.shared.selection()
                                    openCanvas(canvas)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "scribble.variable")
                                            .font(.title2)
                                            .foregroundStyle(.red)
                                            .frame(width: 32, height: 32)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(canvas.title)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text(canvas.updatedAt, style: .relative)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .foregroundStyle(.inverseTheme)


                                        Spacer()

                                        if !subscriptionManager.hasOnyxEntitlement {
                                            Image(systemName: "lock.fill")
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        } header: {
                            Label("Canvases", systemImage: "pencil.and.scribble")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search")
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Color, palette, or canvas")
            .searchFocused($isSearchFocused)
            .onAppear {
                // Delay slightly to ensure the view is fully presented
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchPresented = true
                    isSearchFocused = true
                }

                #if targetEnvironment(macCatalyst)
                // Fix search bar styling issues on Mac Catalyst
                let searchBar = UISearchBar.appearance()
                searchBar.searchTextPositionAdjustment = UIOffset(horizontal: 0, vertical: 0)

                let searchTextField = UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self])
                searchTextField.focusEffect = nil
                searchTextField.contentVerticalAlignment = .center
                #endif
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(featureContext: "Canvas access requires Onyx")
            }
            #if targetEnvironment(macCatalyst)
            .focusEffectDisabled()
            #endif
        }
    }
}

#Preview("Search") {
    // In-memory container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpaliteColor.self,
            OpalitePalette.self,
            CanvasFile.self,
        configurations: config
    )

    let context = container.mainContext
    let colorManager = ColorManager(context: context)
    let canvasManager = CanvasManager(context: context)
    try? colorManager.loadSamples()
    try? canvasManager.loadSamples()

    return SearchView(selectedTab: .constant(.search))
        .modelContainer(container)
        .environment(colorManager)
        .environment(canvasManager)
        .environment(SubscriptionManager())
}
