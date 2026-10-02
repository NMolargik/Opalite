//
//  CommunityModel.swift
//  OpaliteFeatureShared
//
//  The environment-injected Community surface (successor to CommunityManager): paged
//  colors/palettes from the `CommunityService`, local search over the cached set,
//  publishing with a per-hour rate limit, reporting with auto-hide, and "save to
//  portfolio" through the portfolio model (Onyx-gated).
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import os

@MainActor
@Observable
public final class CommunityModel {
    @ObservationIgnored private let service: any CommunityService
    @ObservationIgnored private let entitlements: any EntitlementProviding
    @ObservationIgnored private let toastManager: ToastManager
    @ObservationIgnored private let isOnline: @MainActor () -> Bool
    @ObservationIgnored private var colorCursor: CommunityCursor?
    @ObservationIgnored private var paletteCursor: CommunityCursor?
    @ObservationIgnored private var allColors: [CommunityColor] = []
    @ObservationIgnored private var allPalettes: [CommunityPalette] = []
    @ObservationIgnored private var rateLimiter = PublishRateLimiter()

    public static let pageSize = 20

    public private(set) var colors: [CommunityColor] = []
    public private(set) var palettes: [CommunityPalette] = []
    public private(set) var isLoading = false
    public private(set) var hasMoreColors = true
    public private(set) var hasMorePalettes = true
    public private(set) var error: OpaliteError?
    public private(set) var currentUserRecordID: CommunityRecordID?
    public private(set) var isShowingSearchResults = false
    public var sortOption: CommunitySortOption = .newest
    /// The display name published with content (Settings › Profile).
    public var publisherName: String

    public init(
        service: any CommunityService,
        entitlements: any EntitlementProviding,
        toastManager: ToastManager,
        publisherName: String,
        isOnline: @escaping @MainActor () -> Bool = { true }
    ) {
        self.service = service
        self.entitlements = entitlements
        self.toastManager = toastManager
        self.publisherName = publisherName
        self.isOnline = isOnline
        Task { await refreshIdentity() }
    }

    public var isUserSignedIn: Bool { currentUserRecordID != nil }
    public var isConnected: Bool { isOnline() }
    public var canPublish: Bool { isUserSignedIn && isConnected && rateLimiter.canPublish() }

    public func refreshIdentity() async {
        currentUserRecordID = await service.currentUserRecordID()
    }

    public func isMine(_ color: CommunityColor) -> Bool { color.publisherUserRecordID == currentUserRecordID }
    public func isMine(_ palette: CommunityPalette) -> Bool { palette.publisherUserRecordID == currentUserRecordID }

    // MARK: - Fetching

