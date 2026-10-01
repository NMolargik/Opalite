//
//  ExportService.swift
//  OpaliteServices
//
//  Writes export files to the temp directory for sharing/saving. Interchange formats come
//  from the pure encoders in Core; the PNG preview is rendered by the caller (it needs the
//  design system); the PDF is drawn here with UIKit.
//

import Foundation
import OpaliteCore
import os

nonisolated public enum ExportError: LocalizedError, Sendable {
    case renderFailed
    case writeFailed(String)
    case unsupportedOnThisPlatform

    public var errorDescription: String? {
        switch self {
        case .renderFailed: String(localized: "Failed to render the image.")
        case .writeFailed(let reason): String(localized: "Failed to export: \(reason)")
        case .unsupportedOnThisPlatform: String(localized: "This export isn't available on this device.")
        }
    }
}

public enum ExportService {

    /// Exports a color; `imagePNG` is required for `.image`.
    public static func exportColor(_ color: OpaliteColor, format: ColorExportFormat, imagePNG: Data? = nil) throws -> URL {
        let baseName = color.hasName ? ExportEncoders.sanitizedFilename(color.name ?? "") : ExportEncoders.filename(fromHex: color.hexString)
        let swatch = ExportSwatch(name: color.name, rgba: color.rgba)
        let data: Data
        switch format {
        case .image:
            guard let imagePNG else { throw ExportError.renderFailed }
            data = imagePNG
        case .opalite:
            data = try color.jsonRepresentation()
        case .ase:
            data = ExportEncoders.ase(swatch)
        case .procreate:
            data = try ExportEncoders.procreateSwatches(name: swatch.resolvedName, swatches: [swatch])
        case .gpl:
            data = ExportEncoders.gpl(name: swatch.resolvedName, swatches: [swatch])
        case .css:
            data = ExportEncoders.css(title: swatch.resolvedName, prefix: nil, swatches: [swatch])
        case .swiftui:
            data = ExportEncoders.swiftUI(title: swatch.resolvedName, prefix: nil, swatches: [swatch])
        }
        return try write(data, filename: "\(baseName).\(format.fileExtension)")
    }

    /// Exports a palette; `imagePNG` is required for `.image`, `userName` labels the PDF.
    public static func exportPalette(_ palette: OpalitePalette, format: PaletteExportFormat, imagePNG: Data? = nil, userName: String = "User") throws -> URL {
        let baseName = ExportEncoders.sanitizedFilename(palette.name)
        let swatches = palette.sortedColors.map { ExportSwatch(name: $0.name, rgba: $0.rgba) }
        let data: Data
        switch format {
        case .image:
            guard let imagePNG else { throw ExportError.renderFailed }
            data = imagePNG
        case .pdf:
            #if canImport(UIKit) && !os(watchOS)
            data = PortfolioPDFRenderer.render(palette: palette, userName: userName)
            #else
            throw ExportError.unsupportedOnThisPlatform
            #endif
        case .opalite:
            data = try palette.jsonRepresentation()
        case .ase:
            data = ExportEncoders.ase(groupName: palette.name, swatches: swatches)
        case .procreate:
            data = try ExportEncoders.procreateSwatches(name: palette.name, swatches: swatches)
        case .gpl:
            data = ExportEncoders.gpl(name: palette.name, swatches: swatches)
        case .css:
            data = ExportEncoders.css(title: palette.name, prefix: palette.name, swatches: swatches)
        case .swiftui:
            data = ExportEncoders.swiftUI(title: palette.name, prefix: palette.name, swatches: swatches)
        }
        return try write(data, filename: "\(baseName).\(format.fileExtension)")
    }

    /// Exports the whole portfolio as a PDF.
    public static func exportPortfolioPDF(palettes: [OpalitePalette], looseColors: [OpaliteColor], userName: String) throws -> URL {
        #if canImport(UIKit) && !os(watchOS)
        let data = PortfolioPDFRenderer.render(palettes: palettes, looseColors: looseColors, userName: userName)
        return try write(data, filename: "Opalite Portfolio \(Int(Date().timeIntervalSince1970)).pdf")
        #else
        throw ExportError.unsupportedOnThisPlatform
        #endif
    }

    private static func write(_ data: Data, filename: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
    }
}
