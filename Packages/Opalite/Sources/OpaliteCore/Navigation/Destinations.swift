//
//  Destinations.swift
//  OpaliteCore
//
//  Typed navigation destinations for each tab's NavigationStack. Values carry ids, not
//  model objects, so paths are Hashable/Codable and survive model refreshes.
//

import Foundation

nonisolated public enum PortfolioDestination: Hashable, Sendable, Codable {
    case palette(UUID)
    case color(UUID)
    case canvas(UUID)
}

nonisolated public enum CommunityDestination: Hashable, Sendable {
    case color(CommunityColor)
    case palette(CommunityPalette)
    case publisher(id: CommunityRecordID, displayName: String)
}

nonisolated public enum SettingsDestination: Hashable, Sendable, Codable {
    case appearance
    case accessibility
    case hexCopying
    case onyx
    case watch
    case swatchBar
    case communityAdmin
    case about
}

nonisolated public enum CanvasDestination: Hashable, Sendable, Codable {
    case canvas(UUID)
}
