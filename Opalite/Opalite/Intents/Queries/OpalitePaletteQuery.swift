//
//  OpalitePaletteQuery.swift
//  Opalite
//
//  Created by Nick Molargik on 1/18/26.
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

    /// Returns all palettes so Siri can build its vocabulary for voice resolution.
    /// Siri indexes these periodically — any palette not listed here cannot be resolved by voice.
    @MainActor
    func suggestedEntities() async throws -> [OpalitePaletteEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpalitePalette>(
            sortBy: [SortDescriptor(\.name)]
        )
        let palettes = try context.fetch(descriptor)
        return palettes.map { OpalitePaletteEntity(from: $0) }
    }
}

extension OpalitePaletteQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [OpalitePaletteEntity] {
        let search = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !search.isEmpty else { return [] }

        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpalitePalette>()
        let palettes = try context.fetch(descriptor)

        // 1. Exact name match — no disambiguation needed
        let exactName = palettes.filter { $0.name.lowercased() == search }
        if !exactName.isEmpty {
            return exactName.map { OpalitePaletteEntity(from: $0) }
        }

        // 2. Name starts with search — high confidence
        let prefixMatches = palettes
            .filter { $0.name.lowercased().hasPrefix(search) }
            .sorted { $0.name < $1.name }
        if prefixMatches.count == 1 {
            return [OpalitePaletteEntity(from: prefixMatches[0])]
        }
        if !prefixMatches.isEmpty {
            return Array(prefixMatches.prefix(5)).map { OpalitePaletteEntity(from: $0) }
        }

        // 3. Name contains search — lower confidence, cap tightly
        let containsMatches = palettes
            .filter { $0.name.lowercased().contains(search) }
            .sorted { $0.name < $1.name }
        if containsMatches.count == 1 {
            return [OpalitePaletteEntity(from: containsMatches[0])]
        }
        return Array(containsMatches.prefix(5)).map { OpalitePaletteEntity(from: $0) }
    }
}
