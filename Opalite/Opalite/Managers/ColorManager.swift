//
//  ColorManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI
import SwiftData
#if canImport(DeviceKit)
import DeviceKit
#endif

@MainActor
@Observable
class ColorManager {
    @ObservationIgnored
    let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Cached data for views to consume
    var palettes: [OpalitePalette] = []
    var colors: [OpaliteColor] = []
    var looseColors: [OpaliteColor] {
        colors.filter { $0.palette == nil }
    }
    
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
    
    // MARK: - Private helpers: Relationship management
    /// Attaches a color to the given palette, keeping both sides of the relationship in sync
    /// and updating timestamps/device metadata. Does not save the context.
    func attachColor(_ color: OpaliteColor, to palette: OpalitePalette) {
        // If already attached to this palette, ensure it's present once in the palette list
        if color.palette?.id == palette.id {
            if palette.colors == nil { palette.colors = [] }
            let exists = palette.colors?.contains(where: { $0.id == color.id }) ?? false
            if !exists {
                palette.colors?.append(color)
            }
            // Touch timestamps since the relationship list may have changed
            palette.updatedAt = .now
            color.updatedAt = .now
        } else {
            // If attached to a different palette, remove it from there first
            if let old = color.palette, old.id != palette.id {
                if let idx = old.colors?.firstIndex(where: { $0.id == color.id }) {
                    old.colors?.remove(at: idx)
                }
                old.updatedAt = .now
            }

            // Attach to the new palette
            color.palette = palette
            if palette.colors == nil { palette.colors = [] }
            // Avoid duplicates
            if let dupIdx = palette.colors?.firstIndex(where: { $0.id == color.id }) {
                palette.colors?.remove(at: dupIdx)
            }
            palette.colors?.append(color)
            // Touch timestamps for the new attachment
            palette.updatedAt = .now
            color.updatedAt = .now
        }
        
        do {
            try saveContext()
            Task {
                await refreshAll()
            }
        } catch {
            // TODO: error handling
        }
    }

    /// Detaches a color from its current palette (if any), keeping both sides of the relationship in sync.
    /// Does not save the context.
    func detachColorFromPalette(_ color: OpaliteColor) {
        if let palette = color.palette {
            if let idx = palette.colors?.firstIndex(where: { $0.id == color.id }) {
                palette.colors?.remove(at: idx)
            }
            palette.updatedAt = .now
        }
        color.palette = nil
        
        do {
            try saveContext()
            Task {
                await refreshAll()
            }
        } catch {
            // TODO: error handling
        }

        #if canImport(DeviceKit)
        color.updatedOnDeviceName = Device.current.safeDescription
        #endif
        color.updatedAt = .now
    }
    
