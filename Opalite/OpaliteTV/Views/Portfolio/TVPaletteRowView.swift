//
//  TVPaletteRowView.swift
//  OpaliteTV
//
//  Created by Nick Molargik on 1/18/26.
//

import SwiftUI

/// A palette row with header and horizontal scrolling swatches for tvOS.
/// Tapping the header navigates to the palette detail view.
struct TVPaletteRowView: View {
    let palette: OpalitePalette
    let swatchSize: SwatchSize

    @FocusState private var isHeaderFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Palette Header
            NavigationLink(destination: TVPaletteDetailView(palette: palette)) {
                HStack(spacing: 16) {
                    // Palette preview strip
                    HStack(spacing: 2) {
                        ForEach(palette.sortedColors.prefix(5)) { color in
                            Rectangle()
                                .fill(color.swiftUIColor)
                                .frame(width: 12, height: 32)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)

                    Text(palette.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(palette.colors?.count ?? 0) colors")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 48)
            }
            .buttonStyle(.plain)
            .focused($isHeaderFocused)
            .scaleEffect(isHeaderFocused ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHeaderFocused)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(palette.name), \(palette.colors?.count ?? 0) colors")
            .accessibilityHint("Opens palette details")
            .accessibilityAddTraits(.isButton)

            // Colors Row
            if let colors = palette.colors, !colors.isEmpty {
                TVSwatchRowView(
                    colors: palette.sortedColors,
                    swatchSize: swatchSize
                )
            } else {
                Text("No colors in this palette")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 48)
                    .accessibilityLabel("No colors in this palette")
            }
        }
    }
}

#Preview {
    TVPaletteRowView(palette: OpalitePalette.sample, swatchSize: .medium)
}
