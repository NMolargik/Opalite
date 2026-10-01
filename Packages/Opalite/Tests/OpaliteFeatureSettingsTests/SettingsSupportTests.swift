//
//  SettingsSupportTests.swift
//  OpaliteFeatureSettingsTests
//
//  Host tests for the rules behind Settings and the paywall: Onyx status wording,
//  version formatting, iCloud / watch wording, plan ordering and selection, restore
//  outcomes, and the profile-name commit through the shared models.
//

import Foundation
import Testing
import OpaliteCore
import OpaliteServices
import OpaliteFeatureShared
@testable import OpaliteFeatureSettings

// MARK: - Onyx status

@Suite("Onyx status")
struct OnyxStatusTests {
    @Test func freeTier() {
        let status = OnyxStatus(hasOnyx: false, subscription: nil)
        #expect(status.title == "Free")
        #expect(status.showsUpgrade)
        #expect(!status.canManageSubscription)
        #expect(status.systemImage == "diamond")
    }

    @Test func annual() {
        let status = OnyxStatus(hasOnyx: true, subscription: .annual)
        #expect(status.title == "Onyx Annual")
        #expect(!status.showsUpgrade)
        #expect(status.canManageSubscription)
        #expect(status.systemImage == "diamond.fill")
    }

    @Test func lifetime() {
        let status = OnyxStatus(hasOnyx: true, subscription: .lifetime)
        #expect(status.title == "Onyx Lifetime")
        #expect(!status.canManageSubscription)
    }

    @Test func unknownProductStillReadsAsOnyx() {
        let status = OnyxStatus(hasOnyx: true, subscription: nil)
        #expect(status.title == "Onyx")
        #expect(!status.showsUpgrade)
    }

    @Test func subscriptionIsIgnoredWithoutEntitlement() {
        let status = OnyxStatus(hasOnyx: false, subscription: .lifetime)
        #expect(status.subscription == nil)
        #expect(status.title == "Free")
    }
}

// MARK: - Version

@Suite("App version")
struct AppVersionInfoTests {
    @Test func formatsVersionAndBuild() {
        let info = AppVersionInfo(version: "2.1", build: "345")
        #expect(info.formatted == "2.1 (345)")
        #expect(info.subtitle == "Version 2.1 (345)")
    }

    @Test func omitsEmptyBuild() {
        #expect(AppVersionInfo(version: "2.1", build: "").formatted == "2.1")
    }

    @Test func fallsBackWhenBundleHasNoVersion() {
        let info = AppVersionInfo(bundle: Bundle(for: BundleAnchor.self))
        #expect(!info.version.isEmpty)
        #expect(!info.formatted.isEmpty)
    }

    private final class BundleAnchor {}
}

// MARK: - iCloud

@Suite("iCloud wording")
struct CloudSyncPresentationTests {
    @Test func titles() {
        #expect(CloudSyncPresentation.title(for: .idle) == "Ready")
        #expect(CloudSyncPresentation.title(for: .syncing) == "Syncing…")
        #expect(CloudSyncPresentation.title(for: .synced(.now)) == "Up to Date")
        #expect(CloudSyncPresentation.title(for: .error("x")) == "Needs Attention")
        #expect(CloudSyncPresentation.title(for: .offline) == "Offline")
        #expect(CloudSyncPresentation.title(for: .unavailable) == "Not Signed In")
    }

    @Test func syncNowOnlyWhenItCanDoSomething() {
        #expect(CloudSyncPresentation.canSyncNow(.idle))
        #expect(CloudSyncPresentation.canSyncNow(.synced(.now)))
        #expect(CloudSyncPresentation.canSyncNow(.error("x")))
        #expect(!CloudSyncPresentation.canSyncNow(.syncing))
        #expect(!CloudSyncPresentation.canSyncNow(.offline))
        #expect(!CloudSyncPresentation.canSyncNow(.unavailable))
    }

    @Test func errorGuidanceCarriesTheMessage() {
        #expect(CloudSyncPresentation.guidance(for: .error("Quota exceeded")).contains("Quota exceeded"))
        #expect(CloudSyncPresentation.guidance(for: .unavailable).contains("Sign in"))
    }
}

// MARK: - Apple Watch

@Suite("Apple Watch wording")
struct WatchStatusPresentationTests {
    @Test func notPaired() {
        let status = WatchStatusPresentation(isPaired: false, isWatchAppInstalled: true, isReachable: true)
        #expect(status.summary == "Not Paired")
        #expect(!status.isWatchAppInstalled, "installed/reachable can't be true without pairing")
        #expect(!status.isReachable)
    }

    @Test func pairedWithoutApp() {
        let status = WatchStatusPresentation(isPaired: true, isWatchAppInstalled: false, isReachable: false)
        #expect(status.summary == "App Not Installed")
        #expect(status.guidance.contains("Install"))
    }

    @Test func installed() {
        #expect(WatchStatusPresentation(isPaired: true, isWatchAppInstalled: true, isReachable: true).summary == "Connected")
        #expect(WatchStatusPresentation(isPaired: true, isWatchAppInstalled: true, isReachable: false).summary == "Ready")
    }
}

