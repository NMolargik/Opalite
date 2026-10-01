//
//  TVPaletteRow.swift
//  OpaliteFeatureTV
//
//  A palette as a top-shelf row: a focusable header that opens the palette, then its
//  colors on a horizontal shelf.
//

#if os(tvOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

struct TVPaletteRow: View {
    let palette: OpalitePalette

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Space.sm) {
            HStack {
                NavigationLink(value: PortfolioDestination.palette(palette.id)) {
                    HStack(spacing: Brand.Space.lg) {
                        TVPaletteStrip(colors: palette.colorValues)
                        Text(palette.name)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        Text("\(palette.colorCount) colors")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(Text("\(palette.name), \(palette.colorCount) colors"))
                .accessibilityHint(Text("Opens palette details"))
                Spacer()
            }
            .padding(.horizontal, TVLayout.gutter - Brand.Space.xl)

            if palette.colorCount == 0 {
                Text("No colors in this palette yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, TVLayout.gutter)
                    .padding(.vertical, Brand.Space.lg)
            } else {
                TVSwatchRow(colors: palette.sortedColors)
            }
        }
        .focusSection()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ScrollView {
            TVPaletteRow(palette: .sample)
        }
    }
    .previewEnvironment()
}
#endif
#endif
