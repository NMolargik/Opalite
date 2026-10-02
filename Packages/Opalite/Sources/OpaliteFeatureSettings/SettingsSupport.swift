//
//  SettingsSupport.swift
//  OpaliteFeatureSettings
//
//  The host-testable rules behind the Settings screens and the paywall: Onyx status
//  wording, the version string, iCloud and Apple Watch status wording, the paywall's plan
//  ordering and selection, restore outcomes, the profile-name commit, and outbound links.
//  No SwiftUI here, so `swift test` on macOS exercises every rule.
//

import Foundation
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared

// MARK: - Onyx status

/// What the Onyx row says for a given entitlement.
public struct OnyxStatus: Equatable {
    public let hasOnyx: Bool
    public let subscription: OnyxSubscription?

    public init(hasOnyx: Bool, subscription: OnyxSubscription?) {
        self.hasOnyx = hasOnyx
        self.subscription = hasOnyx ? subscription : nil
    }

    /// "Free", "Onyx Annual", or "Onyx Lifetime" (or "Onyx" for an unrecognized product).
    public var title: String {
        guard hasOnyx else { return String(localized: "Free") }
        return subscription?.displayName ?? String(localized: "Onyx")
    }

    /// The one-line explanation under the title.
    public var detail: String {
        guard hasOnyx else {
            return String(localized: "Unlimited palettes and canvases, Community saves, and pro export formats.")
        }
        switch subscription {
        case .annual: return String(localized: "Renews yearly. Manage or cancel anytime.")
        case .lifetime: return String(localized: "Yours forever. Thank you for supporting Opalite.")
        case nil: return String(localized: "Active on this Apple Account.")
        }
    }

    public var systemImage: String { hasOnyx ? "diamond.fill" : "diamond" }

    /// Whether to offer the paywall.
    public var showsUpgrade: Bool { !hasOnyx }

    /// Whether the App Store's manage-subscriptions sheet applies.
    public var canManageSubscription: Bool { hasOnyx && subscription == .annual }
}

// MARK: - Version

/// The marketing version and build number as shown in About.
nonisolated public struct AppVersionInfo: Equatable, Sendable {
    public let version: String
    public let build: String

    public init(version: String, build: String) {
        self.version = version
        self.build = build
    }

    /// Reads `CFBundleShortVersionString` / `CFBundleVersion`, falling back to "—".
    public init(bundle: Bundle = .main) {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        self.init(version: version.isEmpty ? "—" : version, build: build)
    }

    /// "2.1 (345)", or just "2.1" when the build is unknown.
    public var formatted: String {
        build.isEmpty ? version : "\(version) (\(build))"
    }

    /// "Version 2.1 (345)".
    public var subtitle: String { String(localized: "Version \(formatted)") }
}

// MARK: - iCloud

/// Wording for the iCloud section from the sync manager's status.
public enum CloudSyncPresentation {
    public static func title(for status: CloudSyncManager.SyncStatus) -> String {
        switch status {
        case .idle: String(localized: "Ready")
        case .syncing: String(localized: "Syncing…")
        case .synced: String(localized: "Up to Date")
        case .error: String(localized: "Needs Attention")
        case .offline: String(localized: "Offline")
        case .unavailable: String(localized: "Not Signed In")
        }
    }

    /// The section footer: what the status means and what, if anything, to do.
    public static func guidance(for status: CloudSyncManager.SyncStatus) -> String {
        switch status {
        case .idle, .synced, .syncing:
            String(localized: "Colors, palettes, and canvases sync through iCloud to every device signed in with your Apple Account. Free iCloud space must be available.")
        case .error(let message):
            String(localized: "iCloud reported a problem: \(message). Opalite keeps working on this device and retries automatically.")
        case .offline:
            String(localized: "You're offline. Changes are saved on this device and sync when a connection returns.")
        case .unavailable:
            String(localized: "Sign in to iCloud in the Settings app to sync your work between devices.")
        }
    }

    /// Whether "Sync Now" can do anything right now.
    public static func canSyncNow(_ status: CloudSyncManager.SyncStatus) -> Bool {
        switch status {
        case .idle, .synced, .error: true
        case .syncing, .offline, .unavailable: false
        }
    }
}

// MARK: - Apple Watch

/// Wording for the Apple Watch row and page.
nonisolated public struct WatchStatusPresentation: Equatable, Sendable {
    public let isPaired: Bool
    public let isWatchAppInstalled: Bool
    public let isReachable: Bool

    public init(isPaired: Bool, isWatchAppInstalled: Bool, isReachable: Bool) {
        self.isPaired = isPaired
        self.isWatchAppInstalled = isWatchAppInstalled && isPaired
        self.isReachable = isReachable && isPaired
    }

    /// The trailing value on the Settings row.
    public var summary: String {
        if !isPaired { return String(localized: "Not Paired") }
        if !isWatchAppInstalled { return String(localized: "App Not Installed") }
        return isReachable ? String(localized: "Connected") : String(localized: "Ready")
    }

    /// The status section's footer.
    public var guidance: String {
        if !isPaired {
            return String(localized: "Pair an Apple Watch with your iPhone to carry your colors on your wrist.")
        }
        if !isWatchAppInstalled {
            return String(localized: "Install Opalite from the Watch app on your iPhone to see your colors on your wrist.")
        }
        return String(localized: "Colors and palettes sync automatically while Opalite is open on your iPhone.")
    }

    public var systemImage: String {
        isWatchAppInstalled ? "applewatch.watchface" : "applewatch"
    }
}

// MARK: - Paywall

