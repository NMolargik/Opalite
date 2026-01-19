//
//  PortfolioPDFExporter.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

#if canImport(UIKit)
import UIKit

enum PortfolioPDFExporter {
    enum ExportError: Error {
        case couldNotWrite
    }

    // MARK: - Layout Constants
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @ 72dpi
    private static let margin: CGFloat = 40
    private static let contentWidth: CGFloat = 612 - 80 // pageWidth - 2*margin

    // MARK: - Text Styles
    private static let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
    private static let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
    private static let sectionFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    private static let paletteFont = UIFont.systemFont(ofSize: 14, weight: .medium)
    private static let colorNameFont = UIFont.systemFont(ofSize: 11, weight: .medium)
    private static let colorDetailFont = UIFont.systemFont(ofSize: 9, weight: .regular)

    /// Exports a single palette to PDF
    static func exportPalette(_ palette: OpalitePalette, userName: String) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let sanitizedName = palette.name.replacingOccurrences(of: "/", with: "-")
        let filename = "\(sanitizedName) Palette \(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0

            // Title Page
            ctx.beginPage()
            y = drawPaletteTitlePage(
                palette: palette,
                dateString: dateFormatter.string(from: Date()),
                userName: userName
            )

            let paletteColors = (palette.colors ?? []).sorted {
                ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
            }

            for color in paletteColors {
                y = ensureSpace(y: y, needed: 55, ctx: ctx)
                y = drawColorRow(color, at: y, indented: false)
            }

            if paletteColors.isEmpty {
                y = ensureSpace(y: y, needed: 40, ctx: ctx)
                let emptyAttrs: [NSAttributedString.Key: Any] = [
                    .font: subtitleFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                "No colors in this palette.".draw(at: CGPoint(x: margin, y: y), withAttributes: emptyAttrs)
            }
        }

