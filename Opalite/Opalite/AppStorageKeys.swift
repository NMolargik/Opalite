//
//  AppStorageKeys.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import Foundation

// MARK: - AppStorageKeys

/// Centralized constants for `@AppStorage` keys.
///
/// Using these constants ensures consistency across the app and prevents
/// typos in key names. All persistent user preferences should be added here.
///
/// ## Usage
/// ```swift
/// @AppStorage(AppStorageKeys.userName) private var userName: String = "User"
/// ```
enum AppStorageKeys {

    /// Whether the user has completed the onboarding flow.
    static let isOnboardingComplete = "isOnboardingComplete"

    /// The user's display name (shown on colors/palettes they create).
    static let userName = "userName"

    /// The app's color scheme preference (system, light, or dark).
    static let appTheme = "appTheme"

    /// The color blindness simulation mode for accessibility testing.
    static let colorBlindnessMode = "colorBlindnessMode"

    /// Whether to include the "#" prefix when copying hex codes.
    static let includeHexPrefix = "includeHexPrefix"

    /// Whether the user has been asked about their hex prefix preference.
    static let hasAskedHexPreference = "hasAskedHexPreference"

    /// The preferred swatch size in PortfolioView.
    static let swatchSize = "swatchSize"

    /// Whether to skip the SwatchBar info sheet and launch directly.
    static let skipSwatchBarConfirmation = "skipSwatchBarConfirmation"

    /// Custom order of palette UUIDs for display in PortfolioView.
    /// Stored as a JSON-encoded array of UUID strings.
    static let paletteOrder = "paletteOrder"

    /// The selected app icon variant (dark or light).
    static let appIcon = "appIcon"

    /// The app version when a review was last requested.
    static let lastReviewRequestVersion = "lastReviewRequestVersion"

    /// Whether we've attempted to fetch the user's display name from iCloud.
    static let hasAttemptedUserNameFetch = "hasAttemptedUserNameFetch"

    /// Whether the user has manually edited their display name.
    static let hasUserEditedDisplayName = "hasUserEditedDisplayName"

}
