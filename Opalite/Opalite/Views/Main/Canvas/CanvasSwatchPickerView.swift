//
//  CanvasSwatchPickerView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/20/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CanvasSwatchPickerView: View {
    @Environment(ColorManager.self) private var colorManager

    let onColorSelected: (OpaliteColor) -> Void

    private let swatchSize: CGFloat = 44

    // Track which color was just selected for checkmark animation
    @State private var selectedColorID: UUID? = nil

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
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onColorSelected(color)

            // Show checkmark briefly
            withAnimation(.linear(duration: 0.15)) {
                selectedColorID = color.id
            }

            // Hide checkmark after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.linear(duration: 0.15)) {
                    selectedColorID = nil
                }
            }
        } label: {
            SwatchView(
                fill: [color],
                width: swatchSize,
                height: swatchSize,
                badgeText: "",
                showOverlays: false
            )
            .overlay {
                if selectedColorID == color.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color.idealTextColor())
                        .shadow(color: color.idealTextColor().opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
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
