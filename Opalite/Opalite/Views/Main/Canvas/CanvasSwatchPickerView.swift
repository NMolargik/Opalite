//
//  CanvasSwatchPickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/20/25.
//

import SwiftUI
import SwiftData

struct CanvasSwatchPickerView: View {
    @Environment(ColorManager.self) private var colorManager

    let onColorSelected: (OpaliteColor) -> Void

    private let swatchSize: CGFloat = 44

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // MARK: - Loose Colors Section
                if !colorManager.looseColors.isEmpty {
                    ForEach(colorManager.looseColors.sorted(by: { $0.updatedAt > $1.updatedAt }), id: \.id) { color in
                        swatchButton(for: color)
                    }

                    // Divider after loose colors if there are palettes
                    if !colorManager.palettes.isEmpty {
                        sectionDivider
                    }
                }

                // MARK: - Palette Sections
                ForEach(Array(colorManager.palettes.sorted(by: { $0.updatedAt > $1.updatedAt }).enumerated()), id: \.element.id) { index, palette in
                    let paletteColors = palette.colors?.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? []

                    if !paletteColors.isEmpty {
                        ForEach(paletteColors, id: \.id) { color in
                            swatchButton(for: color)
                        }

                        // Divider after each palette except the last
                        if index < colorManager.palettes.count - 1 {
                            sectionDivider
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: swatchSize + 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func swatchButton(for color: OpaliteColor) -> some View {
        Button {
            onColorSelected(color)
        } label: {
            SwatchView(
                fill: [color],
                width: swatchSize,
                height: swatchSize,
                badgeText: "",
                showOverlays: false
            )
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }

    private var sectionDivider: some View {
        Capsule()
            .fill(.secondary.opacity(0.4))
            .frame(width: 2, height: swatchSize * 0.6)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: OpaliteColor.self,
        OpalitePalette.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let colorManager = ColorManager(context: container.mainContext)
    do {
        try colorManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }

    return CanvasSwatchPickerView { color in
        print("Selected: \(color.hexString)")
    }
    .environment(colorManager)
    .padding(.top, 50)
}
