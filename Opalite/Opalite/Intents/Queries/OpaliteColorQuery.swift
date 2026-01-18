//
//  OpaliteColorQuery.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
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

    @MainActor
    func suggestedEntities() async throws -> [OpaliteColorEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        var descriptor = FetchDescriptor<OpaliteColor>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let colors = try context.fetch(descriptor)
        return colors.map { OpaliteColorEntity(from: $0) }
    }
}

extension OpaliteColorQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [OpaliteColorEntity] {
        let context = ModelContext(OpaliteModelContainer.shared)
        let descriptor = FetchDescriptor<OpaliteColor>()
        let colors = try context.fetch(descriptor)
        let searchLower = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for exact match first - if found, return only that
        if let exactMatch = colors.first(where: { $0.name?.lowercased() == searchLower }) {
            return [OpaliteColorEntity(from: exactMatch)]
        }

        // Also check hex string for exact match
        if let hexMatch = colors.first(where: { $0.hexString.lowercased() == searchLower }) {
            return [OpaliteColorEntity(from: hexMatch)]
        }

        // Otherwise, sort by relevance: starts-with first, then contains
        let matches = colors.filter {
            ($0.name?.lowercased().contains(searchLower) ?? false) ||
            $0.hexString.lowercased().contains(searchLower)
        }
        let sorted = matches.sorted { a, b in
            let aName = a.name?.lowercased() ?? ""
            let bName = b.name?.lowercased() ?? ""
            let aStarts = aName.hasPrefix(searchLower)
            let bStarts = bName.hasPrefix(searchLower)
            if aStarts && !bStarts { return true }
            if !aStarts && bStarts { return false }
            return aName < bName
        }

        return sorted.map { OpaliteColorEntity(from: $0) }
    }
}
