//
//  ColorRecommendedColorsView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct ColorRecommendedColorsView: View {
    @Environment(HexCopyManager.self) private var hexCopyManager

    let baseColor: OpaliteColor
    let onCreateColor: (OpaliteColor) -> Void

    @State private var isShowingInfo = false
    @State private var actionFeedbackColorID: UUID?
    @State private var harmonyColors: [OpaliteColor] = []

    var body: some View {
        SectionCard(title: "Color Harmonies", systemImage: "paintpalette") {
            SwatchRowView(
                colors: harmonyColors,
                palette: nil,
                swatchWidth: 180,
                swatchHeight: 150,
                showOverlays: true,
                showsNavigation: false,
                menuContent: { color in
                    harmonyMenuContent(for: color)
                },
                contextMenuContent: { color in
                    harmonyMenuContent(for: color)
                },
                copiedColorID: $actionFeedbackColorID
            )
            .clipped()
        } trailing: {
            Button {
                HapticsManager.shared.selection()
                isShowingInfo = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Learn about color harmonies")
        }
        .sheet(isPresented: $isShowingInfo) {
            ColorHarmoniesInfoSheet()
        }
        .onAppear {
            if harmonyColors.isEmpty {
                harmonyColors = buildHarmonyColors()
            }
        }
    }

    private func harmonyMenuContent(for color: OpaliteColor) -> AnyView {
        AnyView(
            Group {
                Button {
                    HapticsManager.shared.selection()
                    hexCopyManager.copyHex(for: color)
                    withAnimation {
                        actionFeedbackColorID = color.id
                    }
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }

                Button {
                    HapticsManager.shared.selection()
                    onCreateColor(color)
                    withAnimation {
                        actionFeedbackColorID = color.id
                    }
                } label: {
                    let addSuffix: String = (baseColor.palette != nil) ? "To Palette" : "To Colors"
                    Label("Add \(addSuffix)", systemImage: "plus")
                }
            }
        )
    }

    private func buildHarmonyColors() -> [OpaliteColor] {
        var colors: [OpaliteColor] = []

        // Complementary (1)
        colors.append(baseColor.complementaryColor())

        // Analogous (2)
        colors.append(contentsOf: baseColor.analogousColors())

        // Triadic (2)
        colors.append(contentsOf: baseColor.triadicColors())

        // Split-Complementary (2)
        colors.append(contentsOf: baseColor.splitComplementaryColors())

        // Tetradic (3)
        colors.append(contentsOf: baseColor.tetradicColors())

        return colors
    }
}

// MARK: - Info Sheet

private struct ColorHarmoniesInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Color harmonies are combinations of colors that are aesthetically pleasing and work well together. They're based on the position of colors on the color wheel.")
                        .foregroundStyle(.secondary)

                    harmonySection(
                        name: "Complementary",
                        icon: "circle.lefthalf.filled",
                        color: .red,
                        description: "Colors directly opposite each other on the color wheel (180° apart). Creates high contrast and visual tension.",
                        example: "Red & Green, Blue & Orange"
                    )

                    harmonySection(
                        name: "Analogous",
                        icon: "circle.and.line.horizontal",
                        color: .orange,
                        description: "Colors adjacent to each other on the wheel (±30°). Creates a harmonious, cohesive feel with low contrast.",
                        example: "Blue, Blue-Green, Green"
                    )

                    harmonySection(
                        name: "Triadic",
                        icon: "triangle",
                        color: .yellow,
                        description: "Three colors evenly spaced on the wheel (120° apart). Offers strong visual contrast while retaining balance.",
                        example: "Red, Yellow, Blue"
                    )

                    harmonySection(
                        name: "Split-Complementary",
                        icon: "arrow.triangle.branch",
                        color: .green,
                        description: "A base color plus the two colors adjacent to its complement (150° & 210°). High contrast but less tension than complementary.",
                        example: "Blue, Yellow-Orange, Red-Orange"
                    )

                    harmonySection(
                        name: "Tetradic (Square)",
                        icon: "square",
                        color: .blue,
                        description: "Four colors evenly spaced on the wheel (90° apart). Rich color palette that works best when one color dominates.",
                        example: "Red, Yellow, Green, Blue"
                    )
                }
                .padding()
            }
            .navigationTitle("Color Harmonies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func harmonySection(
        name: String,
        icon: String,
        color: Color,
        description: String,
        example: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 30)

                Text(name)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("Example: \(example)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Recommended Colors") {
    ColorRecommendedColorsView(
        baseColor: OpaliteColor(
            name: "Base Color",
            red: 0.5,
            green: 0.3,
            blue: 0.7,
            alpha: 1.0
        ),
        onCreateColor: { _ in }
    )
    .padding()
    .environment(HexCopyManager())
}

#Preview("Info Sheet") {
    ColorHarmoniesInfoSheet()
}
