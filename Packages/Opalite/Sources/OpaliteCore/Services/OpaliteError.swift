//
//  OpaliteError.swift
//  OpaliteCore
//
//  User-facing failures outside persistence: import/export, subscriptions, Community.
//  Each carries a system image for the error toast.
//

import Foundation

nonisolated public enum OpaliteError: LocalizedError, Equatable, Sendable {
    // Import / export
    case importFailed(reason: String)
    case exportFailed(reason: String)
    case pdfExportFailed

    // Subscription
    case subscriptionLoadFailed
    case subscriptionPurchaseFailed
    case subscriptionRestoreFailed
    case subscriptionVerificationFailed

    // Community
    case communityFetchFailed(reason: String)
    case communityPublishFailed(reason: String)
    case communityDeleteFailed(reason: String)
    case communityReportFailed(reason: String)
    case communityRateLimited
    case communityRequiresOnyx
    case communityColorAlreadyExists
    case communityPaletteAlreadyExists
    case communityNotSignedIn
    case communityOffline

    // Limits
    case paletteLimitReached
    case canvasLimitReached

    // Generic
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .importFailed(let reason): String(localized: "Import failed: \(reason)")
        case .exportFailed(let reason): String(localized: "Export failed: \(reason)")
        case .pdfExportFailed: String(localized: "Unable to export PDF")
        case .subscriptionLoadFailed: String(localized: "Unable to load Onyx options")
        case .subscriptionPurchaseFailed: String(localized: "Purchase could not be completed")
        case .subscriptionRestoreFailed: String(localized: "Unable to restore purchases")
        case .subscriptionVerificationFailed: String(localized: "Purchase verification failed")
        case .communityFetchFailed(let reason): String(localized: "Couldn't load content: \(reason)")
        case .communityPublishFailed(let reason): String(localized: "Publish failed: \(reason)")
        case .communityDeleteFailed(let reason): String(localized: "Delete failed: \(reason)")
        case .communityReportFailed(let reason): String(localized: "Report failed: \(reason)")
        case .communityRateLimited: String(localized: "Slow down, try again soon")
        case .communityRequiresOnyx: String(localized: "Onyx required")
        case .communityColorAlreadyExists: String(localized: "Color already saved")
        case .communityPaletteAlreadyExists: String(localized: "Palette already saved")
        case .communityNotSignedIn: String(localized: "Sign in to iCloud")
        case .communityOffline: String(localized: "You're offline")
        case .paletteLimitReached: String(localized: "Creating more palettes requires Onyx")
        case .canvasLimitReached: String(localized: "Unlimited canvases require Onyx")
        case .unknown(let message): message
        }
    }

    public var systemImage: String {
        switch self {
        case .importFailed: "square.and.arrow.down.fill"
        case .exportFailed, .pdfExportFailed: "square.and.arrow.up.fill"
        case .subscriptionLoadFailed, .subscriptionPurchaseFailed, .subscriptionRestoreFailed, .subscriptionVerificationFailed: "creditcard.fill"
        case .communityFetchFailed, .communityPublishFailed, .communityDeleteFailed, .communityReportFailed: "person.2"
        case .communityRateLimited: "clock.fill"
        case .communityRequiresOnyx, .paletteLimitReached, .canvasLimitReached: "lock.fill"
        case .communityColorAlreadyExists, .communityPaletteAlreadyExists: "doc.on.doc.fill"
        case .communityNotSignedIn, .communityOffline: "icloud.slash.fill"
        case .unknown: "exclamationmark.triangle.fill"
        }
    }

    /// Whether the fix is buying Onyx (the toast offers the paywall).
    public var requiresOnyx: Bool {
        switch self {
        case .communityRequiresOnyx, .paletteLimitReached, .canvasLimitReached: true
        default: false
        }
    }
}
