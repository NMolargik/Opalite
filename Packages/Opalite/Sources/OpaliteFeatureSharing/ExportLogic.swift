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

/// The three collapsible groups of file and code formats. The free "quick" formats (image,
/// PDF, Opalite file) sit above them and belong to no group.
nonisolated public enum ExportGroup: String, CaseIterable, Hashable, Identifiable, Sendable {
    case designApps
    case code
    case designTokens

    public var id: String { rawValue }

    /// Format ids in the order the group lists them. Also what decides membership.
    var memberIDs: [String] {
        switch self {
        case .designApps: ["procreate", "ase", "gpl"]
        case .code: ["css", "tailwind", "swiftui", "xcassets", "android", "flutter"]
        case .designTokens: ["dtcg", "figma", "scss", "json"]
        }
    }

    /// The group `id` (a format's raw value) belongs to, nil for the quick formats.
    static func containing(_ id: String) -> ExportGroup? {
        allCases.first { $0.memberIDs.contains(id) }
    }
}

/// A group and the formats of the sheet that fall in it.
nonisolated public struct ExportGroupEntry<Format: ExportFormat>: Identifiable {
    public let group: ExportGroup
    public let formats: [Format]
    public var id: ExportGroup { group }
}

/// The sheet's list: the free quick formats, then the grouped file and code formats.
nonisolated public struct ExportLayout<Format: ExportFormat> {
    public let quick: [Format]
    public let groups: [ExportGroupEntry<Format>]

    /// The group `format` is listed under, nil for the quick formats.
    public func group(of format: Format) -> ExportGroup? {
        groups.first { $0.formats.contains(format) }?.group
    }
}

/// The formats each sheet offers, free ones first so the default selection is usable.
nonisolated public enum ExportFormatCatalog {
    public static let designTokenColorFormats: [ColorExportFormat] = [.tailwind, .dtcg, .xcassets, .android, .flutter, .scss, .json, .figma]
    public static let designTokenPaletteFormats: [PaletteExportFormat] = [.tailwind, .dtcg, .xcassets, .android, .flutter, .scss, .json, .figma]

    /// Splits `formats` into the quick formats and the three groups, each in its own order.
    /// `idOf` reads a format's raw value; every format lands in exactly one place.
    public static func layout<Format: ExportFormat>(_ formats: [Format], idOf: (Format) -> String) -> ExportLayout<Format> {
        let quick = formats.filter { ExportGroup.containing(idOf($0)) == nil }
        let groups = ExportGroup.allCases.compactMap { group -> ExportGroupEntry<Format>? in
            let members = formats
                .filter { ExportGroup.containing(idOf($0)) == group }
                .sorted { (group.memberIDs.firstIndex(of: idOf($0)) ?? 0) < (group.memberIDs.firstIndex(of: idOf($1)) ?? 0) }
            return members.isEmpty ? nil : ExportGroupEntry(group: group, formats: members)
        }
        return ExportLayout(quick: quick, groups: groups)
    }

    public static func layout(_ formats: [ColorExportFormat]) -> ExportLayout<ColorExportFormat> { layout(formats, idOf: \.rawValue) }
    public static func layout(_ formats: [PaletteExportFormat]) -> ExportLayout<PaletteExportFormat> { layout(formats, idOf: \.rawValue) }

    public static let colorFormats: [ColorExportFormat] = [.image, .opalite, .ase, .procreate, .gpl, .css, .swiftui] + designTokenColorFormats
    public static let paletteFormats: [PaletteExportFormat] = [.image, .pdf, .opalite, .ase, .procreate, .gpl, .css, .swiftui] + designTokenPaletteFormats
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
    public static let scss = UTType(filenameExtension: "scss", conformingTo: .sourceCode) ?? .sourceCode
    public static let dart = UTType(filenameExtension: "dart", conformingTo: .sourceCode) ?? .sourceCode

    /// The type a design-token format is written as.
    static func utType(for kind: DesignTokenKind) -> UTType {
        switch kind {
        case .tailwind: css
        case .dtcg, .json, .figma: .json
        case .xcassets: .zip
        case .android: .xml
        case .flutter: dart
        case .scss: scss
        }
    }

    public static func utType(for format: ColorExportFormat) -> UTType {
        switch format {
        case .image: .png
        case .opalite: opaliteColor
        case .ase: adobeSwatchExchange
        case .procreate: procreateSwatches
        case .gpl: gimpPalette
        case .css: css
        case .swiftui: .swiftSource
        default: utType(for: format.designTokenKind ?? .json)
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
        default: utType(for: format.designTokenKind ?? .json)
        }
    }

    /// Every type an export document can be written as.
    public static let all: [UTType] = [.png, .pdf, opaliteColor, opalitePalette, adobeSwatchExchange, procreateSwatches, gimpPalette, css, scss, dart, .swiftSource, .json, .xml, .zip, .plainText, .data]
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
