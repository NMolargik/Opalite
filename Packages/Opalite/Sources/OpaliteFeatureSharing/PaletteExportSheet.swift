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

    public init(palette: OpalitePalette) {
        self.palette = palette
    }

    private static let imageSize = CGSize(width: 1200, height: 600)

    public var body: some View {
        let userName = portfolio.authorName
        ExportSheet(
            title: String(localized: "Share Palette"),
            subject: palette.name,
            formats: ExportFormatCatalog.paletteFormats,
            prepare: { format in
                try ExportService.exportPalette(
                    palette,
                    format: format,
                    imagePNG: format == .image ? Self.renderPNG(palette) : nil,
                    userName: userName.isEmpty ? String(localized: "User") : userName
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
            publishSheet: { PublishPaletteSheet(palette: palette) }
        )
    }

    private static func renderPNG(_ palette: OpalitePalette, size: CGSize = imageSize, scale: CGFloat? = nil) -> Data? {
        ImageRendering.png(PaletteExportImageView(palette: palette, size: size), size: size, scale: scale)
    }
}

#if DEBUG
#Preview("Share Palette") {
    Text("Host")
        .sheet(isPresented: .constant(true)) {
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
