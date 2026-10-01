//
//  CommunityFeedTests.swift
//  OpaliteFeatureCommunityTests
//
//  Host tests for the Community feature's pure logic and its loading choreography over
//  `CommunityModel`, wired through `PreviewEnvironment` and `FakeCommunityService`.
//

import Foundation
import Testing
import OpaliteCore
import OpaliteFeatureShared
@testable import OpaliteFeatureCommunity

// MARK: - Feed loading

@Suite("Community feed")
struct CommunityFeedTests {
    @Test("First page of colors loads through the feed model")
    func feedLoadsColors() async {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()

        #expect(model.status(in: environment.community) != .content)
        await model.ensureLoaded(in: environment.community)

        #expect(environment.community.colors.count == 2)
        #expect(model.itemCount(in: environment.community) == 2)
        #expect(model.status(in: environment.community) == .content)
        #expect(model.hasMore(in: environment.community) == false)
    }

    @Test("Switching to palettes loads them with their colors")
    func feedLoadsPalettes() async {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()
        model.segment = .palettes

        await model.ensureLoaded(in: environment.community)

        #expect(environment.community.palettes.count == 1)
        #expect(environment.community.palettes.first?.hasLoadedColors == true)
        #expect(model.status(in: environment.community) == .content)
    }

    @Test("Already-loaded segments are not refetched on appear")
    func ensureLoadedIsIdempotent() async {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()
        await model.ensureLoaded(in: environment.community)
        let extra = CommunityColor(
            id: CommunityRecordID(recordName: "late"), originalColorID: UUID(), name: "Late", notes: nil,
            red: 0.1, green: 0.1, blue: 0.1, alpha: 1, publisherName: "Someone",
            publisherUserRecordID: CommunityRecordID(recordName: "other"), originalCreatedAt: .now, publishedAt: .now
        )
        environment.communityService.colors.append(extra)

        await model.ensureLoaded(in: environment.community)
        #expect(environment.community.colors.count == 2)

        await model.refresh(in: environment.community)
        #expect(environment.community.colors.count == 3)
    }

    @Test("A failed fetch with nothing cached reports the failed status")
    func failedFetchStatus() async {
        let environment = PreviewEnvironment()
        environment.communityService.failure = .communityFetchFailed(reason: "boom")
        let model = CommunityFeedModel()

        await model.ensureLoaded(in: environment.community)

        #expect(environment.community.colors.isEmpty)
        #expect(model.status(in: environment.community) == .failed)
    }

    @Test("Sorting re-orders the cached set without refetching")
    func sortReorders() async {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()
        await model.ensureLoaded(in: environment.community)

        model.sort(by: .alphabetical, in: environment.community)
        #expect(environment.community.sortOption == .alphabetical)
        #expect(environment.community.colors.map(\.displayName) == ["Ocean Blue", "Sunset Orange"])

        model.sort(by: .oldest, in: environment.community)
        #expect(environment.community.colors.first?.displayName == "Sunset Orange")
    }
}

// MARK: - Search

@Suite("Community search")
struct CommunitySearchTests {
    @Test("Submitting a query filters colors by name")
    func searchFiltersByName() async {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()
        await model.ensureLoaded(in: environment.community)

        model.searchText = "ocean"
        await model.submitSearch(in: environment.community)

        #expect(environment.community.isShowingSearchResults)
        #expect(environment.community.colors.map(\.displayName) == ["Ocean Blue"])
        #expect(model.hasMore(in: environment.community) == false)
        #expect(model.status(in: environment.community) == .content)
    }

    @Test("A query with no matches shows the no-results state")
    func searchNoResults() async {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()
        await model.ensureLoaded(in: environment.community)

        model.searchText = "zebra"
        await model.submitSearch(in: environment.community)

        #expect(environment.community.colors.isEmpty)
        #expect(model.status(in: environment.community) == .noResults)
    }

    @Test("Clearing the query restores the cached set")
    func clearingRestores() async {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()
        await model.ensureLoaded(in: environment.community)

        model.searchText = "ocean"
        await model.submitSearch(in: environment.community)
        #expect(environment.community.colors.count == 1)

        model.searchText = ""
        await model.submitSearch(in: environment.community)
        #expect(environment.community.colors.count == 2)
        #expect(environment.community.isShowingSearchResults == false)
    }

    @Test("Typing is debounced and searches after the pause")
    func debouncedSearch() async throws {
        let environment = PreviewEnvironment()
        let model = CommunityFeedModel()
        await model.ensureLoaded(in: environment.community)

        model.searchText = "sun"
        model.searchTextChanged(in: environment.community)
        #expect(environment.community.colors.count == 2)

        try await Task.sleep(for: CommunityFeedModel.searchDebounce + .milliseconds(150))
        #expect(environment.community.colors.map(\.displayName) == ["Sunset Orange"])
    }
}

// MARK: - Feed status

@Suite("Community feed status")
struct CommunityFeedStatusTests {
    @Test("Content wins whenever there are items")
    func contentWins() {
        #expect(CommunityFeedStatus.resolve(isConnected: false, isSignedIn: false, isLoading: true, itemCount: 1, hasError: true, isSearching: true) == .content)
    }

