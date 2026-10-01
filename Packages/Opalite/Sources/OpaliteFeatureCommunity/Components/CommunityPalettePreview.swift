//
//  CommunityPalettePreview.swift
//  OpaliteFeatureCommunity
//
//  A palette's colors laid out as the largest square swatches that fit (via
//  `PalettePreviewLayout`), with pulsing placeholder cells until the junction records
//  have loaded. Cards use it small and static; the detail hero uses it large and tappable.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct CommunityPalettePreview: View {
    let colors: [CommunityColor]
    let colorCount: Int
    let hasLoadedColors: Bool
    var maxRows = 2
    var badgeMinimumSize: CGFloat? = nil
    /// Wraps each swatch in a `NavigationLink` to its color (the detail hero).
    var opensColors = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var placeholderCount: Int { min(max(colorCount, 1), 8) }

    var body: some View {
        GeometryReader { proxy in
            let count = hasLoadedColors ? colors.count : placeholderCount
            let layout = PalettePreviewLayout.calculate(
                colorCount: count,
                availableWidth: proxy.size.width,
                availableHeight: proxy.size.height,
                maxRows: maxRows,
                hexBadgeMinSize: badgeMinimumSize
            )
            VStack(spacing: layout.verticalSpacing) {
                ForEach(0..<max(layout.rows, 0), id: \.self) { row in
                    HStack(spacing: layout.horizontalSpacing) {
                        ForEach(0..<layout.columns, id: \.self) { column in
                            if let index = layout.index(row: row, column: column, colorCount: count) {
                                cell(at: index, size: layout.swatchSize, showsBadge: layout.showHexBadges)
                            } else {
                                Color.clear.frame(width: layout.swatchSize, height: layout.swatchSize)
                            }
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear { if !reduceMotion { pulse = true } }
        .accessibilityElement(children: hasLoadedColors ? .contain : .ignore)
        .accessibilityLabel(hasLoadedColors ? Text("\(colorCount) colors") : Text("Loading \(colorCount) colors"))
    }

    @ContentBuilder
    private func cell(at index: Int, size: CGFloat, showsBadge: Bool) -> some View {
        if hasLoadedColors, index < colors.count {
            let color = colors[index]
            if opensColors {
                NavigationLink(value: CommunityDestination.color(color)) {
                    CommunitySwatch(color: color, showsBadge: showsBadge)
                        .frame(width: size, height: size)
                }
                .buttonStyle(.plain)
                .hoverLift()
                .accessibilityHint(Text("Opens this color"))
            } else {
                CommunitySwatch(color: color, showsBadge: showsBadge)
                    .frame(width: size, height: size)
            }
        } else {
            RoundedRectangle(cornerRadius: Brand.Radius.swatch, style: .continuous)
                .fill(.quaternary)
                .frame(width: size, height: size)
                .opacity(pulse ? 0.45 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("Loaded") {
    CommunityPalettePreview(colors: CommunityPalette.sample.colors, colorCount: 2, hasLoadedColors: true)
        .frame(height: 140)
        .padding()
}

#Preview("Loading") {
    CommunityPalettePreview(colors: [], colorCount: 5, hasLoadedColors: false)
        .frame(height: 140)
        .padding()
}
#endif
#endif
