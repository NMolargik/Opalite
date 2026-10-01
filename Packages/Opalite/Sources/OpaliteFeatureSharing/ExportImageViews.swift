//
//  ExportImageViews.swift
//  OpaliteFeatureSharing
//
//  The static renderings behind every PNG Opalite shares: a single color card and a
//  palette grid card. Both are fixed-size so `ImageRendering.png(_:size:)` produces the
//  same picture on every device, and both are public so the Community can render palette
//  previews. The sheets reuse the same cards (responsively sized) as their live preview.
//

#if !os(watchOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

// MARK: - Public renderers

/// A single color as a share image: the color fills a rounded card with its name (or hex)
/// badged top-leading.
public struct ColorExportImageView: View {
    private let color: OpaliteColor
    private let size: CGSize

    public init(color: OpaliteColor, size: CGSize = ImageRendering.defaultSize) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        ColorCard(rgba: color.rgba, title: color.displayName, metrics: .export(for: size))
            .frame(width: size.width, height: size.height)
    }
}

/// A palette as a share image: its swatches on the palette's preview background, the
/// name badged top-leading, hex labels when the swatches are large enough to carry them.
public struct PaletteExportImageView: View {
    private let palette: OpalitePalette
    private let size: CGSize

    public init(palette: OpalitePalette, size: CGSize = CGSize(width: 1200, height: 600)) {
        self.palette = palette
        self.size = size
    }

    public var body: some View {
        PaletteGridCard(
            name: palette.name,
            colors: palette.colorValues,
            background: palette.previewBackground ?? .white,
            size: size,
            metrics: .export(for: size)
        )
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Metrics

/// Sizing for the cards: fixed, proportional values for exports (never Dynamic Type —
/// the PNG must look the same everywhere) and scaled values for on-screen previews.
struct CardMetrics {
    var cornerRadius: CGFloat
    var swatchCornerRadius: CGFloat
    var titleFont: Font
    var badgeFont: Font
    var inset: CGFloat
    var gridInset: CGFloat
    var minSpacing: CGFloat
    var maxSpacing: CGFloat
    var maxRows: Int
    var hexBadgeMinSize: CGFloat?
    var borderWidth: CGFloat

    static func export(for size: CGSize) -> CardMetrics {
        let unit = min(size.width, size.height)
        return CardMetrics(
            cornerRadius: unit * 0.0625,
            swatchCornerRadius: unit * 0.03,
            titleFont: .system(size: max(14, unit * 0.055), weight: .bold, design: .rounded),
            badgeFont: .system(size: max(10, unit * 0.026), weight: .semibold, design: .monospaced),
            inset: unit * 0.04,
            gridInset: unit * 0.16,
            minSpacing: unit * 0.03,
            maxSpacing: unit * 0.06,
            maxRows: 3,
            hexBadgeMinSize: unit * 0.2,
            borderWidth: max(2, unit * 0.006)
        )
    }

    /// On-screen previews: brand radii, semantic fonts.
    static let preview = CardMetrics(
        cornerRadius: Brand.Radius.card,
        swatchCornerRadius: Brand.Radius.chip,
        titleFont: .headline,
        badgeFont: .caption2.monospaced(),
        inset: Brand.Space.md,
        gridInset: Brand.Space.lg,
        minSpacing: 6,
        maxSpacing: 12,
        maxRows: 2,
        hexBadgeMinSize: nil,
        borderWidth: 1
    )
}

// MARK: - Color card

/// A rounded fill of one color with a legible title badge. `showsCheckerboard` reveals
/// translucency on screen; exports keep real alpha instead.
struct ColorCard: View {
    let rgba: RGBA
    let title: String
    var metrics: CardMetrics = .preview
    var showsCheckerboard = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        ZStack(alignment: .topLeading) {
            if showsCheckerboard, rgba.alpha < 1 {
                Checkerboard()
            }
            shape.fill(rgba.color)
            shape.strokeBorder(Color.white.opacity(0.3), lineWidth: metrics.borderWidth)
            CardBadge(text: title, onDark: !rgba.prefersDarkText, font: metrics.titleFont, cornerRadius: metrics.cornerRadius * 0.4)
                .padding(metrics.inset)
        }
        .clipShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(rgba.hexString)"))
    }
}

// MARK: - Palette card

/// The palette's swatches arranged by `PalettePreviewLayout` on its preview background.
struct PaletteGridCard: View {
    let name: String
    let colors: [RGBA]
    let background: PreviewBackground
    let size: CGSize
    var metrics: CardMetrics = .preview

