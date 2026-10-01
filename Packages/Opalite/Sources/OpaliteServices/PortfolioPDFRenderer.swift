//
//  PortfolioPDFRenderer.swift
//  OpaliteServices
//
//  Draws palettes and loose colors into a US-Letter PDF with UIKit (Catalyst/iOS/visionOS).
//

#if canImport(UIKit) && !os(watchOS)
import UIKit
import OpaliteCore

public enum PortfolioPDFRenderer {
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 40
    private static let contentWidth: CGFloat = 612 - 80

    private static let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
    private static let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
    private static let sectionFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
    private static let paletteFont = UIFont.systemFont(ofSize: 14, weight: .medium)
    private static let colorNameFont = UIFont.systemFont(ofSize: 11, weight: .medium)
    private static let colorDetailFont = UIFont.systemFont(ofSize: 9, weight: .regular)

    public static func render(palette: OpalitePalette, userName: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            fillBackground()
            var y = drawTitle(palette.name, subtitle: exportedLine(userName), summary: countLine(palette.colorCount), notes: palette.notes)
            let colors = palette.colors?.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending } ?? []
            for color in colors {
                y = ensureSpace(y: y, needed: 55, ctx: ctx)
                y = drawColorRow(color, at: y, indented: false)
            }
            if colors.isEmpty {
                y = ensureSpace(y: y, needed: 40, ctx: ctx)
                String(localized: "No colors in this palette.").draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: subtitleFont, .foregroundColor: UIColor.darkGray])
            }
        }
    }

    public static func render(palettes: [OpalitePalette], looseColors: [OpaliteColor], userName: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            fillBackground()
            let total = looseColors.count + palettes.reduce(0) { $0 + $1.colorCount }
            let summary = "\(palettes.count) \(palettes.count == 1 ? "palette" : "palettes"), \(total) \(total == 1 ? "color" : "colors")"
            var y = drawTitle("Opalite Portfolio", subtitle: exportedLine(userName), summary: summary, notes: nil)

            if !palettes.isEmpty {
                y = ensureSpace(y: y, needed: 60, ctx: ctx)
                y = drawSectionHeader(String(localized: "Palettes"), at: y)
                for palette in palettes.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                    let colors = palette.colors?.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending } ?? []
                    y = ensureSpace(y: y, needed: 35 + CGFloat(min(colors.count, 1)) * 50, ctx: ctx)
                    y = drawPaletteHeader(palette.name, colorCount: colors.count, at: y)
                    for color in colors {
                        y = ensureSpace(y: y, needed: 55, ctx: ctx)
                        y = drawColorRow(color, at: y, indented: true)
                    }
                    y += 15
                }
            }

            if !looseColors.isEmpty {
                y = ensureSpace(y: y, needed: 60, ctx: ctx)
                y = drawSectionHeader(String(localized: "Loose Colors"), at: y)
                for color in looseColors.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) {
                    y = ensureSpace(y: y, needed: 55, ctx: ctx)
                    y = drawColorRow(color, at: y, indented: false)
                }
            }

            if palettes.isEmpty, looseColors.isEmpty {
                y = ensureSpace(y: y, needed: 40, ctx: ctx)
                String(localized: "No colors or palettes to export.").draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: subtitleFont, .foregroundColor: UIColor.darkGray])
            }
        }
    }

    // MARK: - Drawing

    private static func exportedLine(_ userName: String) -> String {
        let date = Date().formatted(date: .abbreviated, time: .shortened)
        return String(localized: "Exported on \(date) by \(userName)")
    }

    private static func countLine(_ count: Int) -> String {
        "\(count) \(count == 1 ? "color" : "colors")"
    }

    private static func fillBackground() {
        UIColor.white.setFill()
        UIRectFill(pageRect)
    }

    private static func drawTitle(_ title: String, subtitle: String, summary: String, notes: String?) -> CGFloat {
        var y: CGFloat = 60
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: titleFont, .foregroundColor: UIColor.black])
        y += 36
        let subtitleAttrs: [NSAttributedString.Key: Any] = [.font: subtitleFont, .foregroundColor: UIColor.darkGray]
        subtitle.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
        y += 18
        summary.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
        y += 18
        if let notes, !notes.isEmpty {
            truncate(notes, toWidth: contentWidth, font: subtitleFont).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += 18
        }
        y += 12
        let divider = UIBezierPath()
        divider.move(to: CGPoint(x: margin, y: y))
        divider.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
        UIColor.lightGray.setStroke()
        divider.lineWidth = 0.5
        divider.stroke()
        return y + 20
    }

    private static func drawSectionHeader(_ title: String, at y: CGFloat) -> CGFloat {
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black])
        return y + 28
    }

    private static func drawPaletteHeader(_ name: String, colorCount: Int, at y: CGFloat) -> CGFloat {
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: paletteFont, .foregroundColor: UIColor.black]
        name.draw(at: CGPoint(x: margin, y: y), withAttributes: nameAttrs)
        let nameSize = (name as NSString).size(withAttributes: nameAttrs)
        countLine(colorCount).draw(at: CGPoint(x: margin + nameSize.width + 10, y: y + 2), withAttributes: [.font: colorDetailFont, .foregroundColor: UIColor.darkGray])
        return y + 22
    }

    private static func drawColorRow(_ color: OpaliteColor, at y: CGFloat, indented: Bool) -> CGFloat {
        let leftX = indented ? margin + 20 : margin
        let swatchSize: CGFloat = 36
        let swatchPath = UIBezierPath(roundedRect: CGRect(x: leftX, y: y, width: swatchSize, height: swatchSize), cornerRadius: 6)
        UIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha).setFill()
        swatchPath.fill()
        UIColor.lightGray.setStroke()
        swatchPath.lineWidth = 0.5
        swatchPath.stroke()

        let textX = leftX + swatchSize + 12
        let textWidth = pageRect.width - margin - textX
        truncate(color.displayName, toWidth: textWidth, font: colorNameFont).draw(at: CGPoint(x: textX, y: y), withAttributes: [.font: colorNameFont, .foregroundColor: UIColor.black])

        let codeAttrs: [NSAttributedString.Key: Any] = [.font: colorDetailFont, .foregroundColor: UIColor.darkGray]
        color.hexString.draw(at: CGPoint(x: textX, y: y + 13), withAttributes: codeAttrs)
        let hexWidth = (color.hexString as NSString).size(withAttributes: codeAttrs).width
        color.rgbString.uppercased().draw(at: CGPoint(x: textX + hexWidth + 12, y: y + 13), withAttributes: codeAttrs)
        color.hslString.draw(at: CGPoint(x: textX, y: y + 24), withAttributes: codeAttrs)
        if color.alpha < 1 {
            let hslWidth = (color.hslString as NSString).size(withAttributes: codeAttrs).width
            String(format: "%.0f%% opacity", color.alpha * 100).draw(at: CGPoint(x: textX + hslWidth + 12, y: y + 24), withAttributes: codeAttrs)
        }
        return y + 45
    }

    private static func ensureSpace(y: CGFloat, needed: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        if y + needed > pageRect.height - margin {
            ctx.beginPage()
            fillBackground()
            return margin
        }
        return y
    }

    private static func truncate(_ text: String, toWidth maxWidth: CGFloat, font: UIFont) -> String {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var result = text
        while (result as NSString).size(withAttributes: attrs).width > maxWidth, result.count > 3 {
            result = String(result.dropLast(4)) + "…"
        }
        return result
    }
}
#endif
