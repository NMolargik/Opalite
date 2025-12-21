//
//  SwatchBarView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import SwiftUI
import SwiftData

struct SwatchBarView: View {
    @Environment(ColorManager.self) private var colorManager
    
    @State private var copiedColorID: UUID? = nil
    @State private var expandedPalettes: Set<UUID> = []
    @State private var showingSwatchBarInfo: Bool = false
    
    private let swatchSize: CGFloat = 200

    var body: some View {
        NavigationStack {
            Group {
                if (colorManager.colors.isEmpty) {
                    ContentUnavailableView("No Colors Created", systemImage: "questionmark.square.dashed")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            // MARK: - Palette Sections (collapsible with sticky headers)
                            ForEach(colorManager.palettes.sorted(by: { $0.updatedAt > $1.updatedAt })) { palette in
                                let paletteColors = palette.colors?.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? []
                                if !paletteColors.isEmpty {
                                    Section {
                                        if expandedPalettes.contains(palette.id) {
                                            ForEach(paletteColors) { color in
                                                swatchCell(for: color)
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 4)
                                            }
                                        }
                                    } header: {
                                        sectionHeader(for: palette)
                                    }
                                }
                            }
                            
                            // MARK: - Loose Colors Section
                            if !colorManager.looseColors.isEmpty {
                                Section {
                                    ForEach(colorManager.looseColors.sorted(by: { $0.updatedAt > $1.updatedAt })) { color in
                                        swatchCell(for: color)
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                    }
                                } header: {
                                    looseColorsHeader
                                }
                            }
                        }
                    }
                }
            }
            .background(.ultraThinMaterial)
            .navigationTitle("Opalite SwatchBar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem {
                    Button {
                        showingSwatchBarInfo = true
                    } label: {
                        Label("Info", systemImage: "info")
                    }
                    .tint(.blue)
                }
            }
            .sheet(isPresented: $showingSwatchBarInfo) {
                Text("SwatchBar is intended for creators to quickly reference their colors and palettes. Colors can be sampled, or tapped / clicked to copy their color code.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .presentationDetents([.fraction(0.2)])
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(for palette: OpalitePalette) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedPalettes.contains(palette.id) {
                    expandedPalettes.remove(palette.id)
                } else {
                    expandedPalettes.insert(palette.id)
                }
            }
        } label: {
            HStack {
                Label(palette.name, systemImage: "swatchpalette")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .rotationEffect(expandedPalettes.contains(palette.id) ? .degrees(90) : .zero)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .buttonStyle(.plain)
    }

    private var looseColorsHeader: some View {
        HStack {
            Label("Colors", systemImage: "paintpalette")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func swatchCell(for color: OpaliteColor) -> some View {
        SwatchView(
            fill: [color],
            width: swatchSize,
            height: swatchSize,
            badgeText: color.name ?? color.hexString,
            showOverlays: true
        )
        .overlay {
            // Copy feedback overlay
            if copiedColorID == color.id {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "number")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(color.idealTextColor())
                    }
                    .transition(.opacity)
            }
        }
        .onTapGesture {
            handleTap(for: color)
        }
        .contextMenu {
            Text(color.name ?? color.hexString)

            Button {
                copyHexWithFeedback(for: color)
            } label: {
                Label("Copy Hex", systemImage: "number")
            }
        }
    }

    private func handleTap(for color: OpaliteColor) {
        // Copy hex to clipboard
        copyHexWithFeedback(for: color)

        // Also set the canvas color for any open CanvasView
        colorManager.selectedCanvasColor = color
    }

    private func copyHexWithFeedback(for color: OpaliteColor) {
        copyHex(for: color)

        // Show feedback overlay
        withAnimation(.easeIn(duration: 0.1)) {
            copiedColorID = color.id
        }

        // Hide after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                copiedColorID = nil
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    try? manager.loadSamples()

    return SwatchBarView()
        .environment(manager)
        .modelContainer(container)
}
