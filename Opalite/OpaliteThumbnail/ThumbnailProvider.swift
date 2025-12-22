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
                handler(nil, ThumbnailError.invalidFormat)
                return
            }

            let pathExtension = request.fileURL.pathExtension.lowercased()

            if pathExtension == "opalitecolor" {
                // Single color thumbnail
                guard let color = decodeColor(from: json) else {
                    handler(nil, ThumbnailError.decodingFailed)
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
                    handler(nil, ThumbnailError.decodingFailed)
                    return
                }

                let colors = colorDicts.compactMap { decodeColor(from: $0) }

                let reply = QLThumbnailReply(contextSize: maximumSize, currentContextDrawing: { () -> Bool in
                    self.drawPaletteThumbnail(colors: colors, size: maximumSize)
                    return true
                })
                handler(reply, nil)
            } else {
                handler(nil, ThumbnailError.invalidFormat)
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

        // Draw gradient with all colors
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgColors = (colors.isEmpty ? [UIColor.systemGray4, UIColor.systemGray4] : colors).map { $0.cgColor }

        if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors as CFArray, locations: nil) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: insetRect.minX, y: insetRect.midY),
                end: CGPoint(x: insetRect.maxX, y: insetRect.midY),
                options: []
            )
        }

        // Restore state and draw border
        context.restoreGState()
        UIColor.systemGray4.setStroke()
        clipPath.lineWidth = 2
        clipPath.stroke()
    }
}
