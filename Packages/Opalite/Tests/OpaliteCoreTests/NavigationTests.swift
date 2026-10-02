//
//  NavigationTests.swift
//  OpaliteCoreTests
//
//  DeepLink parsing, AppRouter, AppTab, destinations.
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("DeepLink")
struct DeepLinkTests {
    nonisolated static let everyLink: [DeepLink] = [
        .portfolio, .community, .search, .canvases, .settings, .onyx,
        .createColor, .createPalette, .samplePhoto, .swatchBar, .sharedImage,
        .color(UUID()), .palette(UUID()), .canvas(UUID()),
    ]

    @Test("Every link round-trips through its URL", arguments: everyLink)
    func roundTrip(link: DeepLink) {
        #expect(link.url.scheme == DeepLink.scheme)
        #expect(DeepLink(url: link.url) == link)
    }

    @Test("Host spellings", arguments: [
        ("opalite://portfolio", DeepLink.portfolio),
        ("opalite://community", .community),
        ("opalite://search", .search),
        ("opalite://canvases", .canvases),
        ("opalite://canvas", .canvases),
        ("opalite://settings", .settings),
        ("opalite://onyx", .onyx),
        ("opalite://createColor", .createColor),
        ("opalite://createcolor", .createColor),
        ("opalite://create-color", .createColor),
        ("opalite://createPalette", .createPalette),
        ("opalite://create-palette", .createPalette),
        ("opalite://samplePhoto", .samplePhoto),
        ("opalite://sample-photo", .samplePhoto),
        ("opalite://swatchBar", .swatchBar),
        ("opalite://swatch-bar", .swatchBar),
        ("opalite://sharedImage", .sharedImage),
        ("opalite://shared-image", .sharedImage),
        ("OPALITE://Portfolio", .portfolio),
    ])
    func hosts(text: String, expected: DeepLink) throws {
        let url = try #require(URL(string: text))
        #expect(DeepLink(url: url) == expected)
    }

    @Test func idLinksParseTheirUUID() throws {
        let id = UUID()
        #expect(DeepLink(url: URL(string: "opalite://color/\(id.uuidString)")!) == .color(id))
        #expect(DeepLink(url: URL(string: "opalite://palette/\(id.uuidString.lowercased())")!) == .palette(id))
        #expect(DeepLink(url: URL(string: "opalite://canvas/\(id.uuidString)")!) == .canvas(id))
    }

    @Test("Unknown or malformed URLs are rejected", arguments: [
        "opalite://color", "opalite://color/not-a-uuid", "opalite://palette/", "opalite://nowhere",
        "https://portfolio", "mailto:portfolio", "opalite://",
    ])
    func rejects(text: String) {
        guard let url = URL(string: text) else { return }
        #expect(DeepLink(url: url) == nil)
    }

    @Test func destinationTabs() {
        #expect(DeepLink.portfolio.destinationTab == .portfolio)
        #expect(DeepLink.color(UUID()).destinationTab == .portfolio)
        #expect(DeepLink.palette(UUID()).destinationTab == .portfolio)
        #expect(DeepLink.createColor.destinationTab == .portfolio)
        #expect(DeepLink.createPalette.destinationTab == .portfolio)
        #expect(DeepLink.samplePhoto.destinationTab == .portfolio)
        #expect(DeepLink.sharedImage.destinationTab == .portfolio)
        #expect(DeepLink.community.destinationTab == .community)
        #expect(DeepLink.search.destinationTab == .search)
        #expect(DeepLink.canvases.destinationTab == .canvas)
        #expect(DeepLink.canvas(UUID()).destinationTab == .canvas)
        #expect(DeepLink.settings.destinationTab == .settings)
        #expect(DeepLink.onyx.destinationTab == .settings)
        #expect(DeepLink.swatchBar.destinationTab == nil)
    }

    @Test func pendingHandOffThroughAStore() {
        let store = FakeKeyValueStore()
        #expect(DeepLink.takePending(from: store) == nil)
        let id = UUID()
        DeepLink.color(id).storePending(in: store)
        #expect(store.string(forKey: DeepLink.pendingDefaultsKey) == DeepLink.color(id).url.absoluteString)
        #expect(DeepLink.takePending(from: store) == .color(id))
        #expect(DeepLink.takePending(from: store) == nil, "taking consumes the hand-off")
        #expect(store.object(forKey: DeepLink.pendingDefaultsKey) == nil)
    }

    @Test func pendingHandOffToleratesGarbageAndNilStore() {
        let store = FakeKeyValueStore()
        store.set("opalite://nowhere", forKey: DeepLink.pendingDefaultsKey)
        #expect(DeepLink.takePending(from: store) == nil)
        #expect(store.object(forKey: DeepLink.pendingDefaultsKey) == nil, "even an unparseable value is consumed")
        DeepLink.portfolio.storePending(in: nil)
        #expect(DeepLink.takePending(from: nil) == nil)
    }

