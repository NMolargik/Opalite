//
//  WatchColorManager.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI
import WatchKit

@MainActor
@Observable
class WatchColorManager {
    // MARK: - Cached data for views
    var colors: [WatchColor] = []
    var palettes: [WatchPalette] = []

    /// Whether the initial sync has completed
    var hasCompletedInitialSync: Bool = false

    /// Whether a sync is in progress
    var isSyncing: Bool = false

    /// Last successful sync timestamp
    var lastSyncTimestamp: Date? {
        WatchSessionManager.shared.lastSyncTimestamp
    }

    /// Colors not assigned to any palette
    var looseColors: [WatchColor] {
        colors.filter { $0.paletteId == nil }
    }

    /// Returns colors belonging to a specific palette
    func colors(for palette: WatchPalette) -> [WatchColor] {
        colors.filter { $0.paletteId == palette.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - User Preferences

    /// Whether to include the "#" prefix when displaying hex codes.
    var includeHexPrefix: Bool {
        get { UserDefaults.standard.bool(forKey: "includeHexPrefix") }
        set { UserDefaults.standard.set(newValue, forKey: "includeHexPrefix") }
    }

    // MARK: - Init

    init() {
        // Set up callback for when data is received from iPhone
        WatchSessionManager.shared.onDataReceived = { [weak self] colors, palettes in
            self?.colors = colors.sorted { $0.createdAt > $1.createdAt }
            self?.palettes = palettes.sorted { $0.createdAt > $1.createdAt }
            self?.hasCompletedInitialSync = true
            self?.isSyncing = false
        }

        // Load any cached data from local storage
        loadFromCache()
    }

    // MARK: - Data Loading

    /// Loads cached data from UserDefaults
    private func loadFromCache() {
        let cached = WatchSessionManager.shared.loadFromLocalStorage()
        colors = cached.colors.sorted { $0.createdAt > $1.createdAt }
        palettes = cached.palettes.sorted { $0.createdAt > $1.createdAt }

        // If we have cached data, consider initial sync complete
        if !colors.isEmpty || !palettes.isEmpty {
            hasCompletedInitialSync = true
        }
    }

    // MARK: - Sync

    /// Performs the initial sync from iPhone
    func performInitialSync(timeout: TimeInterval = 10) async {
        guard !hasCompletedInitialSync else { return }

        isSyncing = true

        // Start timeout task
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(timeout))
            if !Task.isCancelled {
                await MainActor.run {
                    // Even if sync times out, mark as complete so user can use the app
                    self.hasCompletedInitialSync = true
                    self.isSyncing = false
                }
            }
        }

        // Request sync from iPhone
        WatchSessionManager.shared.requestSync()

        // Wait a bit for the response
        try? await Task.sleep(for: .seconds(2))

        // If we received data, the callback will have set hasCompletedInitialSync
        if hasCompletedInitialSync {
            timeoutTask.cancel()
            return
        }

        // Keep waiting up to timeout
        try? await Task.sleep(for: .seconds(timeout - 2))

        timeoutTask.cancel()
        hasCompletedInitialSync = true
        isSyncing = false
    }

    /// Manually requests a refresh from iPhone
    func refreshAll() async {
        isSyncing = true
        WatchSessionManager.shared.requestSync()

        // Give it a moment to receive data
        try? await Task.sleep(for: .seconds(2))
        isSyncing = false
    }

    // MARK: - Hex Formatting

    /// Returns the hex string formatted according to user preference.
    func formattedHex(for color: WatchColor) -> String {
        let baseHex = color.hexString
        if includeHexPrefix {
            return baseHex
        } else {
            return baseHex.hasPrefix("#") ? String(baseHex.dropFirst()) : baseHex
        }
    }

    // MARK: - Haptic Feedback

    func playTapHaptic() {
        WKInterfaceDevice.current().play(.click)
    }

    func playSuccessHaptic() {
        WKInterfaceDevice.current().play(.success)
    }
}
