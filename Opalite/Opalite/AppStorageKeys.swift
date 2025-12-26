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
}