    public func loadColors(refresh: Bool = false) async {
        if refresh {
            colorCursor = nil
            colors = []
            hasMoreColors = true
        }
        guard hasMoreColors, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await service.fetchColors(sortBy: sortOption, cursor: colorCursor, limit: Self.pageSize)
            colors = (colors + page.items).uniqued(by: \.id)
            colorCursor = page.nextCursor
            hasMoreColors = page.nextCursor != nil
            if !isShowingSearchResults { allColors = colors }
            error = nil
        } catch {
            self.error = error
            Log.community.error("Color fetch failed: \(error.localizedDescription)")
        }
    }

    public func loadPalettes(refresh: Bool = false) async {
        if refresh {
            paletteCursor = nil
            palettes = []
            hasMorePalettes = true
        }
        guard hasMorePalettes, !isLoading else { return }
        isLoading = true
        do {
            let page = try await service.fetchPalettes(sortBy: sortOption, cursor: paletteCursor, limit: Self.pageSize)
            let fresh = page.items.filter { item in !palettes.contains { $0.id == item.id } }
            palettes.append(contentsOf: fresh)
            paletteCursor = page.nextCursor
            hasMorePalettes = page.nextCursor != nil
            isLoading = false
            error = nil
            await loadColors(for: fresh)
            if !isShowingSearchResults { allPalettes = palettes }
        } catch {
            isLoading = false
            self.error = error
            Log.community.error("Palette fetch failed: \(error.localizedDescription)")
        }
    }

    /// Loads each palette's colors, updating the list as each arrives. The service is
    /// main-actor bound, so palettes load sequentially but the UI stays responsive.
    private func loadColors(for toLoad: [CommunityPalette]) async {
        for palette in toLoad where palette.colorCount > 0 {
            let loaded = (try? await service.fetchPaletteColors(paletteID: palette.id)) ?? []
            if let index = palettes.firstIndex(where: { $0.id == palette.id }) {
                palettes[index].colors = loaded
            }
        }
    }

    public func paletteColors(_ palette: CommunityPalette) async -> [CommunityColor] {
        if palette.hasLoadedColors { return palette.colors }
        return (try? await service.fetchPaletteColors(paletteID: palette.id)) ?? []
    }

    public func refreshAll() async {
        await loadColors(refresh: true)
        await loadPalettes(refresh: true)
    }

    public func resort(_ option: CommunitySortOption) {
        sortOption = option
        colors = option.sort(colors)
        palettes = option.sort(palettes)
    }

    // MARK: - Search (local)

    public func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if isShowingSearchResults {
                colors = sortOption.sort(allColors)
                palettes = sortOption.sort(allPalettes)
                isShowingSearchResults = false
                hasMoreColors = colorCursor != nil
                hasMorePalettes = paletteCursor != nil
            }
            return
        }
        if allColors.isEmpty { await loadColors(refresh: true) }
        if allPalettes.isEmpty { await loadPalettes(refresh: true) }
        let lower = trimmed.lowercased()
        colors = sortOption.sort(allColors.filter { color in
            (color.name?.lowercased().contains(lower) ?? false)
                || color.hexString.lowercased().contains(lower)
                || ColorClassifier.matches(color.rgba, query: lower)
        })
        palettes = sortOption.sort(allPalettes.filter { palette in
            palette.name.lowercased().contains(lower) || palette.tags.contains { $0.lowercased().contains(lower) }
        })
        isShowingSearchResults = true
        hasMoreColors = false
        hasMorePalettes = false
    }

    // MARK: - Publishing

    /// Publishes a color; false on failure (toasted).
    @discardableResult
    public func publish(_ color: OpaliteColor) async -> Bool {
        guard await preflightPublish() else { return false }
        do {
            let publication = ColorPublication(originalColorID: color.id, name: color.name, notes: color.notes, rgba: color.rgba, createdOnDeviceName: color.createdOnDeviceName, originalCreatedAt: color.createdAt)
            let published = try await service.publish(publication, publisherName: publisherName)
            rateLimiter.record()
            colors.insert(published, at: 0)
            allColors.insert(published, at: 0)
            toastManager.showSuccess(String(localized: "Published to the Community"), systemImage: "person.2.fill")
            return true
        } catch {
            toastManager.show(error: error)
            return false
        }
    }

    @discardableResult
    public func publish(_ palette: OpalitePalette, previewImagePNG: Data?) async -> Bool {
        guard await preflightPublish() else { return false }
        do {
            let colors = palette.sortedColors.map { ColorPublication(originalColorID: $0.id, name: $0.name, notes: $0.notes, rgba: $0.rgba, createdOnDeviceName: $0.createdOnDeviceName, originalCreatedAt: $0.createdAt) }
            let publication = PalettePublication(originalPaletteID: palette.id, name: palette.name, notes: palette.notes, tags: palette.tags, originalCreatedAt: palette.createdAt, colors: colors, previewImagePNG: previewImagePNG)
            let published = try await service.publish(publication, publisherName: publisherName)
            rateLimiter.record()
            palettes.insert(published, at: 0)
            allPalettes.insert(published, at: 0)
            toastManager.showSuccess(String(localized: "Published to the Community"), systemImage: "person.2.fill")
            return true
        } catch {
            toastManager.show(error: error)
            return false
        }
    }

    private func preflightPublish() async -> Bool {
        guard isConnected else { toastManager.show(error: OpaliteError.communityOffline); return false }
        if currentUserRecordID == nil { await refreshIdentity() }
        guard isUserSignedIn else { toastManager.show(error: OpaliteError.communityNotSignedIn); return false }
        guard rateLimiter.canPublish() else { toastManager.show(error: OpaliteError.communityRateLimited); return false }
        return true
    }

    public func unpublish(_ color: CommunityColor) async {
        do {
            try await service.unpublishColor(id: color.id)
            colors.removeAll { $0.id == color.id }
            allColors.removeAll { $0.id == color.id }
            toastManager.showSuccess(String(localized: "Removed from the Community"))
        } catch {
            toastManager.show(error: error)
        }
    }

    public func unpublish(_ palette: CommunityPalette) async {
        do {
            try await service.unpublishPalette(id: palette.id)
            palettes.removeAll { $0.id == palette.id }
            allPalettes.removeAll { $0.id == palette.id }
            toastManager.showSuccess(String(localized: "Removed from the Community"))
        } catch {
            toastManager.show(error: error)
        }
    }

    // MARK: - Reporting

    @discardableResult
    public func report(id: CommunityRecordID, type: CommunityItemType, reason: ReportReason, details: String?) async -> Bool {
        if currentUserRecordID == nil { await refreshIdentity() }
        guard isUserSignedIn else { toastManager.show(error: OpaliteError.communityNotSignedIn); return false }
        do {
            let count = try await service.report(id: id, type: type, reason: reason, details: details)
            if CommunityModeration.isHidden(afterReports: count) {
                colors.removeAll { $0.id == id }
                palettes.removeAll { $0.id == id }
                allColors.removeAll { $0.id == id }
                allPalettes.removeAll { $0.id == id }
            } else if type == .color, let index = colors.firstIndex(where: { $0.id == id }) {
                colors[index].reportCount = count
            } else if let index = palettes.firstIndex(where: { $0.id == id }) {
                palettes[index].reportCount = count
            }
            toastManager.showSuccess(String(localized: "Thanks for the report"), systemImage: "flag.fill")
            return true
        } catch {
            toastManager.show(error: error)
            return false
        }
    }

    // MARK: - Save to portfolio (Onyx)

    /// Saves a Community color into the portfolio under its original id, so a second save
    /// is recognized as a duplicate. Requires Onyx.
    @discardableResult
    public func save(_ community: CommunityColor, into portfolio: PortfolioModel, router: AppRouter) -> Bool {
        guard entitlements.hasOnyx else {
            toastManager.show(error: OpaliteError.communityRequiresOnyx, actionTitle: String(localized: "Get Onyx")) {
                router.requestPaywall(context: String(localized: "Saving from the Community requires Onyx"))
            }
            return false
        }
        guard !portfolio.colors.contains(where: { $0.id == community.originalColorID }) else {
            toastManager.show(error: OpaliteError.communityColorAlreadyExists)
            return false
        }
        let color = OpaliteColor(id: community.originalColorID, name: community.name, notes: community.notes, createdByDisplayName: community.publisherName, red: community.red, green: community.green, blue: community.blue, alpha: community.alpha)
        guard portfolio.insert(color) != nil else { return false }
        toastManager.showSuccess(String(localized: "Saved to your Portfolio"))
        return true
    }

    @discardableResult
    public func save(_ community: CommunityPalette, into portfolio: PortfolioModel, router: AppRouter) async -> Bool {
        guard entitlements.hasOnyx else {
            toastManager.show(error: OpaliteError.communityRequiresOnyx, actionTitle: String(localized: "Get Onyx")) {
                router.requestPaywall(context: String(localized: "Saving from the Community requires Onyx"))
            }
            return false
        }
        guard !portfolio.palettes.contains(where: { $0.id == community.originalPaletteID }) else {
            toastManager.show(error: OpaliteError.communityPaletteAlreadyExists)
            return false
        }
        let colors = await paletteColors(community).map { c in
            OpaliteColor(name: c.name, notes: c.notes, createdByDisplayName: c.publisherName, red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
        }
        let palette = OpalitePalette(id: community.originalPaletteID, name: community.name, createdByDisplayName: community.publisherName, notes: community.notes, tags: community.tags, colors: colors)
        guard portfolio.insert(palette) != nil else { return false }
        toastManager.showSuccess(String(localized: "Saved to your Portfolio"))
        return true
    }

    // MARK: - Publisher profile

    public func publisherContent(_ id: CommunityRecordID) async -> (colors: [CommunityColor], palettes: [CommunityPalette])? {
        do {
            return try await service.fetchPublisherContent(userRecordID: id)
        } catch {
            toastManager.show(error: error)
            return nil
        }
    }

    // MARK: - Moderation

    public func reportedContent() async -> (colors: [CommunityColor], palettes: [CommunityPalette]) {
        let colors = (try? await service.fetchReportedColors()) ?? []
        let palettes = (try? await service.fetchReportedPalettes()) ?? []
        return (colors, palettes)
    }

    public func clearReports(id: CommunityRecordID) async -> Bool {
        do {
            try await service.clearReports(id: id)
            return true
        } catch {
            toastManager.show(error: error)
            return false
        }
    }

    public func removeEntity(id: CommunityRecordID, type: CommunityItemType) async -> Bool {
        do {
            try await service.clearReports(id: id)
            switch type {
            case .color: try await service.unpublishColor(id: id)
            case .palette: try await service.unpublishPalette(id: id)
            }
            colors.removeAll { $0.id == id }
            palettes.removeAll { $0.id == id }
            return true
        } catch {
            toastManager.show(error: error)
            return false
        }
    }
}
