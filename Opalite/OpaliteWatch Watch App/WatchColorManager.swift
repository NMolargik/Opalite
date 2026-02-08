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

    /// Whether the most recent sync received data
    private var lastSyncReceivedData: Bool = false

    /// Color ID pending from a widget deep link
    var pendingDeepLinkColorID: UUID?

    /// Last successful sync timestamp
    var lastSyncTimestamp: Date? {
        WatchSessionManager.shared.lastSyncTimestamp
    }

    /// Whether cached data is available from a previous sync
    var hasCachedData: Bool {
        !colors.isEmpty || !palettes.isEmpty
    }

    /// Whether the paired iPhone is currently reachable
    var isPhoneReachable: Bool {
        WatchSessionManager.shared.isReachable
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

    /// Whether the app-level high contrast mode is enabled.
    var highContrastEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "highContrastEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "highContrastEnabled") }
    }

    // MARK: - Init

    init() {
        // Set up callback for when data is received from iPhone
        WatchSessionManager.shared.onDataReceived = { [weak self] colors, palettes in
            self?.colors = colors.sorted { $0.createdAt > $1.createdAt }
            self?.palettes = palettes.sorted { $0.createdAt > $1.createdAt }
            self?.hasCompletedInitialSync = true
            self?.isSyncing = false
            self?.lastSyncReceivedData = true
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
    }

    // MARK: - Sync

    /// Performs the initial sync from iPhone
    func performInitialSync(timeout: TimeInterval = 10) async {
        hasCompletedInitialSync = false
        isSyncing = true

        // If iPhone isn't reachable and we have cached data, use a short timeout
        // so the user quickly sees their cached colors instead of waiting
        let effectiveTimeout = (!isPhoneReachable && hasCachedData) ? 2.0 : timeout

        // Start timeout task
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(effectiveTimeout))
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
        let initialWait = min(2.0, effectiveTimeout)
        try? await Task.sleep(for: .seconds(initialWait))

        // If we received data, the callback will have set hasCompletedInitialSync
        if hasCompletedInitialSync {
            timeoutTask.cancel()
            return
        }

        // Keep waiting up to timeout
        let remaining = effectiveTimeout - initialWait
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        timeoutTask.cancel()
        hasCompletedInitialSync = true
        isSyncing = false
    }

    /// Manually requests a refresh from iPhone
    func refreshAll() async {
        isSyncing = true
        lastSyncReceivedData = false
        WatchSessionManager.shared.requestSync()

        // Give it a moment to receive data
        try? await Task.sleep(for: .seconds(2))
        if !lastSyncReceivedData {
            playFailureHaptic()
        }
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

    func playFailureHaptic() {
        WKInterfaceDevice.current().play(.failure)
    }

    func playNavigationHaptic() {
        WKInterfaceDevice.current().play(.directionUp)
    }
}
