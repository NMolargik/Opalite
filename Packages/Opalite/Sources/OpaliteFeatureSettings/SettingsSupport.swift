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

    /// "Free" or "Onyx Lifetime" ("Onyx" for a legacy or unrecognized product).
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
        case .lifetime: return String(localized: "Yours forever. Thank you for supporting Opalite.")
        case .annual, nil: return String(localized: "Active on this Apple Account.")
        }
    }

    public var systemImage: String { hasOnyx ? "diamond.fill" : "diamond" }

    /// Whether to offer the paywall.
    public var showsUpgrade: Bool { !hasOnyx }

    /// Whether the App Store's manage-subscriptions sheet applies — only for the legacy
    /// annual subscribers, who still need a way to manage what they already pay for.
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

/// Whether the iCloud section can act on the sync manager's status.
public enum CloudSyncPresentation {
    /// Whether "Sync Now" can do anything right now.
    public static func canSyncNow(_ status: CloudSyncManager.SyncStatus) -> Bool {
        switch status {
        case .idle, .synced, .error: true
        case .syncing, .offline, .unavailable: false
        }
    }
}

// MARK: - iCloud state

/// The single plain state the iCloud row shows, folded from what the sync manager reports.
/// Account, storage mode, reachability and the event stream all feed it; nothing is guessed.
public enum ICloudState: Equatable, Sendable {
    case syncing
    case upToDate
    /// Signed in with nothing reported yet this launch.
    case ready
    case notSignedIn
    case thisDeviceOnly
    case offline
    case error

    /// Precedence: no account explains everything else, then a store that can't sync, then
    /// connectivity, then the event stream's own state.
    public static func resolve(status: CloudSyncManager.SyncStatus, storeMode: CloudSyncManager.StoreMode) -> ICloudState {
        if status == .unavailable { return .notSignedIn }
        if storeMode != .cloudKit { return .thisDeviceOnly }
        switch status {
        case .offline: return .offline
        case .error: return .error
        case .syncing: return .syncing
        case .synced: return .upToDate
        case .idle: return .ready
        case .unavailable: return .notSignedIn
        }
    }

    public var title: String {
        switch self {
        case .syncing: String(localized: "Syncing…")
        case .upToDate: String(localized: "Up to Date")
        case .ready: String(localized: "Ready")
        case .notSignedIn: String(localized: "Not Signed In")
        case .thisDeviceOnly: String(localized: "This Device Only")
        case .offline: String(localized: "Offline")
        case .error: String(localized: "Error")
        }
    }

    public var systemImage: String {
        switch self {
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .upToDate: "checkmark.icloud"
        case .ready: "icloud"
        case .notSignedIn: "person.icloud"
        case .thisDeviceOnly: "icloud.slash"
        case .offline: "icloud.slash"
        case .error: "exclamationmark.icloud"
        }
    }

    /// Whether the value is drawn as a warning.
    public var needsAttention: Bool {
        switch self {
        case .notSignedIn, .thisDeviceOnly, .error: true
        case .syncing, .upToDate, .ready, .offline: false
        }
    }

    /// The one short footer line, only when the user has something to do.
    public var footer: String? {
        switch self {
        case .notSignedIn: String(localized: "Sign in to iCloud in the Settings app to sync between devices.")
        case .thisDeviceOnly: String(localized: "Your library is saved on this device only. Restart Opalite after signing in to iCloud.")
        case .error: String(localized: "iCloud hit a problem. Open Sync Details to see it.")
        case .syncing, .upToDate, .ready, .offline: nil
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

    /// "One-time $9.99. No subscription."
    public var priceLine: String { String(localized: "One-time \(displayPrice). No subscription.") }
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

    /// The purchase button's title. Only one-time purchases are sold, so it never says "Subscribe".
    public static func callToAction(for plan: PaywallPlan?) -> String {
        String(localized: "Purchase")
    }

    /// The App Store's required disclosure. Only one-time purchases are sold.
    public static func legalText(for plan: PaywallPlan?) -> String {
        String(localized: "One-time purchase. Payment is charged to your Apple Account at confirmation.")
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

// MARK: - Sync health

/// Plain-language wording for the iCloud sync-health rows. Each value says only what the
/// system reported: nothing is estimated, and "not yet" is shown instead of a guess.
public enum SyncHealthPresentation {
    public static func storage(_ mode: CloudSyncManager.StoreMode) -> String {
        switch mode {
        case .cloudKit: String(localized: "Syncing with iCloud")
        case .localOnly: String(localized: "This Device Only")
        case .inMemory: String(localized: "Temporary")
        }
    }

    /// "Today at 9:41 AM", or "Not yet" when iCloud hasn't reported a finished sync since Opalite opened.
    public static func lastSynced(_ date: Date?) -> String {
        guard let date else { return String(localized: "Not Yet This Session") }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// The last error CloudKit reported, with when it happened and whether a later sync succeeded.
    public static func lastProblem(_ error: CloudSyncManager.SyncErrorRecord, lastSuccess: Date?) -> String {
        let when = error.date.formatted(date: .abbreviated, time: .shortened)
        if let lastSuccess, lastSuccess > error.date {
            return String(localized: "\(error.message) (\(when), since resolved)")
        }
        return String(localized: "\(error.message) (\(when))")
    }
}

// MARK: - Backups

public enum BackupPresentation {
    /// `String(localized:)` leaves `^[…](inflect: true)` markup in the text; an attributed
    /// string applies the grammar agreement, so plain strings go through one.
    private static func resolved(_ text: AttributedString) -> String { String(text.characters) }

    public static func counts(_ header: BackupHeader) -> String {
        resolved(AttributedString(localized: "^[\(header.colorCount) color](inflect: true), ^[\(header.paletteCount) palette](inflect: true)"))
    }

    public static func reason(_ reason: BackupReason) -> String {
        switch reason {
        case .automatic: String(localized: "Automatic")
        case .manual: String(localized: "Back Up Now")
        case .beforeDelete: String(localized: "Before deleting")
        case .imported: String(localized: "Imported")
        }
    }

    public static func restoreResult(_ summary: RestoreSummary) -> String {
        if !summary.addedAnything { return String(localized: "Nothing to restore. Everything in this backup is already in your library.") }
        return resolved(AttributedString(localized: "Restored ^[\(summary.colorsAdded) color](inflect: true) and ^[\(summary.palettesAdded) palette](inflect: true)"))
    }
}
