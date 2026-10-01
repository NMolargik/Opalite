//
//  TVSearchFilter.swift
//  OpaliteFeatureTV
//
//  Which kinds of results the Search tab shows, and the matching over the portfolio.
//

import Foundation
import OpaliteCore

nonisolated public enum TVSearchScope: String, CaseIterable, Identifiable, Sendable {
    case all, colors, palettes
    public var id: String { rawValue }
    public var includesColors: Bool { self != .palettes }
    public var includesPalettes: Bool { self != .colors }
}

/// Filters a portfolio with `PortfolioSearch`. MainActor because it reads SwiftData models.
public enum TVSearchFilter {
    public static func colors(_ colors: [OpaliteColor], matching query: String) -> [OpaliteColor] {
        let q = PortfolioSearch.normalized(query)
        guard !q.isEmpty else { return [] }
        return colors.filter { PortfolioSearch.matches(name: $0.name, notes: $0.notes, hex: $0.hexString, rgba: $0.rgba, query: q) }
    }

    public static func palettes(_ palettes: [OpalitePalette], matching query: String) -> [OpalitePalette] {
        let q = PortfolioSearch.normalized(query)
        guard !q.isEmpty else { return [] }
        return palettes.filter { PortfolioSearch.matches(paletteName: $0.name, notes: $0.notes, tags: $0.tags, query: q) }
    }
}
