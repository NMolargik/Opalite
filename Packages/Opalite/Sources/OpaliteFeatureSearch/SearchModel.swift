//
//  SearchModel.swift
//  OpaliteFeatureSearch
//
//  The Search tab's pure logic: value snapshots of the portfolio, grouped results over
//  Core's `PortfolioSearch`, suggestion chips (recent searches and the color families
//  present in the portfolio), and the recent-searches store. Host-tested.
//

import Foundation
import OpaliteCore

// MARK: - Snapshots

nonisolated public struct SearchableColor: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String?
    public let notes: String?
    public let rgba: RGBA
    public let updatedAt: Date

    public init(id: UUID, name: String?, notes: String?, rgba: RGBA, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.notes = notes
        self.rgba = rgba
        self.updatedAt = updatedAt
    }

    public var hex: String { rgba.hexString }
    public var displayName: String { name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : hex }
    public var hasName: Bool { !(name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
}

nonisolated public struct SearchablePalette: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let notes: String?
    public let tags: [String]
    public let colorValues: [RGBA]

    public init(id: UUID, name: String, notes: String?, tags: [String], colorValues: [RGBA]) {
        self.id = id
        self.name = name
        self.notes = notes
        self.tags = tags
        self.colorValues = colorValues
    }

    public var colorCount: Int { colorValues.count }
}

// MARK: - Results

nonisolated public struct SearchResults: Equatable, Sendable {
    public var colors: [SearchableColor]
    public var palettes: [SearchablePalette]

    public init(colors: [SearchableColor] = [], palettes: [SearchablePalette] = []) {
        self.colors = colors
        self.palettes = palettes
    }

    public var isEmpty: Bool { colors.isEmpty && palettes.isEmpty }
    public var count: Int { colors.count + palettes.count }
}

// MARK: - Suggestions

nonisolated public struct SearchSuggestion: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case recent
        case family
    }

    public let text: String
    public let kind: Kind

    public init(text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    public var id: String { "\(kind)-\(text)" }

    public var systemImage: String {
        switch kind {
        case .recent: "clock"
        case .family: "paintpalette"
        }
    }
}

// MARK: - Engine

nonisolated public enum SearchEngine {
    public static let maximumRecentColors = 8
    public static let maximumFamilySuggestions = 8
    public static let maximumRecentQueries = 6

    public static func isBlank(_ query: String) -> Bool {
        PortfolioSearch.normalized(query).isEmpty
    }

    /// Colors and palettes matching the query (name, notes, hex, tags, family words).
    public static func results(query: String, colors: [SearchableColor], palettes: [SearchablePalette]) -> SearchResults {
        guard !isBlank(query) else { return SearchResults() }
        let matchedColors = colors.filter {
            PortfolioSearch.matches(name: $0.name, notes: $0.notes, hex: $0.hex, rgba: $0.rgba, query: query)
        }
        let matchedPalettes = palettes.filter {
            PortfolioSearch.matches(paletteName: $0.name, notes: $0.notes, tags: $0.tags, query: query)
        }
        return SearchResults(colors: matchedColors, palettes: matchedPalettes)
    }

    /// The most recently updated colors for the idle screen.
    public static func recentColors(_ colors: [SearchableColor], limit: Int = maximumRecentColors) -> [SearchableColor] {
        Array(colors.sorted { $0.updatedAt > $1.updatedAt }.prefix(limit))
    }

    /// Family words ("blue", "dark red"…) that actually describe colors in the portfolio,
    /// most common first.
    public static func familySuggestions(for colors: [SearchableColor], limit: Int = maximumFamilySuggestions) -> [String] {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]
        for (index, color) in colors.enumerated() {
            let family = ColorClassifier.family(of: color.rgba)
            let hsl = color.rgba.hsl
            var term = family.rawValue
            if family.isChromatic {
                if hsl.lightness * 100 < 35 { term = "dark \(term)" } else if hsl.lightness * 100 > 65 { term = "light \(term)" }
            }
            counts[term, default: 0] += 1
            if firstSeen[term] == nil { firstSeen[term] = index }
        }
        return counts.keys
            .sorted { lhs, rhs in
                if counts[lhs]! != counts[rhs]! { return counts[lhs]! > counts[rhs]! }
                return firstSeen[lhs]! < firstSeen[rhs]!
            }
            .prefix(limit)
            .map { $0 }
    }

    /// Family words that complete what the user is typing (for `.searchSuggestions`).
    public static func completions(for query: String, families: [String]) -> [String] {
        let q = PortfolioSearch.normalized(query)
        guard !q.isEmpty else { return [] }
        return families.filter { $0.hasPrefix(q) && $0 != q }
    }

    /// Chips for the idle screen: recent searches first, then families.
    public static func suggestions(recentQueries: [String], families: [String]) -> [SearchSuggestion] {
        recentQueries.map { SearchSuggestion(text: $0, kind: .recent) } + families.map { SearchSuggestion(text: $0, kind: .family) }
    }
}

// MARK: - Recent searches

/// The last few submitted queries, newest first, persisted as JSON.
nonisolated public struct RecentSearches: Equatable, Sendable {
    public static let storageKey = "searchRecentQueries"

    public private(set) var queries: [String]

    public init(queries: [String] = []) {
        self.queries = queries
    }

    public static func decode(_ data: Data?) -> RecentSearches {
        guard let data, !data.isEmpty, let queries = try? JSONDecoder().decode([String].self, from: data) else { return RecentSearches() }
        return RecentSearches(queries: queries)
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(queries)) ?? Data()
    }

    /// Records a submitted query at the front (deduplicated, trimmed, capped).
    public mutating func record(_ query: String, limit: Int = SearchEngine.maximumRecentQueries) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        queries.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        queries.insert(trimmed, at: 0)
        if queries.count > limit { queries.removeLast(queries.count - limit) }
    }

    public mutating func remove(_ query: String) {
        queries.removeAll { $0 == query }
    }

    public mutating func clear() {
        queries.removeAll()
    }
}
