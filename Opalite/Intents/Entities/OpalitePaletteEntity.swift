//
//  OpalitePaletteEntity.swift
//  Opalite
//
//  Created by Nick Molargik on 1/18/26.
//

import AppIntents

/// AppEntity wrapper for OpalitePalette that Siri can understand and display.
struct OpalitePaletteEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Palette")
    static var defaultQuery = OpalitePaletteQuery()

    var id: UUID
    var name: String
    var colorCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(colorCount) \(colorCount == 1 ? "color" : "colors")")
    }

    init(id: UUID, name: String, colorCount: Int) {
        self.id = id
        self.name = name
        self.colorCount = colorCount
    }

    init(from palette: OpalitePalette) {
        self.id = palette.id
        self.name = palette.name
        self.colorCount = palette.colors?.count ?? 0
    }
}
