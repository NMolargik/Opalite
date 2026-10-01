//
//  PreviewViewController.swift
//  OpaliteQuickLook
//
//  Quick Look preview for .opalitecolor / .opalitepalette files, rendered with SwiftUI.
//

import QuickLook
import SwiftUI
import UIKit
import OpaliteCore

final class PreviewViewController: UIViewController, QLPreviewingController {
    func preparePreviewOfFile(at url: URL) async throws {
        let data = try Data(contentsOf: url)
        let content: FilePreview.Content
        switch OpaliteFileCodec.kind(of: url) {
        case .color:
            let color = try OpaliteFileCodec.decodeColor(from: data)
            content = .color(name: color.name, rgba: color.rgba)
        case .palette:
            let palette = try OpaliteFileCodec.decodePalette(from: data)
            content = .palette(name: palette.name, colors: palette.colors.map(\.rgba))
        case nil:
            throw OpaliteFileError.unsupportedExtension(url.pathExtension)
        }
        let host = UIHostingController(rootView: FilePreview(content: content))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

struct FilePreview: View {
    enum Content {
        case color(name: String?, rgba: RGBA)
        case palette(name: String, colors: [RGBA])
    }

    let content: Content

    var body: some View {
        VStack(spacing: 20) {
            switch content {
            case .color(let name, let rgba):
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha))
                    .frame(width: 220, height: 220)
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.quaternary, lineWidth: 2))
                Text(name ?? rgba.hexString)
                    .font(.title2.weight(.semibold))
                Text(rgba.hexString)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
            case .palette(let name, let colors):
                GeometryReader { proxy in
                    let layout = PalettePreviewLayout.calculate(colorCount: colors.count, availableWidth: proxy.size.width - 24, availableHeight: proxy.size.height - 24, minSpacing: 8, maxSpacing: 12, maxRows: 3)
                    VStack(spacing: layout.verticalSpacing) {
                        ForEach(0..<max(layout.rows, 0), id: \.self) { row in
                            HStack(spacing: layout.horizontalSpacing) {
                                ForEach(0..<layout.columns, id: \.self) { column in
                                    if let index = layout.index(row: row, column: column, colorCount: colors.count) {
                                        let rgba = colors[index]
                                        RoundedRectangle(cornerRadius: layout.swatchSize * 0.15, style: .continuous)
                                            .fill(Color(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha))
                                            .frame(width: layout.swatchSize, height: layout.swatchSize)
                                    } else {
                                        Color.clear.frame(width: layout.swatchSize, height: layout.swatchSize)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(12)
                .frame(maxWidth: 520, maxHeight: 220)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text(name)
                    .font(.title2.weight(.semibold))
                Text("\(colors.count) \(colors.count == 1 ? "color" : "colors")")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