    @Test func userActivityTypesAreNamespaced() {
        #expect(UserActivityType.viewingColor.hasPrefix(AppGroup.bundleID))
        #expect(UserActivityType.viewingPalette.hasPrefix(AppGroup.bundleID))
        #expect(UserActivityType.swatchBar.hasPrefix(AppGroup.bundleID))
        #expect(Set([UserActivityType.viewingColor, UserActivityType.viewingPalette, UserActivityType.swatchBar]).count == 3)
    }
}

@Suite("AppRouter")
struct AppRouterTests {
    @Test func initialState() {
        let router = AppRouter()
        #expect(router.selectedTab == .portfolio)
        #expect(router.pendingDeepLink == nil)
        #expect(router.pendingPresentation == nil)
        #expect(router.badgeCounts.isEmpty)
    }

    @Test func selectChangesTab() {
        let router = AppRouter()
        router.select(.settings)
        #expect(router.selectedTab == .settings)
    }

    @Test func openingALinkJumpsToItsTabAndStagesIt() {
        let router = AppRouter()
        let id = UUID()
        router.open(.canvas(id))
        #expect(router.selectedTab == .canvas)
        #expect(router.pendingDeepLink == .canvas(id))
    }

    @Test func tablessLinksKeepTheCurrentTab() {
        let router = AppRouter()
        router.select(.community)
        router.open(.swatchBar)
        #expect(router.selectedTab == .community)
        #expect(router.pendingDeepLink == .swatchBar)
    }

    @Test func openURLParsesAndRoutes() {
        let router = AppRouter()
        #expect(router.open(url: URL(string: "opalite://settings")!))
        #expect(router.selectedTab == .settings && router.pendingDeepLink == .settings)
        #expect(!router.open(url: URL(string: "https://example.com")!))
        #expect(router.pendingDeepLink == .settings, "unknown URLs are ignored")
    }

    @Test func takePendingDeepLinkConsumes() {
        let router = AppRouter()
        router.open(.community)
        #expect(router.takePendingDeepLink() == .community)
        #expect(router.takePendingDeepLink() == nil)
        #expect(router.pendingDeepLink == nil)
    }

    @Test func presentationsAreStagedAndConsumed() {
        let router = AppRouter()
        router.present(.colorEditor)
        #expect(router.pendingPresentation == .colorEditor)
        router.requestPaywall(context: "Unlimited palettes")
        #expect(router.pendingPresentation == .paywall(context: "Unlimited palettes"), "a later presentation replaces the earlier one")
        #expect(router.takePendingPresentation() == .paywall(context: "Unlimited palettes"))
        #expect(router.takePendingPresentation() == nil)
    }

    @Test func laterLinksReplaceEarlierOnes() {
        let router = AppRouter()
        router.open(.community)
        router.open(.search)
        #expect(router.pendingDeepLink == .search)
        #expect(router.selectedTab == .search)
    }
}

@Suite("AppTab & destinations")
struct AppTabTests {
    @Test func keyboardNumbersAreUniqueAndOneBased() {
        let numbers = AppTab.allCases.map(\.keyboardNumber)
        #expect(Set(numbers) == Set(1...AppTab.allCases.count))
    }

    @Test func availableTabsAreASubsetOfAllCases() {
        #expect(!AppTab.available.isEmpty)
        #expect(Set(AppTab.available).isSubset(of: Set(AppTab.allCases)))
        #expect(AppTab.available.contains(.portfolio) && AppTab.available.contains(.settings))
    }

    @Test func identityAndSymbols() {
        #expect(AppTab.allCases.allSatisfy { $0.id == $0.rawValue && !$0.systemImage.isEmpty })
        #expect(Set(AppTab.allCases.map(\.systemImage)).count == AppTab.allCases.count)
    }

    @Test func tabsAreCodable() throws {
        let data = try JSONEncoder().encode([AppTab.canvas, .search])
        #expect(try JSONDecoder().decode([AppTab].self, from: data) == [.canvas, .search])
    }

    @Test func portfolioDestinationsAreCodableAndHashable() throws {
        let id = UUID()
        let destinations: [PortfolioDestination] = [.palette(id), .color(id), .canvas(id)]
        let data = try JSONEncoder().encode(destinations)
        #expect(try JSONDecoder().decode([PortfolioDestination].self, from: data) == destinations)
        #expect(Set(destinations).count == 3)
    }

    @Test func settingsDestinationsAreCodable() throws {
        let all: [SettingsDestination] = [.appearance, .accessibility, .onyx, .watch, .swatchBar, .communityAdmin, .about]
        let data = try JSONEncoder().encode(all)
        #expect(try JSONDecoder().decode([SettingsDestination].self, from: data) == all)
    }

    @Test func communityDestinationsHashByPayload() {
        let a = CommunityDestination.color(.sample)
        let b = CommunityDestination.color(.sample)
        let c = CommunityDestination.publisher(id: CommunityRecordID(recordName: "u"), displayName: "U")
        #expect(a == b)
        #expect(a != c)
        #expect(Set([a, b, c]).count == 2)
    }
}
