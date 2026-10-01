//
//  CommunityModels.swift
//  OpaliteCore
//
//  Value types for the public Community database. Core stays CloudKit-free: records are
//  identified by `CommunityRecordID` (the CKRecord.ID record name) and the CKRecord
//  mapping lives in OpaliteServices.
//

import Foundation

/// A CloudKit record identity without the CloudKit dependency.
nonisolated public struct CommunityRecordID: Hashable, Sendable, Codable {
    public let recordName: String
    public init(recordName: String) { self.recordName = recordName }
    public static let unknown = CommunityRecordID(recordName: "unknown")
}

// MARK: - Community Color

/// A published color.
nonisolated public struct CommunityColor: Identifiable, Hashable, Sendable {
    public let id: CommunityRecordID
    public let originalColorID: UUID
    public let name: String?
    public let notes: String?
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    public let hexString: String
    public let publisherName: String
    public let publisherUserRecordID: CommunityRecordID
    public let createdOnDeviceName: String?
    public let originalCreatedAt: Date
    public let publishedAt: Date
    public var reportCount: Int64
    public var isHidden: Bool

    public static let recordType = "PublishedColor"

    public init(
        id: CommunityRecordID,
        originalColorID: UUID,
        name: String?,
        notes: String?,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double,
        hexString: String? = nil,
        publisherName: String,
        publisherUserRecordID: CommunityRecordID,
        createdOnDeviceName: String? = nil,
        originalCreatedAt: Date,
        publishedAt: Date,
        reportCount: Int64 = 0,
        isHidden: Bool = false
    ) {
        self.id = id
        self.originalColorID = originalColorID
        self.name = name
        self.notes = notes
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.hexString = hexString ?? ColorMath.hexString(red: red, green: green, blue: blue)
        self.publisherName = publisherName
        self.publisherUserRecordID = publisherUserRecordID
        self.createdOnDeviceName = createdOnDeviceName
        self.originalCreatedAt = originalCreatedAt
        self.publishedAt = publishedAt
        self.reportCount = reportCount
        self.isHidden = isHidden
    }

    public var rgba: RGBA { RGBA(red: red, green: green, blue: blue, alpha: alpha) }
    public var displayName: String { name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? name! : hexString }
    public var relativeLuminance: Double { rgba.relativeLuminance }
    public var prefersDarkText: Bool { rgba.prefersDarkText }
    public var rgbString: String { rgba.rgbString }
    public var hslString: String { rgba.hslString }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: CommunityColor, rhs: CommunityColor) -> Bool { lhs.id == rhs.id }
}

// MARK: - Community Palette

/// A published palette; its colors load separately through junction records.
nonisolated public struct CommunityPalette: Identifiable, Hashable, Sendable {
    public let id: CommunityRecordID
    public let originalPaletteID: UUID
    public let name: String
    public let notes: String?
    public let tags: [String]
    public let colorCount: Int
    public let previewImageData: Data?
    public let publisherName: String
    public let publisherUserRecordID: CommunityRecordID
    public let createdOnDeviceName: String?
    public let originalCreatedAt: Date
    public let publishedAt: Date
    public var reportCount: Int64
    public var isHidden: Bool
    public var colors: [CommunityColor]

    public static let recordType = "PublishedPalette"
    public static let junctionRecordType = "PublishedPaletteColor"
    public static let reportRecordType = "CommunityReport"

    public init(
        id: CommunityRecordID,
        originalPaletteID: UUID,
        name: String,
        notes: String?,
        tags: [String],
        colorCount: Int,
        previewImageData: Data? = nil,
        publisherName: String,
        publisherUserRecordID: CommunityRecordID,
        createdOnDeviceName: String? = nil,
        originalCreatedAt: Date,
        publishedAt: Date,
        reportCount: Int64 = 0,
        isHidden: Bool = false,
        colors: [CommunityColor] = []
    ) {
        self.id = id
        self.originalPaletteID = originalPaletteID
        self.name = name
        self.notes = notes
        self.tags = tags
        self.colorCount = colorCount
        self.previewImageData = previewImageData
        self.publisherName = publisherName
        self.publisherUserRecordID = publisherUserRecordID
        self.createdOnDeviceName = createdOnDeviceName
        self.originalCreatedAt = originalCreatedAt
        self.publishedAt = publishedAt
        self.reportCount = reportCount
        self.isHidden = isHidden
        self.colors = colors
    }

    /// Whether the color list has loaded (palettes render placeholders until it has).
    public var hasLoadedColors: Bool { !colors.isEmpty || colorCount == 0 }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(colors.count)
    }
    public static func == (lhs: CommunityPalette, rhs: CommunityPalette) -> Bool {
        lhs.id == rhs.id && lhs.colors.count == rhs.colors.count
    }
}