    private var layout: PalettePreviewLayout {
        PalettePreviewLayout.calculate(
            colorCount: colors.count,
            availableWidth: size.width - metrics.gridInset * 2,
            availableHeight: size.height - metrics.gridInset * 2,
            minSpacing: metrics.minSpacing,
            maxSpacing: metrics.maxSpacing,
            maxRows: metrics.maxRows,
            hexBadgeMinSize: metrics.hexBadgeMinSize
        )
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
        let layout = layout
        ZStack(alignment: .topLeading) {
            shape.fill(background.color)
            shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: metrics.borderWidth)

            if colors.isEmpty {
                Text("This palette is empty")
                    .font(metrics.titleFont)
                    .foregroundStyle(background.idealTextColor.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                grid(layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            CardBadge(text: name, onDark: !background.prefersDarkText, font: metrics.titleFont, cornerRadius: metrics.cornerRadius * 0.4)
                .padding(metrics.inset)
        }
        .clipShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("^[\(colors.count) color](inflect: true) in \(name)"))
    }

    private func grid(_ layout: PalettePreviewLayout) -> some View {
        VStack(spacing: layout.verticalSpacing) {
            ForEach(0..<layout.rows, id: \.self) { row in
                HStack(spacing: layout.horizontalSpacing) {
                    ForEach(0..<layout.columns, id: \.self) { column in
                        if let index = layout.index(row: row, column: column, colorCount: colors.count) {
                            swatch(colors[index], size: layout.swatchSize, showsHex: layout.showHexBadges)
                        } else {
                            Color.clear.frame(width: layout.swatchSize, height: layout.swatchSize)
                        }
                    }
                }
            }
        }
    }

    private func swatch(_ rgba: RGBA, size: CGFloat, showsHex: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: metrics.swatchCornerRadius, style: .continuous)
        return shape
            .fill(rgba.color)
            .overlay(shape.strokeBorder(Color.white.opacity(0.3), lineWidth: metrics.borderWidth))
            .overlay(alignment: .topLeading) {
                if showsHex {
                    CardBadge(text: rgba.hexString, onDark: !rgba.prefersDarkText, font: metrics.badgeFont, cornerRadius: metrics.swatchCornerRadius * 0.5)
                        .padding(metrics.inset * 0.5)
                }
            }
            .frame(width: size, height: size)
    }
}

// MARK: - Badge

/// The translucent label on a card — black or white text over a soft scrim.
private struct CardBadge: View {
    let text: String
    let onDark: Bool
    let font: Font
    let cornerRadius: CGFloat

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .foregroundStyle(onDark ? .white : .black)
            .padding(.horizontal, Brand.Space.md)
            .padding(.vertical, Brand.Space.sm)
            .background((onDark ? Color.black : Color.white).opacity(0.22), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Responsive heroes (sheets)

/// The color card sized to its container — the live preview at the top of a sheet.
struct ColorHero: View {
    let rgba: RGBA
    let title: String
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 150

    var body: some View {
        ColorCard(rgba: rgba, title: title, showsCheckerboard: true)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}

/// The palette card sized to its container.
struct PaletteHero: View {
    let name: String
    let colors: [RGBA]
    let background: PreviewBackground?
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 170
    @State private var width: CGFloat = 320
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        PaletteGridCard(
            name: name,
            colors: colors,
            background: background ?? PreviewBackground.defaultFor(colorScheme: colorScheme),
            size: CGSize(width: width, height: height)
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Color export image") {
    ColorExportImageView(color: .sample, size: CGSize(width: 512, height: 512))
}

#Preview("Palette export image") {
    PaletteExportImageView(palette: .sample, size: CGSize(width: 600, height: 300))
}

#Preview("Heroes") {
    VStack(spacing: 16) {
        ColorHero(rgba: RGBA(red: 0.9, green: 0.3, blue: 0.5, alpha: 0.6), title: "Translucent Pink")
        PaletteHero(name: "Sample Palette", colors: OpalitePalette.sample.colorValues, background: nil)
    }
    .padding()
}
#endif
#endif
