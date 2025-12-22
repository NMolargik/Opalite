//
//  UTType-opaliteColorID.swift
//  Opalite
//
//  Created by Nick Molargik on 12/13/25.
//

import UniformTypeIdentifiers

extension UTType {
    /// Drag & drop identifier for an OpaliteColor UUID string
    static let opaliteColorID = UTType(exportedAs: "com.molargiksoftware.opalite.color-id", conformingTo: .plainText)

    /// Shareable file type for a single OpaliteColor (.opalitecolor)
    static let opaliteColor = UTType(exportedAs: "com.molargiksoftware.opalite.color", conformingTo: .json)

    /// Shareable file type for an OpalitePalette with colors (.opalitepalette)
    static let opalitePalette = UTType(exportedAs: "com.molargiksoftware.opalite.palette", conformingTo: .json)
}
