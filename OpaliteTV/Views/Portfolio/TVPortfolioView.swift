//
//  TVPortfolioView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// Main portfolio view displaying colors and palettes in a TV-optimized layout.
/// Colors and palettes are displayed in horizontal scrolling rows.
struct TVPortfolioView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    /// Fixed swatch size for tvOS
    private let swatchSize: SwatchSize = .medium

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Header
                    Text("Opalite")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 48)

                    // Loose Colors Section
                    if !colorManager.looseColors.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Colors")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.leading, 48)
                                .accessibilityAddTraits(.isHeader)

                            TVSwatchRowView(
                                colors: colorManager.looseColors,
                                swatchSize: swatchSize
                            )
                        }
                    }

                    // Palettes Section
                    if !colorManager.palettes.isEmpty {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Palettes")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.leading, 48)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(colorManager.palettes) { palette in
                                TVPaletteRowView(
                                    palette: palette,
                                    swatchSize: swatchSize
                                )
                            }
                        }
                    }

                    // Empty State
                    if colorManager.looseColors.isEmpty && colorManager.palettes.isEmpty {
                        ContentUnavailableView(
                            "No Colors Yet",
                            systemImage: "paintpalette",
                            description: Text("Create colors on your iPhone, iPad, or Mac and they'll sync here via iCloud.")
                        )
                        .padding(.top, 100)
                    }
                }
                .padding(.vertical, 40)
            }
        }
    }
}

#Preview {
    TVPortfolioView()
}