    @Test("Offline precedes sign-in, loading, and errors")
    func offlineFirst() {
        #expect(CommunityFeedStatus.resolve(isConnected: false, isSignedIn: false, isLoading: true, itemCount: 0, hasError: true, isSearching: false) == .offline)
        #expect(CommunityFeedStatus.resolve(isConnected: true, isSignedIn: false, isLoading: true, itemCount: 0, hasError: false, isSearching: false) == .signedOut)
        #expect(CommunityFeedStatus.resolve(isConnected: true, isSignedIn: true, isLoading: true, itemCount: 0, hasError: false, isSearching: false) == .loading)
        #expect(CommunityFeedStatus.resolve(isConnected: true, isSignedIn: true, isLoading: false, itemCount: 0, hasError: false, isSearching: true) == .noResults)
        #expect(CommunityFeedStatus.resolve(isConnected: true, isSignedIn: true, isLoading: false, itemCount: 0, hasError: true, isSearching: false) == .failed)
        #expect(CommunityFeedStatus.resolve(isConnected: true, isSignedIn: true, isLoading: false, itemCount: 0, hasError: false, isSearching: false) == .empty)
    }

    @Test("A signed-out account surfaces through the feed model")
    func signedOutThroughModel() async {
        let environment = PreviewEnvironment()
        environment.communityService.userID = nil
        await environment.community.refreshIdentity()
        let model = CommunityFeedModel()

        #expect(environment.community.isUserSignedIn == false)
        #expect(model.status(in: environment.community) == .signedOut)
    }
}

// MARK: - Display-name prompt

@Suite("Community name prompt")
struct CommunityNamePromptTests {
    @Test("Prompts only until it has been shown once")
    func promptsOnce() {
        #expect(CommunityNameDraft.shouldPrompt(hasPrompted: false))
        #expect(!CommunityNameDraft.shouldPrompt(hasPrompted: true))
    }

    @Test("The anonymous default is not prefilled")
    func anonymousIsBlank() {
        let draft = CommunityNameDraft(storedName: Authorship.anonymous.displayName)
        #expect(draft.text.isEmpty)
        #expect(!draft.canSave)
    }

    @Test("A real profile name is prefilled and trimmed on save")
    func realNamePrefilled() {
        var draft = CommunityNameDraft(storedName: "  Nick  ")
        #expect(draft.text == "Nick")
        #expect(draft.canSave)
        draft.text = "   "
        #expect(!draft.canSave)
        draft.text = String(repeating: "a", count: 60)
        #expect(draft.trimmed.count == CommunityNameDraft.maxLength)
    }

    @Test("Saving writes the profile name and the publisher name")
    func savingWritesBothNames() {
        let environment = PreviewEnvironment()
        let draft = CommunityNameDraft(storedName: "Nick M")
        environment.portfolio.setAuthorName(draft.trimmed)
        environment.community.publisherName = environment.portfolio.authorName

        #expect(environment.portfolio.authorName == "Nick M")
        #expect(environment.community.publisherName == "Nick M")
        #expect(environment.defaults.string(forKey: AppStorageKeys.userName) == "Nick M")
    }
}

// MARK: - Ownership

@Suite("Community ownership")
struct CommunityOwnershipTests {
    @Test("isMine matches the signed-in record id")
    func isMineGating() async {
        let environment = PreviewEnvironment()
        await environment.community.refreshIdentity()

        #expect(environment.community.isMine(CommunityColor.sample))
        #expect(!environment.community.isMine(CommunityColor.sample2))
        #expect(environment.community.isMine(CommunityPalette.sample))
    }

    @Test("Nothing is mine when signed out")
    func nothingMineSignedOut() async {
        let environment = PreviewEnvironment()
        environment.communityService.userID = nil
        await environment.community.refreshIdentity()

        #expect(!environment.community.isMine(CommunityColor.sample))
        #expect(!environment.community.isMine(CommunityPalette.sample))
    }

    @Test("Unpublishing my color removes it from the feed")
    func unpublishRemoves() async {
        let environment = PreviewEnvironment()
        await environment.community.refreshIdentity()
        await environment.community.loadColors(refresh: true)

        await environment.community.unpublish(CommunityColor.sample)
        #expect(environment.community.colors.map(\.id) == [CommunityColor.sample2.id])
    }

    @Test("Saving a community color requires Onyx")
    func saveRequiresOnyx() async {
        let locked = PreviewEnvironment(hasOnyx: false)
        #expect(locked.community.save(CommunityColor.sample2, into: locked.portfolio, router: locked.router) == false)

        let unlocked = PreviewEnvironment(hasOnyx: true)
        let before = unlocked.portfolio.colors.count
        #expect(unlocked.community.save(CommunityColor.sample2, into: unlocked.portfolio, router: unlocked.router))
        #expect(unlocked.portfolio.colors.count == before + 1)
    }
}

// MARK: - Presentation helpers

@Suite("Community presentation helpers")
struct CommunityPresentationTests {
    @Test("Device labels are short and fall back gracefully")
    func deviceLabels() {
        #expect(CommunityDeviceLabel.short("iPhone 17 Pro") == "iPhone")
        #expect(CommunityDeviceLabel.short("iPad Pro 13-inch") == "iPad")
        #expect(CommunityDeviceLabel.short("MacBook Pro") == "Mac")
        #expect(CommunityDeviceLabel.short("Apple Vision Pro") == "Vision Pro")
        #expect(CommunityDeviceLabel.short("Toaster") == "Toaster")
        #expect(CommunityDeviceLabel.short(nil) == "—")
        #expect(CommunityDeviceLabel.short("  ") == "—")
    }

    @Test("Regular widths get wider grid columns")
    func gridMetrics() {
        #expect(CommunityGridMetrics.columnMinimum(for: .colors, isRegularWidth: true) > CommunityGridMetrics.columnMinimum(for: .colors, isRegularWidth: false))
        #expect(CommunityGridMetrics.columnMinimum(for: .palettes, isRegularWidth: false) > CommunityGridMetrics.columnMinimum(for: .colors, isRegularWidth: false))
        #expect(CommunityGridMetrics.placeholderCount(for: .colors) > CommunityGridMetrics.placeholderCount(for: .palettes))
    }
}
