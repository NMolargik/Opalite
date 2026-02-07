//
//  CommunitySegment.swift
//  Opalite
//
//  Extracted from CommunityNavigationNode.swift
//

import Foundation

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
