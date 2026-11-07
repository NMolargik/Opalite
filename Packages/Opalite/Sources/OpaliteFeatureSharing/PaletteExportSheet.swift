//
//  PaletteExportSheet.swift
//  OpaliteFeatureSharing
//
//  "Share Palette": the export flow for a palette. The PNG is rendered from
//  `PaletteExportImageView`; the PDF and the interchange formats come from `ExportService`
//  (the PDF is labeled with the Portfolio's author name).
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteServices

public struct PaletteExportSheet: View {
    private let palette: OpalitePalette
    @Environment(PortfolioModel.self) private var portfolio

    /// The palette paired as the dark-appearance variant for code exports, if any.
    @State private var darkPaletteID: UUID?

    public init(palette: OpalitePalette) {
        self.palette = palette
    }

    private static let imageSize = CGSize(width: 1200, height: 600)

    /// Formats whose output can carry a light and a dark value per color.
    private static let adaptiveFormats: Set<PaletteExportFormat> = [.css, .swiftui]

    /// Every other palette in the Portfolio, offered as a dark counterpart.
    private var darkCandidates: [OpalitePalette] {
        portfolio.palettes.filter { $0.id != palette.id && $0.colorCount > 0 }
    }

    private var darkPalette: OpalitePalette? {
        darkCandidates.first { $0.id == darkPaletteID }
    }

    public var body: some View {
        let userName = portfolio.authorName
        let darkPalette = darkPalette
        ExportSheet(
            title: String(localized: "Share Palette"),
            subject: palette.name,
            formats: ExportFormatCatalog.paletteFormats,
            optionsRevision: darkPaletteID,
            prepare: { format in
                try ExportService.exportPalette(
                    palette,
                    format: format,
                    imagePNG: format == .image ? Self.renderPNG(palette) : nil,
                    userName: userName.isEmpty ? String(localized: "User") : userName,
                    darkPalette: Self.adaptiveFormats.contains(format) ? darkPalette : nil
                )
            },
            previewPNG: { Self.renderPNG(palette, size: CGSize(width: 400, height: 200), scale: 2) },
            hero: {
                VStack(spacing: Brand.Space.sm) {
                    PaletteHero(name: palette.name, colors: palette.colorValues, background: palette.previewBackground)
                    Text("^[\(palette.colorCount) color](inflect: true)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .padding(.vertical, Brand.Space.sm)
            },
            options: { format in
                if let format, Self.adaptiveFormats.contains(format), !darkCandidates.isEmpty {
                    darkVariantSection(for: format)
                }
            },
            publishSheet: { PublishPaletteSheet(palette: palette) }
        )
    }

    /// "Dark variant": pair another palette so CSS gets a `prefers-color-scheme: dark`
    /// block and SwiftUI gets adaptive colors. Colors pair by position.
    private func darkVariantSection(for format: PaletteExportFormat) -> some View {
        Section {
            Picker(selection: $darkPaletteID) {
                Text("None").tag(UUID?.none)
                ForEach(darkCandidates, id: \.id) { candidate in
                    // The same label is reused as the row's value, so keep it to a strip
                    // and a name; the footer carries the paired count.
                    HStack(spacing: Brand.Space.sm) {
                        PaletteSwatchStrip(colors: candidate.colorValues)
                        Text(candidate.name)
                            .lineLimit(1)
                    }
                    .tag(UUID?.some(candidate.id))
                }
            } label: {
                HStack(spacing: Brand.Space.md) {
                    IconTile(systemImage: "circle.lefthalf.filled", tint: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dark variant")
                            .font(.body.weight(.medium))
                        Text("Pair a palette for dark appearance")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .pickerStyle(.navigationLink)
            .accessibilityIdentifier("sharing.export.darkVariant")
            .onChange(of: darkPaletteID) { Haptics.selection() }
        } header: {
            Text("Options")
        } footer: {
            if let darkPalette {
                let paired = min(palette.colorCount, darkPalette.colorCount)
                Text(format == .css
                    ? "\(darkPalette.name) fills a prefers-color-scheme: dark block. ^[\(paired) color](inflect: true) pair by position."
                    : "\(darkPalette.name) becomes the dark value of each adaptive Color. ^[\(paired) color](inflect: true) pair by position.")
            } else {
                Text("Colors pair by position with the palette you choose; without one, the file has a single value per color.")
            }
        }
    }

    private static func renderPNG(_ palette: OpalitePalette, size: CGSize = imageSize, scale: CGFloat? = nil) -> Data? {
        ImageRendering.png(PaletteExportImageView(palette: palette, size: size), size: size, scale: scale)
    }
}

/// A compact strip of a palette's colors for picker rows.
private struct PaletteSwatchStrip: View {
    let colors: [RGBA]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(colors.prefix(6).enumerated()), id: \.offset) { _, rgba in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(rgba.color)
                    .frame(width: 8, height: 18)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Share Palette") {
    Text("Host")
        .sharedSheet(isPresented: .constant(true)) {
            PaletteExportSheet(palette: .sample)
        }
        .previewEnvironment(hasOnyx: false)
}

#Preview("Share Palette · empty") {
    PaletteExportSheet(palette: OpalitePalette(name: "Empty"))
        .previewEnvironment(hasOnyx: true)
}
#endif
#endif
