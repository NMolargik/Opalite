//
//  ColorExportSheet.swift
//  OpaliteFeatureSharing
//
//  "Share Color": the export flow for one color. The PNG is rendered from
//  `ColorExportImageView`; every other format comes from `ExportService`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteServices

public struct ColorExportSheet: View {
    private let color: OpaliteColor

    public init(color: OpaliteColor) {
        self.color = color
    }

    public var body: some View {
        ExportSheet(
            title: String(localized: "Share Color"),
            subject: color.displayName,
            formats: ExportFormatCatalog.colorFormats,
            prepare: { format in
                try ExportService.exportColor(color, format: format, imagePNG: format == .image ? Self.renderPNG(color) : nil)
            },
            previewPNG: { Self.renderPNG(color, size: CGSize(width: 256, height: 256), scale: 2) },
            hero: {
                ColorHero(rgba: color.rgba, title: color.displayName)
                    .padding(.vertical, Brand.Space.sm)
            },
            publishSheet: { PublishColorSheet(color: color) }
        )
    }

    private static func renderPNG(_ color: OpaliteColor, size: CGSize = ImageRendering.defaultSize, scale: CGFloat? = nil) -> Data? {
        ImageRendering.png(ColorExportImageView(color: color, size: size), size: size, scale: scale)
    }
}

#if DEBUG
#Preview("Share Color") {
    Text("Host")
        .sheet(isPresented: .constant(true)) {
            ColorExportSheet(color: .sample)
        }
        .previewEnvironment(hasOnyx: false)
}

#Preview("Share Color · Onyx") {
    ColorExportSheet(color: OpaliteColor(name: nil, red: 0.9, green: 0.3, blue: 0.5, alpha: 0.6))
        .previewEnvironment(hasOnyx: true)
}
#endif
#endif