    // MARK: - Public API: Refresh
    /// Refreshes in-memory caches by fetching the latest data from the ModelContext.
    /// Marked async to align with call sites that await this work, even though the fetches are synchronous.
    func refreshAll() async {
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
    func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Creating / Inserting
    /// Creates, inserts, and saves a new palette.
    @discardableResult
    func createPalette(
        name: String,
        author: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        colors: [OpaliteColor] = []
    ) throws -> OpalitePalette {
        let palette = OpalitePalette(
            name: name,
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: author,
            notes: notes,
            tags: tags,
            colors: colors
        )
        // Ensure relationship is consistent
        palette.colors?.forEach { $0.palette = palette }
        context.insert(palette)
        try saveContext()
        reloadCache()
        return palette
    }

    /// Inserts and saves an existing palette instance (e.g., imported).
    func createPalette(existing palette: OpalitePalette) throws -> OpalitePalette {
        // Ensure relationship is consistent
        palette.colors?.forEach { $0.palette = palette }
        context.insert(palette)
        try saveContext()
        reloadCache()
        return palette
    }
    
    /// Creates, inserts, and saves a new color
    @discardableResult
    func createColor(
        name: String? = nil,
        notes: String? = nil,
        author: String? = nil,
        device: String? = nil,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1.0,
    ) throws -> OpaliteColor {
        #if canImport(DeviceKit)
        let resolvedDeviceName = device ?? Device.current.safeDescription
        #else
        let resolvedDeviceName = device
        #endif
        let color = OpaliteColor(
            name: name,
            notes: notes,
            createdByDisplayName: author,
            createdOnDeviceName: resolvedDeviceName,
            updatedOnDeviceName: resolvedDeviceName,
            createdAt: .now,
            updatedAt: .now,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha,
            palette: nil
        )

        context.insert(color)
        try saveContext()
        reloadCache()
        return color
    }
    
    // Insert an existing color into the context
    func createColor(existing color: OpaliteColor) throws -> OpaliteColor {
        #if canImport(DeviceKit)
        color.createdOnDeviceName = Device.current.safeDescription
        color.updatedOnDeviceName = Device.current.safeDescription
        #endif
        context.insert(color)
        try saveContext()
        reloadCache()
        return color
    }

    // MARK: - Updating
    /// Applies changes to a palette and saves.
    func updatePalette(_ palette: OpalitePalette, applying changes: ((OpalitePalette) -> Void)? = nil) throws {
        changes?(palette)
        palette.updatedAt = .now
        try saveContext()
        reloadCache()
    }

    /// Applies changes to a color and saves.
    func updateColor(_ color: OpaliteColor, applying changes: ((OpaliteColor) -> Void)? = nil) throws {
        changes?(color)
        #if canImport(DeviceKit)
        color.updatedOnDeviceName = Device.current.safeDescription
        #endif
        color.updatedAt = .now
        try saveContext()
        reloadCache()
    }
    
    // MARK: - Deleting
    /// Deletes a palette. Pass `andColors: true` to also delete its colors; otherwise relationships are nullified by default.
    func deletePalette(_ palette: OpalitePalette, andColors: Bool = false) throws {
        if andColors, let colors = palette.colors {
            for c in colors {
                context.delete(c)
            }
        }
        context.delete(palette)
        try saveContext()
        reloadCache()
    }

    /// Deletes a color.
    func deleteColor(_ color: OpaliteColor) throws {
        context.delete(color)
        try saveContext()
        reloadCache()
    }

    // MARK: - Samples
    /// Loads sample data (colors and palette) into the context and saves.
    /// This will insert `OpaliteColor.sample`, `OpaliteColor.sample2`, and `OpalitePalette.sample`,
    /// ensuring relationships are consistent, then refresh the in-memory caches.
    func loadSamples() throws {
        // Clear in-memory caches first (does not modify storage)
        // so the UI will reflect newly added items immediately after save
        self.palettes = []
        self.colors = []

        // Build several themed palettes
        let sunrise = OpalitePalette(
            name: "Sunrise",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: "Samples",
            notes: "Warm hues inspired by a sunrise.",
            tags: ["sample", "warm"],
            colors: [
                OpaliteColor(name: "Dawn", red: 0.98, green: 0.77, blue: 0.36),
                OpaliteColor(name: "Amber", red: 0.95, green: 0.60, blue: 0.18),
                OpaliteColor(name: "Coral", red: 0.95, green: 0.45, blue: 0.30)
            ]
        )

        let ocean = OpalitePalette(
            name: "Ocean",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: "Samples",
            notes: "Cool blues and teals.",
            tags: ["sample", "cool"],
            colors: [
                OpaliteColor(name: "Deep Blue", red: 0.05, green: 0.20, blue: 0.45),
                OpaliteColor(name: "Sea", red: 0.00, green: 0.55, blue: 0.65),
                OpaliteColor(name: "Foam", red: 0.80, green: 0.95, blue: 0.95),
                OpaliteColor(name: "Lagoon", red: 0.00, green: 0.70, blue: 0.55)
            ]
        )

        let neon = OpalitePalette(
            name: "Neon",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: "Samples",
            notes: "High-contrast neon accents.",
            tags: ["sample", "neon"],
            colors: [
                OpaliteColor(name: "Neon Pink", red: 1.00, green: 0.20, blue: 0.65),
                OpaliteColor(name: "Electric Blue", red: 0.10, green: 0.45, blue: 1.00),
                OpaliteColor(name: "Lime", red: 0.70, green: 1.00, blue: 0.20),
                OpaliteColor(name: "Laser", red: 0.95, green: 1.00, blue: 0.30)
            ]
        )

        let grayscale = OpalitePalette(
            name: "Grayscale",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: "Samples",
            notes: "Neutral grays for UI.",
            tags: ["sample", "neutral"],
            colors: [
                OpaliteColor(name: "Almost Black", red: 0.05, green: 0.05, blue: 0.06),
                OpaliteColor(name: "Charcoal", red: 0.10, green: 0.10, blue: 0.11),
                OpaliteColor(name: "Graphite", red: 0.16, green: 0.17, blue: 0.19),
                OpaliteColor(name: "Slate", red: 0.20, green: 0.22, blue: 0.25),
                OpaliteColor(name: "Steel", red: 0.40, green: 0.43, blue: 0.47),
                OpaliteColor(name: "Pewter", red: 0.52, green: 0.54, blue: 0.57),
                OpaliteColor(name: "Ash", red: 0.58, green: 0.59, blue: 0.61),
                OpaliteColor(name: "Smoke", red: 0.66, green: 0.67, blue: 0.69),
                OpaliteColor(name: "Silver", red: 0.70, green: 0.73, blue: 0.76),
                OpaliteColor(name: "Cloud", red: 0.82, green: 0.84, blue: 0.86),
                OpaliteColor(name: "Platinum", red: 0.90, green: 0.91, blue: 0.92),
                OpaliteColor(name: "Off White", red: 0.93, green: 0.94, blue: 0.95),
                OpaliteColor(name: "Snow", red: 0.97, green: 0.98, blue: 0.99)
            ]
        )
        
        let looseColors = [
            OpaliteColor(name: "Moss", red: 0.35, green: 0.55, blue: 0.30),
            OpaliteColor(name: "Pine", red: 0.10, green: 0.35, blue: 0.20),
            OpaliteColor(name: "Bark", red: 0.45, green: 0.30, blue: 0.20),
            OpaliteColor(name: "Fern", red: 0.30, green: 0.70, blue: 0.35)
        ]

        // Ensure relationships are consistent (colors' palette back-references)
        let palettesToInsert: [OpalitePalette] = [sunrise, ocean, neon, grayscale, OpalitePalette(name: "New Palette")]
        for p in palettesToInsert {
            p.colors = p.colors ?? []
            for c in p.colors ?? [] {
                c.palette = p
            }
        }

        // Insert palettes and their colors
        for p in palettesToInsert {
            context.insert(p)
            for c in p.colors ?? [] {
                context.insert(c)
            }
        }
        
        for c in looseColors {
            context.insert(c)
        }

        try saveContext()
        reloadCache()
    }
}
