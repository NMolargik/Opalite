//
//  ExportLogic.swift
//  OpaliteFeatureSharing
//
//  The pure decisions behind the export sheets: which formats are offered and in what
//  order, which ones the free tier can use, the content type each one is written as, and
//  the value that describes a file the `ExportService` has already written. Host-tested.
//

import Foundation
import UniformTypeIdentifiers
import OpaliteCore

// MARK: - Access

/// Onyx gating for export formats.
nonisolated public enum ExportAccess {
    /// Whether tapping `format` should show the paywall instead of exporting.
    public static func isLocked<Format: ExportFormat>(_ format: Format, hasOnyx: Bool) -> Bool {
        !format.isFreeFormat && !hasOnyx
    }

    /// The first format the user can actually use — the sheet's initial selection.
    public static func defaultFormat<Format: ExportFormat>(in formats: [Format], hasOnyx: Bool) -> Format? {
        formats.first { !isLocked($0, hasOnyx: hasOnyx) }
    }

    /// Whether any offered format is gated for this user (drives the section footer).
    public static func hasLockedFormats<Format: ExportFormat>(in formats: [Format], hasOnyx: Bool) -> Bool {
        formats.contains { isLocked($0, hasOnyx: hasOnyx) }
    }
}

// MARK: - Catalog

/// The formats each sheet offers, free ones first so the default selection is usable.
nonisolated public enum ExportFormatCatalog {
    public static let colorFormats: [ColorExportFormat] = [.image, .opalite, .ase, .procreate, .gpl, .css, .swiftui]
    public static let paletteFormats: [PaletteExportFormat] = [.image, .pdf, .opalite, .ase, .procreate, .gpl, .css, .swiftui]
}

// MARK: - Content types

/// The `UTType` each export is written as (drives the Files exporter and the share sheet).
nonisolated public enum ExportContentType {
    public static let opaliteColor = UTType(exportedAs: OpaliteFileType.colorIdentifier, conformingTo: .json)
    public static let opalitePalette = UTType(exportedAs: OpaliteFileType.paletteIdentifier, conformingTo: .json)
    public static let adobeSwatchExchange = UTType(filenameExtension: "ase") ?? .data
    public static let procreateSwatches = UTType(filenameExtension: "swatches") ?? .data
    public static let gimpPalette = UTType(filenameExtension: "gpl", conformingTo: .plainText) ?? .plainText
    public static let css = UTType(filenameExtension: "css", conformingTo: .sourceCode) ?? .sourceCode

    public static func utType(for format: ColorExportFormat) -> UTType {
        switch format {
        case .image: .png
        case .opalite: opaliteColor
        case .ase: adobeSwatchExchange
        case .procreate: procreateSwatches
        case .gpl: gimpPalette
        case .css: css
        case .swiftui: .swiftSource
        }
    }

    public static func utType(for format: PaletteExportFormat) -> UTType {
        switch format {
        case .image: .png
        case .pdf: .pdf
        case .opalite: opalitePalette
        case .ase: adobeSwatchExchange
        case .procreate: procreateSwatches
        case .gpl: gimpPalette
        case .css: css
        case .swiftui: .swiftSource
        }
    }

    /// Every type an export document can be written as.
    public static let all: [UTType] = [.png, .pdf, opaliteColor, opalitePalette, adobeSwatchExchange, procreateSwatches, gimpPalette, css, .swiftSource, .json, .plainText, .data]
}

// MARK: - Exported file

/// A file the `ExportService` wrote to the temp directory, loaded for sharing and saving.
nonisolated public struct ExportedFile: Sendable, Equatable, Identifiable {
    public let url: URL
    public let data: Data
    public let contentType: UTType

    public init(url: URL, data: Data, contentType: UTType) {
        self.url = url
        self.data = data
        self.contentType = contentType
    }

    /// Reads the file at `url` into memory (exports are small; the PDF is the largest).
    public static func load(_ url: URL, contentType: UTType) throws -> ExportedFile {
        ExportedFile(url: url, data: try Data(contentsOf: url), contentType: contentType)
    }

    public var id: URL { url }
    /// "Ocean-Blue.ase"
    public var filename: String { url.lastPathComponent }
    /// "Ocean-Blue" — what the Files exporter proposes; it appends the extension itself.
    public var baseName: String { url.deletingPathExtension().lastPathComponent }
    public var byteCount: Int { data.count }
    public var isImage: Bool { contentType.conforms(to: .image) }

    /// "Ocean-Blue.ase · 1 KB"
    public var summary: String {
        "\(filename) · \(byteCount.formatted(.byteCount(style: .file)))"
    }

    /// Deletes the temp file (safe to call more than once).
    public func removeFromDisk() {
        try? FileManager.default.removeItem(at: url)
    }
}
