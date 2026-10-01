//
//  ThumbnailProvider.swift
//  OpaliteThumbnail
//
//  Finder/Files thumbnails for .opalitecolor / .opalitepalette, drawn with Core Graphics
//  from the decoded color values.
//

import QuickLookThumbnailing
import UIKit
import OpaliteCore

nonisolated final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, (any Error)?) -> Void) {
        let size = request.maximumSize
        do {
            let data = try Data(contentsOf: request.fileURL)
            let colors: [RGBA]
            switch OpaliteFileCodec.kind(of: request.fileURL) {
            case .color: colors = [try OpaliteFileCodec.decodeColor(from: data).rgba]
            case .palette: colors = try OpaliteFileCodec.decodePalette(from: data).colors.map(\.rgba)
            case nil: throw OpaliteFileError.unsupportedExtension(request.fileURL.pathExtension)
            }
            handler(QLThumbnailReply(contextSize: size) {
                ThumbnailDrawing.draw(colors: colors, in: size)
                return true
            }, nil)
        } catch {
            handler(nil, error)
        }
    }
}

nonisolated enum ThumbnailDrawing {
    static func draw(colors: [RGBA], in size: CGSize) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        let radius = min(size.width, size.height) * 0.15
        let clip = UIBezierPath(roundedRect: rect, cornerRadius: radius)

        if colors.count == 1, let only = colors.first {
            only.uiColor.setFill()
            clip.fill()
        } else {
            context.saveGState()
            clip.addClip()
            UIColor.systemBackground.setFill()
            context.fill(rect)
            let inset = rect.insetBy(dx: 6, dy: 6)
            let layout = PalettePreviewLayout.calculate(colorCount: colors.count, availableWidth: inset.width, availableHeight: inset.height, minSpacing: 3, maxSpacing: 3, maxRows: 3)
            let gridWidth = CGFloat(layout.columns) * layout.swatchSize + CGFloat(max(layout.columns - 1, 0)) * layout.horizontalSpacing
            let gridHeight = CGFloat(layout.rows) * layout.swatchSize + CGFloat(max(layout.rows - 1, 0)) * layout.verticalSpacing
            let startX = inset.minX + (inset.width - gridWidth) / 2
            let startY = inset.minY + (inset.height - gridHeight) / 2
            for (index, color) in colors.enumerated() where layout.columns > 0 {
                let row = index / layout.columns, column = index % layout.columns
                let swatch = CGRect(
                    x: startX + CGFloat(column) * (layout.swatchSize + layout.horizontalSpacing),
                    y: startY + CGFloat(row) * (layout.swatchSize + layout.verticalSpacing),
                    width: layout.swatchSize, height: layout.swatchSize
                )
                let path = UIBezierPath(roundedRect: swatch, cornerRadius: layout.swatchSize * 0.15)
                color.uiColor.setFill()
                path.fill()
            }
            context.restoreGState()
        }
        UIColor.systemGray4.setStroke()
        clip.lineWidth = 2
        clip.stroke()
    }
}

nonisolated private extension RGBA {
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
}
