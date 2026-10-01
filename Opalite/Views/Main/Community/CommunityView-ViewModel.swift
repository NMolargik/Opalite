//
//  CommunityView-ViewModel.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CloudKit

extension CommunityView {
    @Observable
    final class ViewModel {
        // MARK: - Navigation
        var navigationPath = NavigationPath()

        // MARK: - UI State
        var selectedSegment: CommunitySegment = .colors
        var sortOption: CommunitySortOption = .newest
        var searchText: String = ""

        // MARK: - Caching
        /// Tracks when colors were last fetched for cache invalidation
        var colorsLastFetchedAt: Date?
        /// Tracks when palettes were last fetched for cache invalidation
        var palettesLastFetchedAt: Date?
        /// Cache duration before considering data stale (5 minutes)
        private let cacheValidityDuration: TimeInterval = 5 * 60

        // MARK: - Sheets
        var isShowingPaywall: Bool = false
        var paywallContext: String = ""
        var isShowingReportSheet: Bool = false
        var itemToReport: (CKRecord.ID, CommunityItemType)?
        var isShowingCommunityInfo: Bool = false

        // MARK: - Info Sheets
        var colorToShowInfo: CommunityColor?
        var paletteToShowInfo: CommunityPalette?

        var isShowingColorInfo: Bool {
            get { colorToShowInfo != nil }
            set { if !newValue { colorToShowInfo = nil } }
        }

        var isShowingPaletteInfo: Bool {
            get { paletteToShowInfo != nil }
            set { if !newValue { paletteToShowInfo = nil } }
        }

        // MARK: - Cache Methods

        /// Returns true if colors data is stale and should be refreshed
        func isColorsCacheStale() -> Bool {
            guard let lastFetched = colorsLastFetchedAt else { return true }
            return Date().timeIntervalSince(lastFetched) > cacheValidityDuration
        }

        /// Returns true if palettes data is stale and should be refreshed
        func isPalettesCacheStale() -> Bool {
            guard let lastFetched = palettesLastFetchedAt else { return true }
            return Date().timeIntervalSince(lastFetched) > cacheValidityDuration
        }

        /// Marks colors as freshly fetched
        func markColorsFetched() {
            colorsLastFetchedAt = Date()
        }

        /// Marks palettes as freshly fetched
        func markPalettesFetched() {
            palettesLastFetchedAt = Date()
        }

        /// Invalidates all caches (used for forced refresh)
        func invalidateAllCaches() {
            colorsLastFetchedAt = nil
            palettesLastFetchedAt = nil
        }
    }
}
