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
}

nonisolated public enum ColorExportFormat: String, ExportFormat {
    case image
    case opalite
    case ase
    case procreate
    case gpl
    case css
    case swiftui

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
