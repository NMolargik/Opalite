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
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
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
    /// Palettes sorted by createdAt (most recently created first)
    var palettes: [OpalitePalette] = []
    /// Colors sorted by updatedAt (most recently edited first)
    var colors: [OpaliteColor] = []

    /// Colors not assigned to any palette
    var looseColors: [OpaliteColor] {
        colors.filter { $0.palette == nil }
    }

    /// Color selected from SwatchBar to apply to canvas drawing tool.
    /// CanvasView observes this to update the current ink color.
    var selectedCanvasColor: OpaliteColor?

    /// Tracks whether the SwatchBar window is currently open (iOS only, for single-instance enforcement).
    var isSwatchBarOpen: Bool = false

    /// Tracks whether the main window is currently open (for single-instance enforcement from SwatchBar).
    var isMainWindowOpen: Bool = false

    /// The currently active/viewed color in a detail view.
    /// Set by ColorDetailView on appear, cleared on disappear.
    /// Used by menu bar commands to provide context-aware actions.
    var activeColor: OpaliteColor?

    /// The currently active/viewed palette in a detail view.
    /// Set by PaletteDetailView on appear, cleared on disappear.
    /// Used by menu bar commands to provide context-aware actions.
    var activePalette: OpalitePalette?

    /// Triggers the color editor for the active color from menu bar.
    var editColorTrigger: UUID?

    /// Triggers the palette selection sheet for the active color from menu bar.
    var addToPaletteTrigger: UUID?

    /// Triggers removing the active color from its palette from menu bar.
    var removeFromPaletteTrigger: UUID?

    /// Triggers renaming the active palette from menu bar.
    var renamePaletteTrigger: UUID?

    var author: String = "User"

    // MARK: - Fetch Helpers
    private var paletteSort: [SortDescriptor<OpalitePalette>] {
        [
            SortDescriptor(\OpalitePalette.createdAt, order: .reverse)
        ]
    }

    private var colorSort: [SortDescriptor<OpaliteColor>] {
        [
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

    // MARK: - Targeted Cache Updates
    // These methods update the in-memory cache without a full database fetch,
    // improving performance for single-item operations.

    private func insertPaletteIntoCache(_ palette: OpalitePalette) {
        // Insert at beginning since it's most recently updated
        palettes.insert(palette, at: 0)
    }

    private func insertColorIntoCache(_ color: OpaliteColor) {
        // Insert at beginning since it's most recently updated
        colors.insert(color, at: 0)
    }

    private func removePaletteFromCache(_ palette: OpalitePalette) {
        palettes.removeAll { $0.id == palette.id }
    }

    private func removeColorFromCache(_ color: OpaliteColor) {
        colors.removeAll { $0.id == color.id }
    }

    private func resortPalettesCache() {
        palettes.sort { $0.createdAt > $1.createdAt }
    }

    private func resortColorsCache() {
        colors.sort { ($0.updatedAt, $0.createdAt) > ($1.updatedAt, $1.createdAt) }
    }

    // MARK: - Private helpers: Relationship management
    /// Attaches a color to the given palette, keeping both sides of the relationship in sync
    /// and updating timestamps/device metadata. Optionally accepts an error handler.
    func attachColor(_ color: OpaliteColor, to palette: OpalitePalette, onError: ((OpaliteError) -> Void)? = nil) {
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
            onError?(.colorAttachFailed)
        }
    }

    /// Detaches a color from its current palette (if any), keeping both sides of the relationship in sync.
    /// Optionally accepts an error handler.
    func detachColorFromPalette(_ color: OpaliteColor, onError: ((OpaliteError) -> Void)? = nil) {
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
            onError?(.colorDetachFailed)
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
        notes: String? = nil,
        tags: [String] = [],
        colors: [OpaliteColor] = []
    ) throws -> OpalitePalette {
        let palette = OpalitePalette(
            name: name,
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: self.author,
            notes: notes,
            tags: tags,
            colors: colors
        )
        // Ensure relationship is consistent
        palette.colors?.forEach { $0.palette = palette }
        context.insert(palette)
        try saveContext()
        // Targeted cache update: insert new palette at front (most recently updated)
        insertPaletteIntoCache(palette)
        // Also insert any colors that came with the palette
        palette.colors?.forEach { insertColorIntoCache($0) }
        return palette
    }

    /// Inserts and saves an existing palette instance (e.g., imported).
    func createPalette(existing palette: OpalitePalette) throws -> OpalitePalette {
        // Ensure relationship is consistent
        palette.colors?.forEach { $0.palette = palette }
        context.insert(palette)
        try saveContext()
        // Targeted cache update: insert new palette at front
        insertPaletteIntoCache(palette)
        // Also insert any colors that came with the palette
        palette.colors?.forEach { insertColorIntoCache($0) }
        return palette
    }

    /// Creates, inserts, and saves a new color
    @discardableResult
    func createColor(
        name: String? = nil,
        notes: String? = nil,
        device: String? = nil,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double = 1.0,
        palette: OpalitePalette? = nil,
    ) throws -> OpaliteColor {
        #if canImport(DeviceKit)
        let resolvedDeviceName = device ?? Device.current.safeDescription
        #else
        let resolvedDeviceName = device
        #endif
        let color = OpaliteColor(
            name: name,
            notes: notes,
            createdByDisplayName: self.author,
            createdOnDeviceName: resolvedDeviceName,
            updatedOnDeviceName: resolvedDeviceName,
            createdAt: .now,
            updatedAt: .now,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha,
            palette: palette
        )

        context.insert(color)
        try saveContext()
        // Targeted cache update: insert new color at front (most recently updated)
        insertColorIntoCache(color)
        return color
    }

    // Insert an existing color into the context
    func createColor(existing color: OpaliteColor) throws -> OpaliteColor {
        #if canImport(DeviceKit)
        color.createdOnDeviceName = Device.current.safeDescription
        color.updatedOnDeviceName = Device.current.safeDescription
        #endif
        // Set author if not already set (e.g., when creating a new color via the editor)
        if color.createdByDisplayName == nil || color.createdByDisplayName?.isEmpty == true {
            color.createdByDisplayName = self.author
        }
        context.insert(color)
        try saveContext()
        // Targeted cache update: insert new color at front
        insertColorIntoCache(color)
        return color
    }

    // MARK: - Updating
    /// Applies changes to a palette and saves.
    func updatePalette(_ palette: OpalitePalette, applying changes: ((OpalitePalette) -> Void)? = nil) throws {
        changes?(palette)
        palette.updatedAt = .now
        try saveContext()
        // Targeted cache update: re-sort since updatedAt changed
        resortPalettesCache()
    }

    /// Renames a palette.
    func renamePalette(_ palette: OpalitePalette, to newName: String) throws {
        try updatePalette(palette) { p in
            p.name = newName
        }
    }

    /// Applies changes to a color and saves.
    func updateColor(_ color: OpaliteColor, applying changes: ((OpaliteColor) -> Void)? = nil) throws {
        changes?(color)
        #if canImport(DeviceKit)
        color.updatedOnDeviceName = Device.current.safeDescription
        #endif
        color.updatedAt = .now
        try saveContext()
        // Targeted cache update: re-sort since updatedAt changed
        resortColorsCache()
    }

    /// Renames a color. Pass nil to clear the name.
    func renameColor(_ color: OpaliteColor, to newName: String?) throws {
        try updateColor(color) { c in
            c.name = newName
        }
    }

    // MARK: - Deleting
    /// Deletes a palette. Pass `andColors: true` to also delete its colors; otherwise relationships are nullified by default.
    func deletePalette(_ palette: OpalitePalette, andColors: Bool = false) throws {
        let colorsToRemove = andColors ? (palette.colors ?? []) : []
        if andColors {
            for c in colorsToRemove {
                context.delete(c)
            }
        }
        context.delete(palette)
        try saveContext()
        // Targeted cache update: remove deleted items from cache
        removePaletteFromCache(palette)
        colorsToRemove.forEach { removeColorFromCache($0) }
    }

    /// Deletes a color.
    func deleteColor(_ color: OpaliteColor) throws {
        context.delete(color)
        try saveContext()
        // Targeted cache update: remove deleted color from cache
        removeColorFromCache(color)
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

        let sampleAuthor = "Sample Sam"
        let deviceName: String = {
            #if canImport(DeviceKit)
            return Device.current.safeDescription
            #elseif canImport(UIKit)
            return UIDevice.current.name
            #elseif canImport(AppKit)
            return Host.current().localizedName ?? "This Mac"
            #else
            return "Unknown Device"
            #endif
        }()

        let makeColor: (String, Double, Double, Double) -> OpaliteColor = { name, r, g, b in
            OpaliteColor(
                name: name,
                createdByDisplayName: sampleAuthor,
                createdOnDeviceName: deviceName,
                updatedOnDeviceName: deviceName,
                createdAt: .now,
                updatedAt: .now,
                red: r,
                green: g,
                blue: b,
                alpha: 1.0
            )
        }

        // Build several themed palettes
        let sunrise = OpalitePalette(
            name: "Sunrise",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: sampleAuthor,
            notes: "Warm hues inspired by a sunrise.",
            tags: ["sample", "warm"],
            colors: [
                makeColor("Dawn", 0.98, 0.77, 0.36),
                makeColor("Amber", 0.95, 0.60, 0.18),
                makeColor("Coral", 0.95, 0.45, 0.30)
            ]
        )

        let ocean = OpalitePalette(
            name: "Ocean",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: sampleAuthor,
            notes: "Cool blues and teals.",
            tags: ["sample", "cool"],
            colors: [
                makeColor("Deep Blue", 0.05, 0.20, 0.45),
                makeColor("Sea", 0.00, 0.55, 0.65),
                makeColor("Foam", 0.80, 0.95, 0.95),
                makeColor("Lagoon", 0.00, 0.70, 0.55)
            ]
        )

        let neon = OpalitePalette(
            name: "Neon",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: sampleAuthor,
            notes: "High-contrast neon accents.",
            tags: ["sample", "neon"],
            colors: [
                makeColor("Neon Pink", 1.00, 0.20, 0.65),
                makeColor("Electric Blue", 0.10, 0.45, 1.00),
                makeColor("Lime", 0.70, 1.00, 0.20),
                makeColor("Laser", 0.95, 1.00, 0.30)
            ]
        )

        let grayscale = OpalitePalette(
            name: "Grayscale",
            createdAt: .now,
            updatedAt: .now,
            createdByDisplayName: sampleAuthor,
            notes: "Neutral grays for UI.",
            tags: ["sample", "neutral"],
            colors: [
                makeColor("Almost Black", 0.05, 0.05, 0.06),
                makeColor("Charcoal", 0.10, 0.10, 0.11),
                makeColor("Graphite", 0.16, 0.17, 0.19),
                makeColor("Slate", 0.20, 0.22, 0.25),
                makeColor("Steel", 0.40, 0.43, 0.47),
                makeColor("Pewter", 0.52, 0.54, 0.57),
                makeColor("Ash", 0.58, 0.59, 0.61),
                makeColor("Smoke", 0.66, 0.67, 0.69),
                makeColor("Silver", 0.70, 0.73, 0.76),
                makeColor("Cloud", 0.82, 0.84, 0.86),
                makeColor("Platinum", 0.90, 0.91, 0.92),
                makeColor("Off White", 0.93, 0.94, 0.95),
                makeColor("Snow", 0.97, 0.98, 0.99)
            ]
        )

        let looseColors = [
            makeColor("Moss", 0.35, 0.55, 0.30),
            makeColor("Pine", 0.10, 0.35, 0.20),
            makeColor("Bark", 0.45, 0.30, 0.20),
            makeColor("Fern", 0.30, 0.70, 0.35)
        ]

        // Ensure relationships are consistent (colors' palette back-references)
        let palettesToInsert: [OpalitePalette] = [
            sunrise,
            ocean,
            neon,
            grayscale,
            OpalitePalette(name: "New Palette", createdAt: .now, updatedAt: .now, createdByDisplayName: sampleAuthor, notes: nil, tags: [], colors: [])
        ]
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
