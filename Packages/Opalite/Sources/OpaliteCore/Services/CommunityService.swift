//
//  CommunityService.swift
//  OpaliteCore
//
//  The public-database boundary (CloudKit impl in OpaliteServices; an in-memory fake in
//  tests and previews). Pages are cursor-based and opaque to callers.
//

import Foundation

/// An opaque pagination token.
nonisolated public struct CommunityCursor: Sendable, Equatable {
    public let token: String
    public init(token: String) { self.token = token }
}

nonisolated public struct CommunityPage<Item: Sendable>: Sendable {
    public let items: [Item]
    public let nextCursor: CommunityCursor?

    public init(items: [Item], nextCursor: CommunityCursor?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// What the publisher sends when publishing a color.
nonisolated public struct ColorPublication: Sendable, Equatable {
    public let originalColorID: UUID
    public let name: String?
    public let notes: String?
    public let rgba: RGBA
    public let createdOnDeviceName: String?
    public let originalCreatedAt: Date

    public init(originalColorID: UUID, name: String?, notes: String?, rgba: RGBA, createdOnDeviceName: String?, originalCreatedAt: Date) {
        self.originalColorID = originalColorID
        self.name = name
        self.notes = notes
        self.rgba = rgba
        self.createdOnDeviceName = createdOnDeviceName
        self.originalCreatedAt = originalCreatedAt
    }
}

nonisolated public struct PalettePublication: Sendable, Equatable {
    public let originalPaletteID: UUID
    public let name: String
    public let notes: String?
    public let tags: [String]
    public let originalCreatedAt: Date
    public let colors: [ColorPublication]
    public let previewImagePNG: Data?

    public init(originalPaletteID: UUID, name: String, notes: String?, tags: [String], originalCreatedAt: Date, colors: [ColorPublication], previewImagePNG: Data?) {
        self.originalPaletteID = originalPaletteID
        self.name = name
        self.notes = notes
        self.tags = tags
        self.originalCreatedAt = originalCreatedAt
        self.colors = colors
        self.previewImagePNG = previewImagePNG
    }
}

@MainActor
public protocol CommunityService: AnyObject {
    /// The signed-in user's record id, or nil when there is no iCloud account.
    func currentUserRecordID() async -> CommunityRecordID?

    func fetchColors(sortBy: CommunitySortOption, cursor: CommunityCursor?, limit: Int) async throws(OpaliteError) -> CommunityPage<CommunityColor>
    func fetchPalettes(sortBy: CommunitySortOption, cursor: CommunityCursor?, limit: Int) async throws(OpaliteError) -> CommunityPage<CommunityPalette>
    /// A palette's colors in sort order (via junction records).
    func fetchPaletteColors(paletteID: CommunityRecordID) async throws(OpaliteError) -> [CommunityColor]
    func fetchPublisherContent(userRecordID: CommunityRecordID) async throws(OpaliteError) -> (colors: [CommunityColor], palettes: [CommunityPalette])

    func publish(_ color: ColorPublication, publisherName: String) async throws(OpaliteError) -> CommunityColor
    func publish(_ palette: PalettePublication, publisherName: String) async throws(OpaliteError) -> CommunityPalette
    func unpublishColor(id: CommunityRecordID) async throws(OpaliteError)
    func unpublishPalette(id: CommunityRecordID) async throws(OpaliteError)

    func report(id: CommunityRecordID, type: CommunityItemType, reason: ReportReason, details: String?) async throws(OpaliteError) -> Int64

    // Moderation (Settings › Debug)
    func fetchReportedColors() async throws(OpaliteError) -> [CommunityColor]
    func fetchReportedPalettes() async throws(OpaliteError) -> [CommunityPalette]
    func clearReports(id: CommunityRecordID) async throws(OpaliteError)
}

/// Publishing is capped per hour per device; pure so the policy is tested.
nonisolated public struct PublishRateLimiter: Sendable, Equatable {
    public static let maxPublishesPerHour = 10
    public private(set) var recentPublishes: [Date]

    public init(recentPublishes: [Date] = []) { self.recentPublishes = recentPublishes }

    public func canPublish(now: Date = Date()) -> Bool {
        pruned(now: now).recentPublishes.count < Self.maxPublishesPerHour
    }

    public mutating func record(now: Date = Date()) {
        self = pruned(now: now)
        recentPublishes.append(now)
    }

    private func pruned(now: Date) -> PublishRateLimiter {
        let oneHourAgo = now.addingTimeInterval(-3600)
        return PublishRateLimiter(recentPublishes: recentPublishes.filter { $0 >= oneHourAgo })
    }
}

/// Reports needed before an item is auto-hidden.
nonisolated public enum CommunityModeration {
    public static let autoHideThreshold: Int64 = 5
    public static func isHidden(afterReports count: Int64) -> Bool { count >= autoHideThreshold }
}
