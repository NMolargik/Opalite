//
//  WatchColorManager.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI
import SwiftData
import WatchKit

@MainActor
@Observable
class WatchColorManager {
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

    // MARK: - User Preferences

    /// Whether to include the "#" prefix when displaying hex codes.
    var includeHexPrefix: Bool {
        get { UserDefaults.standard.bool(forKey: "includeHexPrefix") }
        set { UserDefaults.standard.set(newValue, forKey: "includeHexPrefix") }
    }

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
            #if DEBUG
            print("[WatchColorManager] reloadCache error: \(error)")
            #endif
        }
    }

    // MARK: - Public API: Refresh
    /// Refreshes in-memory caches by fetching the latest data from the ModelContext.
    func refreshAll() async {
        reloadCache()
    }

    // MARK: - Hex Formatting

    /// Returns the hex string formatted according to user preference.
    func formattedHex(for color: OpaliteColor) -> String {
        let baseHex = color.hexString
        if includeHexPrefix {
            return baseHex
        } else {
            return baseHex.hasPrefix("#") ? String(baseHex.dropFirst()) : baseHex
        }
    }

    // MARK: - Haptic Feedback

    /// Plays a click haptic for tap interactions.
    func playTapHaptic() {
        WKInterfaceDevice.current().play(.click)
    }

    /// Plays a success haptic for long-press interactions.
    func playSuccessHaptic() {
        WKInterfaceDevice.current().play(.success)
    }
}
