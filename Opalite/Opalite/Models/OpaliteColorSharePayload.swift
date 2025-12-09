//
//  OpaliteColorSharePayload.swift
//  Opalite
//
//  Created by Nick Molargik on 12/6/25.
//

import Foundation

struct OpaliteColorSharePayload: Codable {
    let id: UUID
    let name: String?
    let notes: String?
    let createdByDisplayName: String?
    let createdOnDeviceName: String?
    
    let hex: String
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let createdAt: Date
    let updatedAt: Date
}

@MainActor
extension OpaliteColor {
    func makeSharePayload() -> OpaliteColorSharePayload {
        OpaliteColorSharePayload(
            id: id,
            name: name,
            notes: notes,
            createdByDisplayName: createdByDisplayName,
            createdOnDeviceName: createdOnDeviceName,
            hex: hexString,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    func jsonDataForSharing() throws -> Data {
        let payload = makeSharePayload()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }
}
