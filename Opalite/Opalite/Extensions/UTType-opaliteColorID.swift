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
}
