//
//  OpalitePaletteQuery.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//

import AppIntents
import SwiftData

/// EntityQuery that allows Siri to find palettes by name or ID.
struct OpalitePaletteQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [OpalitePaletteEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpalitePalette>()
        let palettes = try context.fetch(descriptor)
        return palettes
            .filter { identifiers.contains($0.id) }
            .map { OpalitePaletteEntity(from: $0) }
    }

    @MainActor
    func suggestedEntities() async throws -> [OpalitePaletteEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        var descriptor = FetchDescriptor<OpalitePalette>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let palettes = try context.fetch(descriptor)
        return palettes.map { OpalitePaletteEntity(from: $0) }
    }
}

extension OpalitePaletteQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [OpalitePaletteEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpalitePalette>()
        let palettes = try context.fetch(descriptor)
        let searchLower = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for exact match first - if found, return only that
        if let exactMatch = palettes.first(where: { $0.name.lowercased() == searchLower }) {
            return [OpalitePaletteEntity(from: exactMatch)]
        }

        // Otherwise, sort by relevance: starts-with first, then contains
        let matches = palettes.filter { $0.name.lowercased().contains(searchLower) }
        let sorted = matches.sorted { a, b in
            let aStarts = a.name.lowercased().hasPrefix(searchLower)
            let bStarts = b.name.lowercased().hasPrefix(searchLower)
            if aStarts && !bStarts { return true }
            if !aStarts && bStarts { return false }
            return a.name < b.name
        }

        return sorted.map { OpalitePaletteEntity(from: $0) }
    }
}
