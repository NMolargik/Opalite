//
//  ColorManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI
import SwiftData

@MainActor
@Observable
class ColorManager {
    @ObservationIgnored
    let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // Cached data for views to consume
    var palettes: [OpalitePalette] = []
    var colors: [OpaliteColor] = []
    
    // MARK: - Fetch Helpers
    private var paletteSort: [SortDescriptor<OpalitePalette>] {
        [
            SortDescriptor(\OpalitePalette.updatedAt, order: .reverse),
            SortDescriptor(\OpalitePalette.createdAt, order: .reverse)
        ]
    }

    private var colorSort: [SortDescriptor<OpaliteColor>] {
        [
            SortDescriptor(\OpaliteColor.updatedAt, order: .reverse),
            SortDescriptor(\OpaliteColor.createdAt, order: .reverse)
        ]
    }
    
    private func reloadCache() {
        do {
            let paletteDescriptor = FetchDescriptor<OpalitePalette>(sortBy: paletteSort)
            let colorDescriptor = FetchDescriptor<OpaliteColor>(sortBy: colorSort)
            self.palettes = try context.fetch(paletteDescriptor)
            self.colors = try context.fetch(colorDescriptor)
        } catch {
            // Intentionally non-fatal; callers observe empty arrays on failure
            #if DEBUG
            print("[ColorManager] reloadCache error: \(error)")
            #endif
        }
    }
    
    // MARK: - Public API: Refresh
    /// Refreshes in-memory caches by fetching the latest data from the ModelContext.
    /// Marked async to align with call sites that await this work, even though the fetches are synchronous.
    func refresh() async {
        reloadCache()
    }
    
    // MARK: - Public API: Fetching
    /// Fetches all palettes and updates the cache.
    @discardableResult
    func fetchPalettes() throws -> [OpalitePalette] {
        let descriptor = FetchDescriptor<OpalitePalette>(sortBy: paletteSort)
        let result = try context.fetch(descriptor)
        self.palettes = result
        return result
    }

    /// Fetches all colors and updates the cache.
    @discardableResult
    func fetchColors() throws -> [OpaliteColor] {
        let descriptor = FetchDescriptor<OpaliteColor>(sortBy: colorSort)
        let result = try context.fetch(descriptor)
        self.colors = result
        return result
    }

    /// Fetches colors belonging to a specific palette.
    func fetchColors(for palette: OpalitePalette) throws -> [OpaliteColor] {
        // Compare by identifier to avoid optional relationship comparison issues in SwiftData predicates
        let targetID = palette.id
        let predicate = #Predicate<OpaliteColor> { color in
            color.palette?.id == targetID
        }
        let descriptor = FetchDescriptor<OpaliteColor>(predicate: predicate, sortBy: colorSort)
        return try context.fetch(descriptor)
    }
    
    // MARK: - Saving
    /// Persists any pending changes in the context.
    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Creating / Inserting
    /// Creates, inserts, and saves a new palette.
    @discardableResult
    func addPalette(
        name: String,
        author: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        isPinned: Bool = false,
        colors: [OpaliteColor] = []
    ) throws -> OpalitePalette {
        let palette = OpalitePalette(
            name: name,
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: author,
            notes: notes,
            tags: tags,
            isPinned: isPinned,
            colors: colors
        )
        // Ensure relationship is consistent
        palette.colors?.forEach { $0.palette = palette }
        context.insert(palette)
        try save()
        reloadCache()
        return palette
    }

    /// Inserts and saves an existing palette instance (e.g., imported).
    func addPalette(_ palette: OpalitePalette) throws {
        // Ensure relationship is consistent
        palette.colors?.forEach { $0.palette = palette }
        context.insert(palette)
        try save()
        reloadCache()
    }
    /// Creates, inserts, and saves a new color, optionally attaching it to a palette.
    @discardableResult
    func addColor(
        name: String? = nil,
        notes: String? = nil,
        isPinned: Bool = false,
        author: String? = nil,
        device: String? = nil,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1.0,
        to palette: OpalitePalette? = nil
    ) throws -> OpaliteColor {
        let color = OpaliteColor(
            name: name,
            notes: notes,
            isPinned: isPinned,
            createdByDisplayName: author,
            createdOnDeviceName: device,
            createdAt: .now,
            updatedAt: .now,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha,
            palette: palette
        )
        if let palette {
            // Maintain both sides of the relationship
            if palette.colors == nil { palette.colors = [] }
            palette.colors?.append(color)
            palette.updatedAt = .now
        }
        context.insert(color)
        try save()
        reloadCache()
        return color
    }

    /// Inserts and saves an existing color instance.
    func addColor(_ color: OpaliteColor, to palette: OpalitePalette? = nil) throws {
        if let palette {
            if palette.colors == nil { palette.colors = [] }
            color.palette = palette
            palette.colors?.append(color)
            palette.updatedAt = .now
        }
        context.insert(color)
        try save()
        reloadCache()
    }
    
    // MARK: - Updating
    /// Applies changes to a palette and saves.
    func update(_ palette: OpalitePalette, applying changes: ((OpalitePalette) -> Void)? = nil) throws {
        changes?(palette)
        palette.updatedAt = .now
        try save()
        reloadCache()
    }

    /// Applies changes to a color and saves.
    func update(_ color: OpaliteColor, applying changes: ((OpaliteColor) -> Void)? = nil) throws {
        changes?(color)
        color.updatedAt = .now
        try save()
        reloadCache()
    }
    
    // MARK: - Deleting
    /// Deletes a palette. Pass `andColors: true` to also delete its colors; otherwise relationships are nullified by default.
    func delete(_ palette: OpalitePalette, andColors: Bool = false) throws {
        if andColors, let colors = palette.colors {
            for c in colors {
                context.delete(c)
            }
        }
        context.delete(palette)
        try save()
        reloadCache()
    }

    /// Deletes a color.
    func delete(_ color: OpaliteColor) throws {
        context.delete(color)
        try save()
        reloadCache()
    }
    
}

