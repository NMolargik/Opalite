//
//  OpaliteColorQuery.swift
//  Opalite
//
//  Created by Nick Molargik on 1/18/26.
//

import AppIntents
import SwiftData

/// EntityQuery that allows Siri to find colors by name or ID.
struct OpaliteColorQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [OpaliteColorEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpaliteColor>()
        let colors = try context.fetch(descriptor)
        return colors
            .filter { identifiers.contains($0.id) }
            .map { OpaliteColorEntity(from: $0) }
    }

    /// Returns all named colors so Siri can build its vocabulary for voice resolution.
    /// Siri indexes these periodically — any color not listed here cannot be resolved by voice.
    @MainActor
    func suggestedEntities() async throws -> [OpaliteColorEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpaliteColor>(
            sortBy: [SortDescriptor(\.name)]
        )
        let colors = try context.fetch(descriptor)
        return colors
            .filter { $0.name != nil && !$0.name!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { OpaliteColorEntity(from: $0) }
    }
}

extension OpaliteColorQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [OpaliteColorEntity] {
        let search = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !search.isEmpty else { return [] }

        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpaliteColor>()
        let colors = try context.fetch(descriptor)

        // 1. Exact name match — no disambiguation needed
        let exactName = colors.filter { $0.name?.lowercased() == search }
        if !exactName.isEmpty {
            return exactName.map { OpaliteColorEntity(from: $0) }
        }

        // 2. Exact hex match (with or without #)
        let searchHex = search.hasPrefix("#") ? search : "#\(search)"
        if let hexMatch = colors.first(where: {
            $0.hexString.lowercased() == search || $0.hexString.lowercased() == searchHex
        }) {
            return [OpaliteColorEntity(from: hexMatch)]
        }

        // 3. Name starts with search — high confidence
        let prefixMatches = colors
            .filter { $0.name?.lowercased().hasPrefix(search) == true }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        if prefixMatches.count == 1 {
            return [OpaliteColorEntity(from: prefixMatches[0])]
        }
        if !prefixMatches.isEmpty {
            return Array(prefixMatches.prefix(5)).map { OpaliteColorEntity(from: $0) }
        }

        // 4. Name contains search — lower confidence, cap tightly
        let containsMatches = colors
            .filter { $0.name?.lowercased().contains(search) == true }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        if containsMatches.count == 1 {
            return [OpaliteColorEntity(from: containsMatches[0])]
        }
        return Array(containsMatches.prefix(5)).map { OpaliteColorEntity(from: $0) }
    }
}
