//
//  ExportFormat.swift
//  OpaliteCore
//
//  The export formats for colors and palettes and which ones the free tier includes.
//  Display strings/colors live in the UI layers.
//

import Foundation

nonisolated public protocol ExportFormat: CaseIterable, Identifiable, Hashable, Sendable {
    var fileExtension: String { get }
    var systemImage: String { get }
    /// Whether the format is available without Onyx.
    var isFreeFormat: Bool { get }
    /// The preferred filename extension's UTType identifier, when the app registers one.
    var utTypeIdentifier: String? { get }
    /// Whether the format is listed under "Design Tokens" rather than with the general formats.
    var isDesignToken: Bool { get }
}

nonisolated public enum ColorExportFormat: String, ExportFormat {
    case image
    case opalite
    case ase
    case procreate
    case gpl
    case css
    case swiftui
    case tailwind
    case dtcg
    case xcassets
    case android
    case flutter
    case scss
    case json
    case figma

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .image: "png"
        case .opalite: "opalitecolor"
        case .ase: "ase"
        case .procreate: "swatches"
        case .gpl: "gpl"
        case .css: "css"
        case .swiftui: "swift"
        case .tailwind: "css"
        case .dtcg: "json"
        case .xcassets: "zip"
        case .android: "xml"
        case .flutter: "dart"
        case .scss: "scss"
        case .json: "json"
        case .figma: "json"
        }
    }

    public var systemImage: String {
        switch self {
        case .image: "photo.fill"
        case .opalite: "paintpalette.fill"
        case .ase: "a.square.fill"
        case .procreate: "paintbrush.fill"
        case .gpl: "square.grid.3x3.fill"
        case .css: "chevron.left.forwardslash.chevron.right"
        case .swiftui: "swift"
        case .tailwind: "wind"
        case .dtcg: "curlybraces"
        case .xcassets: "shippingbox.fill"
        case .android: "chevron.left.slash.chevron.right"
        case .flutter: "bird.fill"
        case .scss: "number"
        case .json: "curlybraces.square.fill"
        case .figma: "pencil.and.ruler.fill"
        }
    }

    public var isFreeFormat: Bool { self == .opalite || self == .image }

    public var utTypeIdentifier: String? {
        self == .opalite ? OpaliteFileType.colorIdentifier : nil
    }
}

nonisolated public enum PaletteExportFormat: String, ExportFormat {
    case image
    case pdf
    case opalite
    case ase
    case procreate
    case gpl
    case css
    case swiftui
    case tailwind
    case dtcg
    case xcassets
    case android
    case flutter
    case scss
    case json
    case figma

    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .image: "png"
        case .pdf: "pdf"
        case .opalite: "opalitepalette"
        case .ase: "ase"
        case .procreate: "swatches"
        case .gpl: "gpl"
        case .css: "css"
        case .swiftui: "swift"
        case .tailwind: "css"
        case .dtcg: "json"
        case .xcassets: "zip"
        case .android: "xml"
        case .flutter: "dart"
        case .scss: "scss"
        case .json: "json"
        case .figma: "json"
        }
    }

    public var systemImage: String {
        switch self {
        case .image: "photo.fill"
        case .pdf: "doc.richtext"
        case .opalite: "swatchpalette.fill"
        case .ase: "a.square.fill"
        case .procreate: "paintbrush.fill"
        case .gpl: "square.grid.3x3.fill"
        case .css: "chevron.left.forwardslash.chevron.right"
        case .swiftui: "swift"
        case .tailwind: "wind"
        case .dtcg: "curlybraces"
        case .xcassets: "shippingbox.fill"
        case .android: "chevron.left.slash.chevron.right"
        case .flutter: "bird.fill"
        case .scss: "number"
        case .json: "curlybraces.square.fill"
        case .figma: "pencil.and.ruler.fill"
        }
    }

    public var isFreeFormat: Bool { self == .opalite || self == .image || self == .pdf }

    public var utTypeIdentifier: String? {
        self == .opalite ? OpaliteFileType.paletteIdentifier : nil
    }
}

/// The uniform type identifiers the app exports (declared in Info.plist).
nonisolated public enum OpaliteFileType {
    public static let colorIdentifier = "com.molargiksoftware.opalite.color"
    public static let paletteIdentifier = "com.molargiksoftware.opalite.palette"
    public static let colorIDIdentifier = "com.molargiksoftware.opalite.color-id"
    public static let colorExtension = "opalitecolor"
    public static let paletteExtension = "opalitepalette"
}

// MARK: - Design tokens

nonisolated extension ColorExportFormat {
    /// Whether the format belongs to the "Design Tokens" group in the export list.
    public var isDesignToken: Bool { designTokenKind != nil }

    /// The token kind this format writes, nil for the non-token formats.
    public var designTokenKind: DesignTokenKind? {
        switch self {
        case .tailwind: .tailwind
        case .dtcg: .dtcg
        case .xcassets: .xcassets
        case .android: .android
        case .flutter: .flutter
        case .scss: .scss
        case .json: .json
        case .figma: .figma
        default: nil
        }
    }

    /// The exported file's suffix after its base name (".tokens.json").
    public var filenameSuffix: String { designTokenKind?.filenameSuffix ?? ".\(fileExtension)" }
}

nonisolated extension PaletteExportFormat {
    public var isDesignToken: Bool { designTokenKind != nil }

    public var designTokenKind: DesignTokenKind? {
        switch self {
        case .tailwind: .tailwind
        case .dtcg: .dtcg
        case .xcassets: .xcassets
        case .android: .android
        case .flutter: .flutter
        case .scss: .scss
        case .json: .json
        case .figma: .figma
        default: nil
        }
    }

    public var filenameSuffix: String { designTokenKind?.filenameSuffix ?? ".\(fileExtension)" }
}

/// The design-token outputs, shared by the color and palette format enums.
nonisolated public enum DesignTokenKind: Sendable, CaseIterable {
    case tailwind, dtcg, xcassets, android, flutter, scss, json, figma

    public var filenameSuffix: String {
        switch self {
        case .tailwind: ".tailwind.css"
        case .dtcg: ".tokens.json"
        case .xcassets: ".xcassets.zip"
        case .android: ".colors.xml"
        case .flutter: ".dart"
        case .scss: ".scss"
        case .json: ".json"
        case .figma: ".figma.json"
        }
    }

    /// Encodes `set` in this format. `catalogName` names the folder inside the asset-catalog zip.
    public func encode(_ set: TokenSet, catalogName: String) -> Data {
        switch self {
        case .tailwind: DesignTokenEncoders.tailwind(set)
        case .dtcg: DesignTokenEncoders.dtcg(set)
        case .xcassets: DesignTokenEncoders.xcassetsArchive(set, catalogName: catalogName)
        case .android: DesignTokenEncoders.androidColorsXML(set)
        case .flutter: DesignTokenEncoders.flutter(set)
        case .scss: DesignTokenEncoders.scss(set)
        case .json: DesignTokenEncoders.json(set)
        case .figma: DesignTokenEncoders.figmaVariables(set)
        }
    }
}
