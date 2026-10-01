//
//  PortfolioSearch.swift
//  OpaliteCore
//
//  Local search over the portfolio: name, notes, hex (with or without "#"), tags, and
//  color-family words ("dark blue"). Used by the Search tab and Siri entity queries.
//

import Foundation

nonisolated public struct PortfolioSearchResult: Sendable, Equatable {
    public var colorIDs: [UUID]
    public var paletteIDs: [UUID]

    public init(colorIDs: [UUID] = [], paletteIDs: [UUID] = []) {
        self.colorIDs = colorIDs
        self.paletteIDs = paletteIDs
    }

    public var isEmpty: Bool { colorIDs.isEmpty && paletteIDs.isEmpty }
}

nonisolated public enum PortfolioSearch {
    public static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Whether a color matches a free-text query.
    public static func matches(name: String?, notes: String?, hex: String, rgba: RGBA, query: String) -> Bool {
        let q = normalized(query)
        guard !q.isEmpty else { return false }
        if let name, name.lowercased().contains(q) { return true }
        if let notes, notes.lowercased().contains(q) { return true }
        let hexQuery = q.hasPrefix("#") ? q : "#\(q)"
        if hex.lowercased() == hexQuery || hex.lowercased().contains(q) { return true }
        return ColorClassifier.matches(rgba, query: q)
    }

    /// Whether a palette matches a free-text query.
    public static func matches(paletteName: String, notes: String?, tags: [String], query: String) -> Bool {
        let q = normalized(query)
        guard !q.isEmpty else { return false }
        if paletteName.lowercased().contains(q) { return true }
        if let notes, notes.lowercased().contains(q) { return true }
        return tags.contains { $0.lowercased().contains(q) }
    }

    /// Ranks name matches for Siri: exact → exact hex → prefix → contains, capped.
    public static func rankedNameMatches<T>(_ items: [T], query: String, name: (T) -> String?, hex: (T) -> String?, limit: Int = 5) -> [T] {
        let q = normalized(query)
        guard !q.isEmpty else { return [] }

        let exact = items.filter { name($0)?.lowercased() == q }
        if !exact.isEmpty { return exact }

        let hexQuery = q.hasPrefix("#") ? q : "#\(q)"
        if let hexMatch = items.first(where: { hex($0)?.lowercased() == hexQuery }) { return [hexMatch] }

        let prefix = items.filter { name($0)?.lowercased().hasPrefix(q) == true }
            .sorted { (name($0) ?? "") < (name($1) ?? "") }
        if !prefix.isEmpty { return Array(prefix.prefix(limit)) }

        let contains = items.filter { name($0)?.lowercased().contains(q) == true }
            .sorted { (name($0) ?? "") < (name($1) ?? "") }
        return Array(contains.prefix(limit))
    }
}