        try data.write(to: url)
        return url
    }

    /// Exports all palettes and loose colors to PDF
    static func export(palettes: [OpalitePalette], looseColors: [OpaliteColor], userName: String) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let filename = "Opalite Portfolio \(Int(Date().timeIntervalSince1970)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0

            // MARK: - Title Page
            ctx.beginPage()
            y = drawTitlePage(dateString: dateFormatter.string(from: Date()),
                              paletteCount: palettes.count,
                              colorCount: looseColors.count + palettes.reduce(0) { $0 + ($1.colors?.count ?? 0) },
                              userName: userName)

            // MARK: - Palettes Section
            if !palettes.isEmpty {
                y = ensureSpace(y: y, needed: 60, ctx: ctx)
                y = drawSectionHeader("Palettes", at: y)

                let sortedPalettes = palettes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                for palette in sortedPalettes {
                    let paletteColors = (palette.colors ?? []).sorted {
                        ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
                    }

                    // Palette header needs ~30pt, each color row needs ~50pt
                    let neededHeight: CGFloat = 35 + CGFloat(min(paletteColors.count, 1)) * 50
                    y = ensureSpace(y: y, needed: neededHeight, ctx: ctx)
                    y = drawPaletteHeader(palette, colorCount: paletteColors.count, at: y)

                    for color in paletteColors {
                        y = ensureSpace(y: y, needed: 55, ctx: ctx)
                        y = drawColorRow(color, at: y, indented: true)
                    }

                    y += 15 // Space after palette
                }
            }

            // MARK: - Loose Colors Section
            if !looseColors.isEmpty {
                y = ensureSpace(y: y, needed: 60, ctx: ctx)
                y = drawSectionHeader("Loose Colors", at: y)

                let sortedColors = looseColors.sorted {
                    ($0.name ?? "Untitled").localizedCaseInsensitiveCompare($1.name ?? "Untitled") == .orderedAscending
                }

                for color in sortedColors {
                    y = ensureSpace(y: y, needed: 55, ctx: ctx)
                    y = drawColorRow(color, at: y, indented: false)
                }
            }

            // Empty state
            if palettes.isEmpty && looseColors.isEmpty {
                y = ensureSpace(y: y, needed: 40, ctx: ctx)
                let emptyAttrs: [NSAttributedString.Key: Any] = [
                    .font: subtitleFont,
                    .foregroundColor: UIColor.secondaryLabel
                ]
                "No colors or palettes to export.".draw(at: CGPoint(x: margin, y: y), withAttributes: emptyAttrs)
            }
        }

        try data.write(to: url)
        return url
    }

    // MARK: - Drawing Helpers

    private static func drawTitlePage(dateString: String, paletteCount: Int, colorCount: Int, userName: String) -> CGFloat {
        var y: CGFloat = 60

        // App title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]
        "Opalite Portfolio".draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 36

        // Subtitle with date
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        "Exported on \(dateString) by \(userName)".draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
        y += 18

        // Summary
        let summary = "\(paletteCount) palette\(paletteCount == 1 ? "" : "s"), \(colorCount) total color\(colorCount == 1 ? "" : "s")"
        summary.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
        y += 30

        // Divider line
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: margin, y: y))
        dividerPath.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        UIColor.separator.setStroke()
        dividerPath.lineWidth = 0.5
        dividerPath.stroke()

        return y + 20
    }

    private static func drawPaletteTitlePage(palette: OpalitePalette, dateString: String, userName: String) -> CGFloat {
        var y: CGFloat = 60
        let colorCount = palette.colors?.count ?? 0

        // Palette name as title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.label
        ]
        palette.name.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        y += 36

        // Subtitle with date
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        "Exported on \(dateString) by \(userName)".draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
        y += 18

        // Color count
        let summary = "\(colorCount) color\(colorCount == 1 ? "" : "s")"
        summary.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
        y += 18

        // Notes if available
        if let notes = palette.notes, !notes.isEmpty {
            let notesAttrs: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            let truncatedNotes = truncateText(notes, toWidth: contentWidth, font: subtitleFont)
            truncatedNotes.draw(at: CGPoint(x: margin, y: y), withAttributes: notesAttrs)
            y += 18
        }

        y += 12

        // Divider line
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: margin, y: y))
        dividerPath.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        UIColor.separator.setStroke()
        dividerPath.lineWidth = 0.5
        dividerPath.stroke()

        return y + 20
    }

    private static func drawSectionHeader(_ title: String, at y: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: sectionFont,
            .foregroundColor: UIColor.label
        ]
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        return y + 28
    }

    private static func drawPaletteHeader(_ palette: OpalitePalette, colorCount: Int, at y: CGFloat) -> CGFloat {
        // Palette name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: paletteFont,
            .foregroundColor: UIColor.label
        ]
        palette.name.draw(at: CGPoint(x: margin, y: y), withAttributes: nameAttrs)

        // Color count badge
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: colorDetailFont,
            .foregroundColor: UIColor.secondaryLabel
        ]
        let countText = "\(colorCount) color\(colorCount == 1 ? "" : "s")"
        let nameSize = (palette.name as NSString).size(withAttributes: nameAttrs)
        countText.draw(at: CGPoint(x: margin + nameSize.width + 10, y: y + 2), withAttributes: countAttrs)

        return y + 22
    }

    private static func drawColorRow(_ color: OpaliteColor, at y: CGFloat, indented: Bool) -> CGFloat {
        let leftX: CGFloat = indented ? margin + 20 : margin
        let swatchSize: CGFloat = 36

        // Draw swatch with rounded corners
        let swatchRect = CGRect(x: leftX, y: y, width: swatchSize, height: swatchSize)
        let swatchPath = UIBezierPath(roundedRect: swatchRect, cornerRadius: 6)

        color.uiColor.setFill()
        swatchPath.fill()

        UIColor.separator.setStroke()
        swatchPath.lineWidth = 0.5
        swatchPath.stroke()

        // Text area starts after swatch
        let textX = leftX + swatchSize + 12
        let textWidth = pageRect.width - margin - textX

        // Color name (or "Untitled")
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: colorNameFont,
            .foregroundColor: UIColor.label
        ]
        let displayName = color.name ?? "Untitled"
        let truncatedName = truncateText(displayName, toWidth: textWidth, font: colorNameFont)
        truncatedName.draw(at: CGPoint(x: textX, y: y), withAttributes: nameAttrs)

        // Color codes
        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: colorDetailFont,
            .foregroundColor: UIColor.secondaryLabel
        ]

        // HEX
        color.hexString.draw(at: CGPoint(x: textX, y: y + 13), withAttributes: codeAttrs)

        // RGB
        let rgbText = String(format: "RGB(%d, %d, %d)",
                             Int(round(color.red * 255)),
                             Int(round(color.green * 255)),
                             Int(round(color.blue * 255)))
        let hexSize = (color.hexString as NSString).size(withAttributes: codeAttrs)
        rgbText.draw(at: CGPoint(x: textX + hexSize.width + 12, y: y + 13), withAttributes: codeAttrs)

        // HSL
        color.hslString.draw(at: CGPoint(x: textX, y: y + 24), withAttributes: codeAttrs)

        // Alpha if not fully opaque
        if color.alpha < 1.0 {
            let alphaText = String(format: "%.0f%% opacity", color.alpha * 100)
            let hslSize = (color.hslString as NSString).size(withAttributes: codeAttrs)
            alphaText.draw(at: CGPoint(x: textX + hslSize.width + 12, y: y + 24), withAttributes: codeAttrs)
        }

        return y + 45
    }

    private static func ensureSpace(y: CGFloat, needed: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        if y + needed > pageRect.height - margin {
            ctx.beginPage()
            return margin
        }
        return y
    }

    private static func truncateText(_ text: String, toWidth maxWidth: CGFloat, font: UIFont) -> String {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var result = text

        while (result as NSString).size(withAttributes: attrs).width > maxWidth && result.count > 3 {
            result = String(result.dropLast(4)) + "..."
        }

        return result
    }
}
#endif
