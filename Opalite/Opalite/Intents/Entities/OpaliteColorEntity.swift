//
//  OpaliteColorEntity.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//

import AppIntents
import SwiftData

/// AppEntity wrapper for OpaliteColor that Siri can understand and display.
struct OpaliteColorEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Color")
    static var defaultQuery = OpaliteColorQuery()

    var id: UUID
    var name: String
    var hexString: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(hexString)")
    }

    init(id: UUID, name: String, hexString: String) {
        self.id = id
        self.name = name
        self.hexString = hexString
    }

    init(from color: OpaliteColor) {
        self.id = color.id
        self.name = color.name ?? color.hexString
        self.hexString = color.hexString
    }
}
