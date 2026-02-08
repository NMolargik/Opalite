//
//  ThumbnailProvider.swift
//  OpaliteThumbnail
//
//  Created by Nick Molargik on 12/21/25.
//

import UIKit
import QuickLookThumbnailing

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {

        let maximumSize = request.maximumSize

        do {
            let data = try Data(contentsOf: request.fileURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                handler(nil, FileHandlerError.invalidFormat)
                return
            }

            let pathExtension = request.fileURL.pathExtension.lowercased()

            if pathExtension == "opalitecolor" {
                // Single color thumbnail
                guard let color = decodeColor(from: json) else {
                    handler(nil, FileHandlerError.decodingFailed)
                    return
                }

                let reply = QLThumbnailReply(contextSize: maximumSize, currentContextDrawing: { () -> Bool in
                    self.drawColorThumbnail(color: color, size: maximumSize)
                    return true
                })
                handler(reply, nil)

            } else if pathExtension == "opalitepalette" {
                // Palette thumbnail
                guard let colorDicts = json["colors"] as? [[String: Any]] else {
                    handler(nil, FileHandlerError.decodingFailed)
                    return
                }

                let colors = colorDicts.compactMap { decodeColor(from: $0) }

                let reply = QLThumbnailReply(contextSize: maximumSize, currentContextDrawing: { () -> Bool in
                    self.drawPaletteThumbnail(colors: colors, size: maximumSize)
                    return true
                })
                handler(reply, nil)
            } else {
                handler(nil, FileHandlerError.invalidFormat)
            }

        } catch {
            handler(nil, error)
        }
    }

    // MARK: - Color Decoding

    private func decodeColor(from json: [String: Any]) -> UIColor? {
        guard let red = json["red"] as? Double,
              let green = json["green"] as? Double,
              let blue = json["blue"] as? Double else {
            return nil
        }
        let alpha = json["alpha"] as? Double ?? 1.0
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: - Drawing

    private func drawColorThumbnail(color: UIColor, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        let cornerRadius: CGFloat = min(size.width, size.height) * 0.15
        let insetRect = rect.insetBy(dx: 2, dy: 2)

        let path = UIBezierPath(roundedRect: insetRect, cornerRadius: cornerRadius)

        // Fill with color
        color.setFill()
        path.fill()

        // Draw border
        UIColor.systemGray4.setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    private func drawPaletteThumbnail(colors: [UIColor], size: CGSize) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let rect = CGRect(origin: .zero, size: size)
        let cornerRadius: CGFloat = min(size.width, size.height) * 0.15
        let insetRect = rect.insetBy(dx: 2, dy: 2)

        let clipPath = UIBezierPath(roundedRect: insetRect, cornerRadius: cornerRadius)

        // Save state and clip
        context.saveGState()
        clipPath.addClip()

        // Draw background
        UIColor.systemBackground.setFill()
        context.fill(insetRect)

        // Draw swatch grid
        if !colors.isEmpty {
            let layout = calculateSwatchLayout(colorCount: colors.count, availableSize: insetRect.size)
            let totalGridWidth = CGFloat(layout.columns) * layout.swatchSize + CGFloat(layout.columns - 1) * layout.spacing
            let totalGridHeight = CGFloat(layout.rows) * layout.swatchSize + CGFloat(layout.rows - 1) * layout.spacing
            let startX = insetRect.minX + (insetRect.width - totalGridWidth) / 2
            let startY = insetRect.minY + (insetRect.height - totalGridHeight) / 2

            for (index, color) in colors.enumerated() {
                let row = index / layout.columns
                let col = index % layout.columns

                let x = startX + CGFloat(col) * (layout.swatchSize + layout.spacing)
                let y = startY + CGFloat(row) * (layout.swatchSize + layout.spacing)

                let swatchRect = CGRect(x: x, y: y, width: layout.swatchSize, height: layout.swatchSize)
                let swatchPath = UIBezierPath(roundedRect: swatchRect, cornerRadius: layout.swatchSize * 0.15)

                color.setFill()
                swatchPath.fill()

                UIColor.black.withAlphaComponent(0.1).setStroke()
                swatchPath.lineWidth = 1
                swatchPath.stroke()
            }
        }

        // Restore state and draw border
        context.restoreGState()
        UIColor.systemGray4.setStroke()
        clipPath.lineWidth = 2
        clipPath.stroke()
    }

    private struct SwatchLayout {
        let rows: Int
        let columns: Int
        let swatchSize: CGFloat
        let spacing: CGFloat
    }

    private func calculateSwatchLayout(colorCount: Int, availableSize: CGSize) -> SwatchLayout {
        guard colorCount > 0 else {
            return SwatchLayout(rows: 0, columns: 0, swatchSize: 0, spacing: 0)
        }

        let padding: CGFloat = 6
        let spacing: CGFloat = 3
        let usableWidth = availableSize.width - (padding * 2)
        let usableHeight = availableSize.height - (padding * 2)

        var bestLayout = SwatchLayout(rows: 1, columns: 1, swatchSize: 0, spacing: spacing)

        // Try 1-3 rows
        for rows in 1...3 {
            let columns = Int(ceil(Double(colorCount) / Double(rows)))

            let totalHSpacing = CGFloat(columns - 1) * spacing
            let totalVSpacing = CGFloat(rows - 1) * spacing

            let maxSwatchWidth = (usableWidth - totalHSpacing) / CGFloat(columns)
            let maxSwatchHeight = (usableHeight - totalVSpacing) / CGFloat(rows)

            let swatchSize = min(maxSwatchWidth, maxSwatchHeight)

            if swatchSize > bestLayout.swatchSize {
                bestLayout = SwatchLayout(rows: rows, columns: columns, swatchSize: swatchSize, spacing: spacing)
            }
        }

        return bestLayout
    }
}