/// One purchasable Onyx plan, independent of StoreKit so the ordering rules are testable.
nonisolated public struct PaywallPlan: Identifiable, Equatable, Sendable {
    public let subscription: OnyxSubscription
    public let displayPrice: String

    public init(subscription: OnyxSubscription, displayPrice: String) {
        self.subscription = subscription
        self.displayPrice = displayPrice
    }

    public var id: String { subscription.rawValue }
    public var isSubscription: Bool { subscription.isSubscription }
}

/// The plans the paywall shows — only plans still sold — with a default selection.
nonisolated public struct PaywallCatalog: Equatable, Sendable {
    public let plans: [PaywallPlan]

    /// Keeps purchasable plans only (legacy subscriptions never show), dropping duplicates.
    public init(plans: [PaywallPlan]) {
        var seen: Set<String> = []
        self.plans = plans.filter { $0.subscription.isPurchasable && seen.insert($0.id).inserted }
    }

    public init(lifetime: PaywallPlan?) {
        self.init(plans: [lifetime].compactMap { $0 })
    }

    public var isEmpty: Bool { plans.isEmpty }

    /// The first plan offered.
    public var defaultSelectionID: String? { plans.first?.id }

    public func plan(withID id: String?) -> PaywallPlan? {
        guard let id else { return nil }
        return plans.first { $0.id == id }
    }

    /// Keeps the current selection while it's still offered; otherwise the default.
    public func resolvedSelection(current: String?) -> String? {
        if let current, plans.contains(where: { $0.id == current }) { return current }
        return defaultSelectionID
    }

    /// The purchase button's title for the selected plan.
    public static func callToAction(for plan: PaywallPlan?) -> String {
        guard let plan else { return String(localized: "Choose a Plan") }
        return plan.isSubscription ? String(localized: "Subscribe") : String(localized: "Purchase")
    }

    /// The App Store's required disclosure for the selected plan (one-time wording when
    /// nothing is selected yet, since only one-time purchases are sold).
    public static func legalText(for plan: PaywallPlan?) -> String {
        if let plan, plan.isSubscription {
            return String(localized: "Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel in Settings.")
        }
        return String(localized: "One-time purchase. Payment is charged to your Apple Account at confirmation.")
    }
}

/// What Onyx unlocks, shared by the paywall, the Onyx page, and the info sheet.
nonisolated public struct OnyxFeature: Identifiable, Equatable, Sendable {
    public let id: String
    public let systemImage: String
    public let title: String
    public let detail: String

    public init(id: String, systemImage: String, title: String, detail: String) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }

    public static var all: [OnyxFeature] {
        [
            OnyxFeature(
                id: "palettes",
                systemImage: "swatchpalette.fill",
                title: String(localized: "Unlimited Palettes"),
                detail: String(localized: "Go beyond \(OnyxGate.freePaletteLimit) palettes and organize as much as your work demands.")
            ),
            OnyxFeature(
                id: "canvases",
                systemImage: "pencil.and.scribble",
                title: String(localized: "Unlimited Canvases"),
                detail: String(localized: "Sketch on as many canvases as you like. The free tier includes one.")
            ),
            OnyxFeature(
                id: "community",
                systemImage: "person.2.fill",
                title: String(localized: "Save from the Community"),
                detail: String(localized: "Keep colors and palettes shared by other Opalite users in your own portfolio.")
            ),
            OnyxFeature(
                id: "export",
                systemImage: "square.and.arrow.up.fill",
                title: String(localized: "Pro Export Formats"),
                detail: String(localized: "Procreate, Adobe ASE, GIMP, SwiftUI, CSS, and PDF — ready for the tools you already use.")
            ),
            OnyxFeature(
                id: "future",
                systemImage: "sparkles",
                title: String(localized: "Everything Still to Come"),
                detail: String(localized: "New Onyx features are included as Opalite grows.")
            ),
        ]
    }
}

// MARK: - Restore purchases

/// The toast to show after a restore attempt.
nonisolated public enum RestoreOutcome: Equatable, Sendable {
    case failed
    case restored
    case alreadyActive
    case nothingToRestore

    public static func evaluate(hadOnyx: Bool, hasOnyx: Bool, failed: Bool) -> RestoreOutcome {
        if failed { return .failed }
        if hasOnyx { return hadOnyx ? .alreadyActive : .restored }
        return .nothingToRestore
    }

    /// The message for every outcome but `.failed` (which shows the error itself).
    public var message: String? {
        switch self {
        case .failed: nil
        case .restored: String(localized: "Onyx restored")
        case .alreadyActive: String(localized: "Onyx is already active")
        case .nothingToRestore: String(localized: "No purchases to restore")
        }
    }
}

// MARK: - Profile name

/// Commits the display name everywhere it's used: the portfolio's authorship stamp and
/// the Community publisher name follow each other.
public enum ProfileName {
    public static func commit(_ raw: String, portfolio: PortfolioModel, community: CommunityModel) {
        portfolio.setAuthorName(raw)
        community.publisherName = portfolio.authorName
    }
}

// MARK: - Links

/// Outbound links from About and the paywall.
nonisolated public enum SettingsLinks {
    public static let website = URL(string: "https://www.molargiksoftware.com")!
    public static let privacy = URL(string: "https://molargiksoftware.com/#/privacy")!
    public static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    public static let developer = URL(string: "https://www.linkedin.com/in/nicholas-molargik/")!
    /// Support routes through the publisher's site until a dedicated page exists.
    public static let support = website
    public static let deviceKit = URL(string: "https://github.com/devicekit/DeviceKit")!
}