// MARK: - Paywall

@Suite("Paywall catalog")
struct PaywallCatalogTests {
    private let annual = PaywallPlan(subscription: .annual, displayPrice: "$4.99")
    private let lifetime = PaywallPlan(subscription: .lifetime, displayPrice: "$19.99")

    @Test func ordersAnnualBeforeLifetimeRegardlessOfInput() {
        let catalog = PaywallCatalog(plans: [lifetime, annual])
        #expect(catalog.plans.map(\.subscription) == [.annual, .lifetime])
    }

    @Test func dropsDuplicates() {
        let catalog = PaywallCatalog(plans: [annual, annual, lifetime])
        #expect(catalog.plans.count == 2)
    }

    @Test func defaultsToAnnual() {
        #expect(PaywallCatalog(annual: annual, lifetime: lifetime).defaultSelectionID == annual.id)
        #expect(PaywallCatalog(annual: nil, lifetime: lifetime).defaultSelectionID == lifetime.id)
        #expect(PaywallCatalog(annual: nil, lifetime: nil).defaultSelectionID == nil)
        #expect(PaywallCatalog(annual: nil, lifetime: nil).isEmpty)
    }

    @Test func keepsCurrentSelectionWhileOffered() {
        let catalog = PaywallCatalog(annual: annual, lifetime: lifetime)
        #expect(catalog.resolvedSelection(current: lifetime.id) == lifetime.id)
        #expect(catalog.resolvedSelection(current: "gone") == annual.id)
        #expect(catalog.resolvedSelection(current: nil) == annual.id)
    }

    @Test func callToActionFollowsPlanKind() {
        #expect(PaywallCatalog.callToAction(for: annual) == "Subscribe")
        #expect(PaywallCatalog.callToAction(for: lifetime) == "Purchase")
        #expect(PaywallCatalog.callToAction(for: nil) == "Choose a Plan")
    }

    @Test func legalTextDistinguishesOneTimePurchase() {
        #expect(PaywallCatalog.legalText(for: lifetime).contains("One-time"))
        #expect(PaywallCatalog.legalText(for: annual).contains("renew"))
        #expect(PaywallCatalog.legalText(for: nil).contains("renew"))
    }

    @Test func badgesAndIdentity() {
        #expect(lifetime.isBestValue)
        #expect(!annual.isBestValue)
        #expect(annual.id == OnyxSubscription.annual.rawValue)
        #expect(annual.isSubscription)
        #expect(!lifetime.isSubscription)
    }

    @Test func featuresAreUniqueAndNonEmpty() {
        let features = OnyxFeature.all
        #expect(features.count == 5)
        #expect(Set(features.map(\.id)).count == features.count)
        #expect(features.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }
}

// MARK: - Restore

@Suite("Restore outcome")
struct RestoreOutcomeTests {
    @Test func outcomes() {
        #expect(RestoreOutcome.evaluate(hadOnyx: false, hasOnyx: false, failed: true) == .failed)
        #expect(RestoreOutcome.evaluate(hadOnyx: false, hasOnyx: true, failed: false) == .restored)
        #expect(RestoreOutcome.evaluate(hadOnyx: true, hasOnyx: true, failed: false) == .alreadyActive)
        #expect(RestoreOutcome.evaluate(hadOnyx: false, hasOnyx: false, failed: false) == .nothingToRestore)
    }

    @Test func failureTakesPrecedence() {
        #expect(RestoreOutcome.evaluate(hadOnyx: true, hasOnyx: true, failed: true) == .failed)
        #expect(RestoreOutcome.failed.message == nil)
        #expect(RestoreOutcome.restored.message == "Onyx restored")
    }
}

// MARK: - Profile name

@Suite("Profile name")
struct ProfileNameTests {
    @Test func communityPublisherFollowsThePortfolioName() {
        let env = PreviewEnvironment(seeded: false)
        ProfileName.commit("  Nick Molargik  ", portfolio: env.portfolio, community: env.community)
        #expect(env.portfolio.authorName == "Nick Molargik")
        #expect(env.community.publisherName == "Nick Molargik")
        #expect(env.defaults.string(forKey: AppStorageKeys.userName) == "Nick Molargik")
    }

    @Test func emptyNameFallsBackForBoth() {
        let env = PreviewEnvironment(seeded: false)
        ProfileName.commit("   ", portfolio: env.portfolio, community: env.community)
        #expect(env.portfolio.authorName == Authorship.anonymous.displayName)
        #expect(env.community.publisherName == env.portfolio.authorName)
    }
}

// MARK: - Links

@Suite("Links")
struct SettingsLinksTests {
    @Test func allLinksAreHTTPS() {
        for url in [SettingsLinks.website, SettingsLinks.privacy, SettingsLinks.terms, SettingsLinks.developer, SettingsLinks.support, SettingsLinks.deviceKit] {
            #expect(url.scheme == "https")
        }
    }
}
