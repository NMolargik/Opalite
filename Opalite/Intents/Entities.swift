//
//  Entities.swift
//  Opalite
//
//  App Intents entities mirroring colors and palettes. Both conform to IndexedEntity so
//  Spotlight indexes them semantically, and back the intents that take a specific color
//  or palette as a parameter.
//

import AppIntents
import CoreSpotlight
import Foundation
import OpaliteComposition
import OpaliteCore

// MARK: - Color

struct ColorEntity: AppEntity, IndexedEntity {
    let id: UUID
    let name: String?
    let hexString: String
    let notes: String?
    let paletteName: String?
    let rgba: RGBA

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Color")
    }

    static let defaultQuery = ColorEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name ?? hexString)", subtitle: name == nil ? nil : "\(hexString)")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = name ?? hexString
        var parts = [hexString, rgba.rgbString, rgba.hslString]
        if let notes, !notes.isEmpty { parts.append(notes) }
        if let paletteName { parts.append(String(localized: "In palette \(paletteName)")) }
        set.contentDescription = parts.joined(separator: " · ")
        set.keywords = ["color", "swatch", hexString] + ColorClassifier.searchTerms(for: rgba)
        return set
    }
}

extension ColorEntity {
    @MainActor
    init(_ color: OpaliteColor) {
        id = color.id
        name = color.hasName ? color.name : nil
        hexString = color.hexString
        notes = color.notes
        paletteName = color.palette?.name
        rgba = color.rgba
    }
}

struct ColorEntityQuery: EntityQuery, EntityStringQuery {
    @Dependency private var session: SessionController

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ColorEntity] {
        try session.loadColors().filter { identifiers.contains($0.id) }.map(ColorEntity.init)
    }

    /// Named colors form Siri's vocabulary; unnamed ones can't be spoken.
    @MainActor
    func suggestedEntities() async throws -> [ColorEntity] {
        try session.loadColors().filter(\.hasName).map(ColorEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ColorEntity] {
        PortfolioSearch.rankedNameMatches(try session.loadColors(), query: string, name: \.name, hex: \.hexString).map(ColorEntity.init)
    }
}

// MARK: - Palette

struct PaletteEntity: AppEntity, IndexedEntity {
    let id: UUID
    let name: String
    let colorCount: Int
    let notes: String?
    let tags: [String]
    let colorNames: [String]

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Palette")
    }

    static let defaultQuery = PaletteEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: colorCount == 1 ? "1 color" : "\(colorCount) colors")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = name
        var parts = [colorCount == 1 ? "1 color" : "\(colorCount) colors"]
        if !colorNames.isEmpty { parts.append(colorNames.joined(separator: ", ")) }
        if let notes, !notes.isEmpty { parts.append(notes) }
        set.contentDescription = parts.joined(separator: " · ")
        set.keywords = ["palette", "colors"] + tags
        return set
    }
}

extension PaletteEntity {
    @MainActor
    init(_ palette: OpalitePalette) {
        id = palette.id
        name = palette.name
        colorCount = palette.colorCount
        notes = palette.notes
        tags = palette.tags
        colorNames = palette.sortedColors.map(\.displayName)
    }
}

struct PaletteEntityQuery: EntityQuery, EntityStringQuery {
    @Dependency private var session: SessionController

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PaletteEntity] {
        try session.loadPalettes().filter { identifiers.contains($0.id) }.map(PaletteEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PaletteEntity] {
        try session.loadPalettes().filter { !$0.isArchived }.map(PaletteEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PaletteEntity] {
        PortfolioSearch.rankedNameMatches(try session.loadPalettes(), query: string, name: { $0.name }, hex: { _ in nil }).map(PaletteEntity.init)
    }
}
