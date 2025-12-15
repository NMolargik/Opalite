//
//  PortfolioView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI
import SwiftData

struct PortfolioView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(ColorManager.self) private var colorManager
    @State private var isColorsExpanded: Bool = true
    @State private var isPaletteExpanded: Bool = true
    @State private var paletteSelectionColor: OpaliteColor?

    var body: some View {
        ScrollView {
            if hSizeClass == .compact {
                compactView()
            } else {
                regularView()
            }
        }
        .refreshable {
            Task { await colorManager.refreshAll() }
        }
    }
    
    @ViewBuilder func compactView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(colorManager.palettes) { palette in
                VStack(alignment: .leading, spacing: 5) {
                    PaletteHeaderView(palette: palette)
                    
                    SwatchRowView(
                        colors: palette.colors ?? [],
                        swatchWidth: 75,
                        swatchHeight: 75,
                        showBadge: false,
                        contextMenuContent: { color in
                            AnyView(
                                Group {
                                    Button {
                                        copyHex(for: color)
                                    } label: {
                                        Label("Copy Hex", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button {
                                        // TODO: share color as image
                                    } label: {
                                        Label("Share As Image", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button {
                                        // TODO: share color data
                                    } label: {
                                        Label("Share Color", systemImage: "doc.on.doc")
                                    }
                                    
                                    Divider()

                                    Button(role: .destructive) {
                                        colorManager.detachColorFromPalette(color)
                                    } label: {
                                        Label("Remove From Palette", systemImage: "swatchpalette")
                                    }
                                }
                            )
                        }
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: {
                        do {
                            try colorManager.createPalette(name: "New Palette")
                        } catch {
                            // TODO: error handling
                        }
                    }, label: {
                        HStack {
                            Image(systemName: "swatchpalette.fill")
                            Text("New Palette")
                                .bold()
                        }
                    })
                    
                    Button(action: {
                        // TODO: show color creator
                    }, label: {
                        HStack {
                            Image(systemName: "paintpalette.fill")
                            Text("New Color")
                                .bold()
                        }
                    })
                } label: {
                    Text("Create")
                }
            }
        }
    }
    
    @ViewBuilder func regularView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Colors")
                    .font(.title)
                    .bold()
                    .padding(.leading, 20)
            }

            SwatchRowView(
                colors: colorManager.colors.filter({ $0.palette == nil }),
                swatchWidth: 175,
                swatchHeight: 150,
                showBadge: true,
                menuContent: { color in
                    AnyView(
                        Group {
                            Button {
                                copyHex(for: color)
                            } label: {
                                Label("Copy Hex", systemImage: "doc.on.doc")
                            }

                            Button {
                                paletteSelectionColor = color
                            } label: {
                                Label("Add To Palette", systemImage: "swatchpalette")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                do {
                                    try colorManager.deleteColor(color)
                                } catch {
                                    // TODO: error handling
                                }
                            } label: {
                                Label("Delete Color", systemImage: "trash.fill")
                            }
                        }
                    )
                }
            )
            
            Text("Palettes")
                .font(.title)
                .bold()
                .padding(.leading, 20)
            
            ForEach(colorManager.palettes) { palette in
                VStack(alignment: .leading, spacing: 5) {
                    PaletteHeaderView(palette: palette)
                    
                    SwatchRowView(
                        colors: palette.colors ?? [],
                        swatchWidth: 175,
                        swatchHeight: 150,
                        showBadge: true,
                        menuContent: { color in
                            AnyView(
                                Group {
                                    Button {
                                        copyHex(for: color)
                                    } label: {
                                        Label("Copy Hex", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button {
                                        // TODO: share color as image
                                    } label: {
                                        Label("Share As Image", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button {
                                        // TODO: share color data
                                    } label: {
                                        Label("Share Color", systemImage: "doc.on.doc")
                                    }
                                    
                                    Divider()

                                    Button(role: .destructive) {
                                        colorManager.detachColorFromPalette(color)
                                    } label: {
                                        Label("Remove From Palette", systemImage: "swatchpalette")
                                    }
                                }
                            )
                        }
                    )
                }
            }
        }
        .sheet(item: $paletteSelectionColor) { color in
            PaletteSelectionSheet(color: color)
                .environment(colorManager)
        }
    }
}

#Preview("Portfolio") {
    // In-memory SwiftData container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
            OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    do {
        try manager.loadSamples()
    } catch {
        print("Failed to load samples into context")
    }

    return PortfolioView()
        .environment(manager)
        .modelContainer(container)
}
