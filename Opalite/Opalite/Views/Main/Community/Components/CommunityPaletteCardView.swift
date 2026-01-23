//
//  CommunityPaletteCardView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

/// A palette card that displays colors in a SwatchRowView-like horizontal scroll
struct CommunityPaletteCardView: View {
    let palette: CommunityPalette

    // Color blindness simulation
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw: String = ColorBlindnessMode.off.rawValue

    private var colorBlindnessMode: ColorBlindnessMode {
        ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off
    }

    private let swatchSize: CGFloat = 75

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // SwatchRowView-style horizontal scroll of colors
            if !palette.colors.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(palette.colors) { color in
                            communitySwatchCell(for: color)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                }
                .scrollClipDisabled()
            } else {
                // Fallback: show placeholder swatches with loading indicators
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<min(5, palette.colorCount), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.thinMaterial, lineWidth: 5)
                                )
                                .overlay {
                                    ProgressView()
                                        .tint(.secondary)
                                }
                                .frame(width: swatchSize, height: swatchSize)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                }
                .scrollClipDisabled()
            }

            // Info section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(palette.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text("by \(palette.publisherName)")
                        .font(.caption)
                        .lineLimit(1)

                    // Tags
                    if !palette.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(palette.tags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.2), in: Capsule())
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Stats
                HStack(spacing: 4) {
                    Image(systemName: "paintpalette")
                        .font(.caption)
                    Text("\(palette.colorCount)")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Swatch Cell (SwatchView-style for CommunityColor)

    @ViewBuilder
    private func communitySwatchCell(for color: CommunityColor) -> some View {
        let displayColor = simulateColorBlindness(for: color)

        RoundedRectangle(cornerRadius: 16)
            .fill(displayColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.thinMaterial, lineWidth: 5)
            )
            .frame(width: swatchSize, height: swatchSize)
    }

    private func simulateColorBlindness(for color: CommunityColor) -> Color {
        color.simulatedSwiftUIColor(colorBlindnessMode)
    }
}

#Preview {
    CommunityPaletteCardView(palette: CommunityPalette.sample)
        .padding()
}
