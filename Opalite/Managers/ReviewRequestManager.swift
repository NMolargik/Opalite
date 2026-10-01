//
//  ReviewRequestManager.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import StoreKit
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Manages App Store review requests using StoreKit.
///
/// This manager tracks when reviews have been requested to avoid prompting users
/// too frequently. Reviews are requested once per app version when the user
/// reaches engagement milestones (exactly 2 palettes or more than 8 colors).
@MainActor
@Observable
final class ReviewRequestManager {
    // MARK: - Private State

    @ObservationIgnored
    @AppStorage(AppStorageKeys.lastReviewRequestVersion)
    private var lastReviewRequestVersion: String = ""

    // MARK: - Computed Properties

    /// The current app version string (e.g., "1.2.3").
    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Whether a review has already been requested for the current app version.
    private var hasRequestedReviewThisVersion: Bool {
        lastReviewRequestVersion == currentAppVersion
    }

    // MARK: - Public API

    /// Evaluates whether to request an App Store review based on user engagement.
    ///
    /// Reviews are requested when the user has:
    /// - Exactly 2 palettes, OR
    /// - More than 8 colors
    ///
    /// Reviews are only requested once per app version to avoid annoying users.
    ///
    /// - Parameters:
    ///   - colorCount: The current number of colors in the user's portfolio.
    ///   - paletteCount: The current number of palettes in the user's portfolio.
    func evaluateReviewRequest(colorCount: Int, paletteCount: Int) {
        // Skip if already requested this version
        guard !hasRequestedReviewThisVersion else { return }

        // Check engagement criteria: exactly 2 palettes OR more than 8 colors
        guard paletteCount == 2 || colorCount > 8 else { return }

        requestReview()
    }

    // MARK: - Private Helpers

    /// Requests an App Store review and records the version.
    private func requestReview() {
        // Mark that we've requested a review for this version
        lastReviewRequestVersion = currentAppVersion

        // Request the review using StoreKit
        // Note: This only shows the review prompt in TestFlight/App Store builds,
        // not in debug/simulator builds
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            AppStore.requestReview(in: windowScene)
        }
        #endif
    }
}
