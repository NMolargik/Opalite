//
//  CommunityFeedModel.swift
//  OpaliteFeatureCommunity
//
//  The Community tab's view state (segment, search, sheets) and the loading choreography
//  over `CommunityModel`: first-page loads per segment, pull-to-refresh, infinite scroll,
//  debounced local search, and sort changes. Host-testable with `PreviewEnvironment`.
//

import Foundation
import Observation
import OpaliteCore
import OpaliteFeatureShared

@MainActor
@Observable
public final class CommunityFeedModel {
    /// Something the user asked to report from a card's context menu.
    public struct ReportTarget: Identifiable, Equatable, Sendable {
        public let id: CommunityRecordID
        public let type: CommunityItemType
        public init(id: CommunityRecordID, type: CommunityItemType) {
            self.id = id
            self.type = type
        }
    }

    public var segment: CommunitySegment = .colors
    public var searchText = ""
    public var isShowingInfo = false
    public var isShowingNamePrompt = false
    public var reportTarget: ReportTarget?

    /// How long typing pauses before the search runs.
    public static let searchDebounce: Duration = .milliseconds(250)

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    public init() {}

    // MARK: - Status

    public var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// The feed status for the current segment.
    public func status(in community: CommunityModel) -> CommunityFeedStatus {
        CommunityFeedStatus.resolve(
            isConnected: community.isConnected,
            isSignedIn: community.isUserSignedIn,
            isLoading: community.isLoading,
            itemCount: itemCount(in: community),
            hasError: community.error != nil,
            isSearching: isSearching || community.isShowingSearchResults
        )
    }

    public func itemCount(in community: CommunityModel) -> Int {
        switch segment {
        case .colors: community.colors.count
        case .palettes: community.palettes.count
        }
    }

    public func hasMore(in community: CommunityModel) -> Bool {
        guard !community.isShowingSearchResults else { return false }
        return switch segment {
        case .colors: community.hasMoreColors
        case .palettes: community.hasMorePalettes
        }
    }

    // MARK: - Loading

    /// Loads the current segment's first page when nothing is cached. Waits out an
    /// in-flight load for the other segment so the request isn't dropped.
    public func ensureLoaded(in community: CommunityModel) async {
        guard community.isConnected else { return }
        if community.currentUserRecordID == nil { await community.refreshIdentity() }
        var waited = 0
        while community.isLoading, waited < 40, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
            waited += 1
        }
        guard !Task.isCancelled, itemCount(in: community) == 0, !community.isShowingSearchResults else { return }
        await load(refresh: true, in: community)
    }

    /// Pull-to-refresh and the retry buttons: refetch the current segment from the top.
    public func refresh(in community: CommunityModel) async {
        if community.currentUserRecordID == nil { await community.refreshIdentity() }
        searchTask?.cancel()
        if isSearching {
            await community.search(searchText)
        } else {
            await load(refresh: true, in: community)
        }
    }

    /// Infinite scroll: fetch the next page of the current segment.
    public func loadMore(in community: CommunityModel) async {
        guard hasMore(in: community), !community.isLoading else { return }
        await load(refresh: false, in: community)
    }

    private func load(refresh: Bool, in community: CommunityModel) async {
        switch segment {
        case .colors: await community.loadColors(refresh: refresh)
        case .palettes: await community.loadPalettes(refresh: refresh)
        }
    }

    // MARK: - Search & sort

    /// Debounces typing, then filters the cached set (clearing restores it).
    public func searchTextChanged(in community: CommunityModel) {
        searchTask?.cancel()
        let query = searchText
        searchTask = Task { [weak self] in
            if !query.isEmpty {
                try? await Task.sleep(for: Self.searchDebounce)
            }
            guard !Task.isCancelled, let self else { return }
            await self.runSearch(query, in: community)
        }
    }

    /// Runs the search immediately (return key).
    public func submitSearch(in community: CommunityModel) async {
        searchTask?.cancel()
        await runSearch(searchText, in: community)
    }

    private func runSearch(_ query: String, in community: CommunityModel) async {
        await community.search(query)
    }

    public func sort(by option: CommunitySortOption, in community: CommunityModel) {
        guard option != community.sortOption else { return }
        community.resort(option)
    }
}
