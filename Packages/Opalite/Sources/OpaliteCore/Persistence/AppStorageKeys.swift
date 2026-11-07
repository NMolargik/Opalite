//
//  AppStorageKeys.swift
//  OpaliteCore
//
//  Centralized `@AppStorage` / UserDefaults keys. The string values are shipping keys —
//  renaming one silently resets that preference for every existing user.
//

import Foundation

nonisolated public enum AppStorageKeys {
    // MARK: - Lifecycle
    public static let isOnboardingComplete = "isOnboardingComplete"
    public static let lastReviewRequestVersion = "lastReviewRequestVersion"
    /// The version that already asked for a review after a Procreate/ASE export.
    public static let lastExportReviewRequestVersion = "lastExportReviewRequestVersion"
    public static let hasPromptedForCommunityName = "hasPromptedForCommunityName"

    // MARK: - Identity & appearance
    public static let userName = "userName"
    public static let appTheme = "appTheme"
    public static let appIcon = "appIcon"
    public static let colorBlindnessMode = "colorBlindnessMode"

    // MARK: - Portfolio
    public static let swatchSize = "swatchSize"
    /// JSON-encoded `[UUID]` giving the user's palette order in the Portfolio.
    public static let paletteOrder = "paletteOrder"

    // MARK: - Hex copying
    public static let includeHexPrefix = "includeHexPrefix"
    public static let hasAskedHexPreference = "hasAskedHexPreference"
    public static let hasSetHexPrefixDefault = "hasSetHexPrefixDefault"

    // MARK: - SwatchBar
    public static let skipSwatchBarConfirmation = "skipSwatchBarConfirmation"
    public static let swatchBarSwatchSize = "swatchBarSwatchSize"

    // MARK: - Mac eyedropper
    public static let eyedropperHotkey = "eyedropperHotkey"
    public static let eyedropperCopyFormat = "eyedropperCopyFormat"
    public static let eyedropperAutoCopy = "eyedropperAutoCopy"
    public static let eyedropperKeepSwatchBarHidden = "eyedropperKeepSwatchBarHidden"

    // MARK: - Watch relay
    public static let lastWatchSyncTimestamp = "lastWatchSyncTimestamp"
    public static let lastWatchSyncColorCount = "lastWatchSyncColorCount"
    public static let lastWatchSyncPaletteCount = "lastWatchSyncPaletteCount"
    public static let pendingWatchHexCopy = "pendingWatchHexCopy"

    // MARK: - Watch app (its own defaults)
    public static let watchHighContrastEnabled = "highContrastEnabled"
}
