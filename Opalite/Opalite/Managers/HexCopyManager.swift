//
//  HexCopyManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/27/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
class HexCopyManager {

    // MARK: - State

    /// Whether to show the first-time preference alert.
    var showPreferenceAlert: Bool = false

    /// The color pending copy while waiting for user preference choice.
    var pendingCopyColor: OpaliteColor?

    // MARK: - Preferences

    /// Whether to include the "#" prefix when copying hex codes.
    /// Defaults to true.
    var includeHexPrefix: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageKeys.includeHexPrefix) }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageKeys.includeHexPrefix) }
    }

    /// Whether the user has already been asked about their hex prefix preference.
    private var hasAskedHexPreference: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageKeys.hasAskedHexPreference) }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageKeys.hasAskedHexPreference) }
    }

    // MARK: - Initialization

    init() {
        // Set default value for includeHexPrefix if not previously set
        if !UserDefaults.standard.bool(forKey: "hasSetHexPrefixDefault") {
            UserDefaults.standard.set(true, forKey: AppStorageKeys.includeHexPrefix)
            UserDefaults.standard.set(true, forKey: "hasSetHexPrefixDefault")
        }
    }

    // MARK: - Copy Methods

    /// Copies the hex code for the given color, respecting user preferences.
    /// On first copy, shows an alert to ask user preference.
    func copyHex(for color: OpaliteColor) {
        if !hasAskedHexPreference {
            // First time copying - show the preference alert
            pendingCopyColor = color
            showPreferenceAlert = true
        } else {
            // Preference already set - copy directly
            performCopy(for: color)
        }
    }

    /// Called when user chooses to include the "#" prefix.
    func userChoseIncludePrefix() {
        hasAskedHexPreference = true
        includeHexPrefix = true

        if let color = pendingCopyColor {
            performCopy(for: color)
            pendingCopyColor = nil
        }
    }

    /// Called when user chooses to exclude the "#" prefix.
    func userChoseExcludePrefix() {
        hasAskedHexPreference = true
        includeHexPrefix = false

        if let color = pendingCopyColor {
            performCopy(for: color)
            pendingCopyColor = nil
        }
    }

    /// Actually copies the hex to the clipboard.
    private func performCopy(for color: OpaliteColor) {
        let hex = formattedHex(for: color)

        #if os(iOS) || os(visionOS)
        UIPasteboard.general.string = hex
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
        #endif
    }

    /// Returns the hex string formatted according to user preference.
    func formattedHex(for color: OpaliteColor) -> String {
        let baseHex = color.hexString
        if includeHexPrefix {
            // hexString already includes "#", so return as-is
            return baseHex
        } else {
            // Remove the "#" prefix if present
            return baseHex.hasPrefix("#") ? String(baseHex.dropFirst()) : baseHex
        }
    }
}
