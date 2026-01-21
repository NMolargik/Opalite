//
//  CommunityNavigationNode.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import CloudKit

/// Navigation destinations for the Community feature
enum CommunityNavigationNode: Hashable {
    case colorDetail(CommunityColor)
    case paletteDetail(CommunityPalette)
    case publisherProfile(CKRecord.ID, String) // userRecordID, displayName
}

/// Segment filter for the Community tab
enum CommunitySegment: String, CaseIterable, Identifiable {
    case colors = "Colors"
    case palettes = "Palettes"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .colors: return "paintpalette"
        case .palettes: return "swatchpalette"
        }
    }
}