// MARK: - Community Publisher

nonisolated public struct CommunityPublisher: Identifiable, Hashable, Sendable {
    public let id: CommunityRecordID
    public let displayName: String
    public var colorCount: Int
    public var paletteCount: Int

    public init(id: CommunityRecordID, displayName: String, colorCount: Int = 0, paletteCount: Int = 0) {
        self.id = id
        self.displayName = displayName
        self.colorCount = colorCount
        self.paletteCount = paletteCount
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: CommunityPublisher, rhs: CommunityPublisher) -> Bool { lhs.id == rhs.id }
}

// MARK: - Sorting, item types, reports

nonisolated public enum CommunitySortOption: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case alphabetical

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .newest: "clock"
        case .oldest: "clock.arrow.circlepath"
        case .alphabetical: "textformat.abc"
        }
    }

    /// The CloudKit field the server-side sort uses.
    public var sortField: String {
        switch self {
        case .newest, .oldest: "publishedAt"
        case .alphabetical: "name"
        }
    }

    public var ascending: Bool {
        switch self {
        case .newest: false
        case .oldest, .alphabetical: true
        }
    }

    /// Sorts colors locally the same way the server would.
    public func sort(_ colors: [CommunityColor]) -> [CommunityColor] {
        switch self {
        case .newest: colors.sorted { $0.publishedAt > $1.publishedAt }
        case .oldest: colors.sorted { $0.publishedAt < $1.publishedAt }
        case .alphabetical: colors.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    public func sort(_ palettes: [CommunityPalette]) -> [CommunityPalette] {
        switch self {
        case .newest: palettes.sorted { $0.publishedAt > $1.publishedAt }
        case .oldest: palettes.sorted { $0.publishedAt < $1.publishedAt }
        case .alphabetical: palettes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

nonisolated public enum CommunityItemType: String, Sendable {
    case color
    case palette
}

nonisolated public enum CommunitySegment: String, CaseIterable, Identifiable, Sendable {
    case colors
    case palettes

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .colors: "paintpalette"
        case .palettes: "swatchpalette"
        }
    }
}

/// Reasons for reporting content. Raw values are the server-side `reason` field.
nonisolated public enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case inappropriate = "Inappropriate Content"
    case copyright = "Copyright Violation"
    case spam = "Spam"
    case other = "Other"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .inappropriate: "exclamationmark.triangle"
        case .copyright: "doc.badge.ellipsis"
        case .spam: "envelope.badge"
        case .other: "questionmark.circle"
        }
    }
}

// MARK: - Samples

extension CommunityColor {
    public static let sample = CommunityColor(
        id: CommunityRecordID(recordName: "sample-color-1"),
        originalColorID: UUID(),
        name: "Ocean Blue",
        notes: "A beautiful blue inspired by the ocean",
        red: 0.2, green: 0.5, blue: 0.8, alpha: 1,
        publisherName: "Sample User",
        publisherUserRecordID: CommunityRecordID(recordName: "sample-user-1"),
        createdOnDeviceName: "iPhone 15 Pro",
        originalCreatedAt: Date().addingTimeInterval(-86_400 * 7),
        publishedAt: Date().addingTimeInterval(-86_400)
    )

    public static let sample2 = CommunityColor(
        id: CommunityRecordID(recordName: "sample-color-2"),
        originalColorID: UUID(),
        name: "Sunset Orange",
        notes: nil,
        red: 0.95, green: 0.45, blue: 0.20, alpha: 1,
        publisherName: "Design Pro",
        publisherUserRecordID: CommunityRecordID(recordName: "sample-user-2"),
        createdOnDeviceName: "iPad Pro",
        originalCreatedAt: Date().addingTimeInterval(-86_400 * 14),
        publishedAt: Date().addingTimeInterval(-86_400 * 2)
    )
}

extension CommunityPalette {
    public static let sample = CommunityPalette(
        id: CommunityRecordID(recordName: "sample-palette-1"),
        originalPaletteID: UUID(),
        name: "Sunset Vibes",
        notes: "Warm colors inspired by summer sunsets",
        tags: ["warm", "sunset", "summer"],
        colorCount: 2,
        publisherName: "Sample User",
        publisherUserRecordID: CommunityRecordID(recordName: "sample-user-1"),
        createdOnDeviceName: "iPhone 15 Pro",
        originalCreatedAt: Date().addingTimeInterval(-86_400 * 10),
        publishedAt: Date().addingTimeInterval(-86_400 * 3),
        colors: [.sample, .sample2]
    )
}

extension CommunityPublisher {
    public static let sample = CommunityPublisher(id: CommunityRecordID(recordName: "sample-user-1"), displayName: "Sample User", colorCount: 12, paletteCount: 3)
}
