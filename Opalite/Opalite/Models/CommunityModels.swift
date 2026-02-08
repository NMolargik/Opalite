//
//  CommunityModels.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CloudKit

// MARK: - Community Color

/// A published color from the Community public database
struct CommunityColor: Identifiable, Hashable, Sendable {
    let id: CKRecord.ID
    let originalColorID: UUID
    let name: String?
    let notes: String?
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let hexString: String
    let publisherName: String
    let publisherUserRecordID: CKRecord.ID
    let createdOnDeviceName: String?
    let originalCreatedAt: Date
    let publishedAt: Date
    var reportCount: Int64
    var isHidden: Bool

    /// SwiftUI Color for rendering
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    /// WCAG relative luminance (0 = dark, 1 = light)
    var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            return c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        let rLin = channel(red)
        let gLin = channel(green)
        let bLin = channel(blue)
        return 0.2126 * rLin + 0.7152 * gLin + 0.0722 * bLin
    }

    /// Returns black or white depending on which has better contrast
    func idealTextColor() -> Color {
        relativeLuminance > 0.179 ? .black : .white
    }

    /// RGB string representation (e.g., "rgb(255, 128, 0)")
    var rgbString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return "rgb(\(r), \(g), \(b))"
    }

    /// HSL string representation (e.g., "hsl(30, 100%, 50%)")
    var hslString: String {
        let (h, s, l) = hslComponents
        return "hsl(\(Int(round(h))), \(Int(round(s * 100)))%, \(Int(round(l * 100)))%)"
    }

    // MARK: - CloudKit Mapping

    static let recordType = "PublishedColor"

    init(record: CKRecord) throws {
        guard record.recordType == Self.recordType else {
            throw OpaliteError.communityFetchFailed(reason: "Invalid record type")
        }

        self.id = record.recordID
        self.originalColorID = UUID(uuidString: record["originalColorID"] as? String ?? "") ?? UUID()
        self.name = record["name"] as? String
        self.notes = record["notes"] as? String
        self.red = record["red"] as? Double ?? 0
        self.green = record["green"] as? Double ?? 0
        self.blue = record["blue"] as? Double ?? 0
        self.alpha = record["alpha"] as? Double ?? 1
        self.hexString = record["hexString"] as? String ?? "#000000"
        self.publisherName = record["publisherName"] as? String ?? "Unknown"
        self.publisherUserRecordID = (record["publisherUserRecordID"] as? CKRecord.Reference)?.recordID ?? CKRecord.ID(recordName: "unknown")
        self.createdOnDeviceName = record["createdOnDeviceName"] as? String
        self.originalCreatedAt = record["originalCreatedAt"] as? Date ?? record.creationDate ?? Date()
        self.publishedAt = record["publishedAt"] as? Date ?? record.creationDate ?? Date()
        self.reportCount = record["reportCount"] as? Int64 ?? 0
        self.isHidden = (record["isHidden"] as? Int64 ?? 0) != 0
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommunityColor, rhs: CommunityColor) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Community Palette

/// A published palette from the Community public database
struct CommunityPalette: Identifiable, Hashable, Sendable {
    let id: CKRecord.ID
    let originalPaletteID: UUID
    let name: String
    let notes: String?
    let tags: [String]
    let colorCount: Int
    let previewImageData: Data?
    let publisherName: String
    let publisherUserRecordID: CKRecord.ID
    let createdOnDeviceName: String?
    let originalCreatedAt: Date
    let publishedAt: Date
    var reportCount: Int64
    var isHidden: Bool

    /// Associated colors (loaded separately via PublishedPaletteColor records)
    var colors: [CommunityColor] = []

    // MARK: - CloudKit Mapping

    static let recordType = "PublishedPalette"

    init(record: CKRecord) throws {
        guard record.recordType == Self.recordType else {
            throw OpaliteError.communityFetchFailed(reason: "Invalid record type")
        }

        self.id = record.recordID
        self.originalPaletteID = UUID(uuidString: record["originalPaletteID"] as? String ?? "") ?? UUID()
        self.name = record["name"] as? String ?? "Untitled"
        self.notes = record["notes"] as? String
        self.tags = record["tags"] as? [String] ?? []
        self.colorCount = Int(record["colorCount"] as? Int64 ?? 0)
        self.publisherName = record["publisherName"] as? String ?? "Unknown"
        self.publisherUserRecordID = (record["publisherUserRecordID"] as? CKRecord.Reference)?.recordID ?? CKRecord.ID(recordName: "unknown")
        self.createdOnDeviceName = record["createdOnDeviceName"] as? String
        self.originalCreatedAt = record["originalCreatedAt"] as? Date ?? record.creationDate ?? Date()
        self.publishedAt = record["publishedAt"] as? Date ?? record.creationDate ?? Date()
        self.reportCount = record["reportCount"] as? Int64 ?? 0
        self.isHidden = (record["isHidden"] as? Int64 ?? 0) != 0

        // Load preview image from CKAsset
        if let asset = record["previewImageData"] as? CKAsset,
           let fileURL = asset.fileURL {
            self.previewImageData = try? Data(contentsOf: fileURL)
        } else {
            self.previewImageData = nil
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(colors.count)
    }

    static func == (lhs: CommunityPalette, rhs: CommunityPalette) -> Bool {
        lhs.id == rhs.id && lhs.colors.count == rhs.colors.count
    }
}

// MARK: - Community Publisher

/// A publisher profile derived from CloudKit user records
struct CommunityPublisher: Identifiable, Hashable, Sendable {
    let id: CKRecord.ID
    let displayName: String

    /// Number of published colors by this user
    var colorCount: Int = 0

    /// Number of published palettes by this user
    var paletteCount: Int = 0

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CommunityPublisher, rhs: CommunityPublisher) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sort Options

/// Sort options for Community content
enum CommunitySortOption: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case alphabetical = "A-Z"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .newest: return "clock"
        case .oldest: return "clock.arrow.circlepath"
        case .alphabetical: return "textformat.abc"
        }
    }

    var sortDescriptorKey: String {
        switch self {
        case .newest, .oldest: return "publishedAt"
        case .alphabetical: return "name"
        }
    }

    var ascending: Bool {
        switch self {
        case .newest: return false
        case .oldest, .alphabetical: return true
        }
    }
}

// MARK: - Item Type

/// Type of Community item for generic operations
enum CommunityItemType: String, Sendable {
    case color
    case palette
}

// MARK: - Report Reason

/// Reasons for reporting content
enum ReportReason: String, CaseIterable, Identifiable {
    case inappropriate = "Inappropriate Content"
    case copyright = "Copyright Violation"
    case spam = "Spam"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .inappropriate: return "exclamationmark.triangle"
        case .copyright: return "doc.badge.ellipsis"
        case .spam: return "envelope.badge"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Sample Data for Previews

extension CommunityColor {
    static let sample = CommunityColor(
        id: CKRecord.ID(recordName: "sample-color-1"),
        originalColorID: UUID(),
        name: "Ocean Blue",
        notes: "A beautiful blue inspired by the ocean",
        red: 0.2,
        green: 0.5,
        blue: 0.8,
        alpha: 1.0,
        hexString: "#3380CC",
        publisherName: "Sample User",
        publisherUserRecordID: CKRecord.ID(recordName: "sample-user-1"),
        createdOnDeviceName: "iPhone 15 Pro",
        originalCreatedAt: Date().addingTimeInterval(-86400 * 7),
        publishedAt: Date().addingTimeInterval(-86400),
        reportCount: 0,
        isHidden: false
    )

    static let sample2 = CommunityColor(
        id: CKRecord.ID(recordName: "sample-color-2"),
        originalColorID: UUID(),
        name: "Sunset Orange",
        notes: nil,
        red: 0.95,
        green: 0.45,
        blue: 0.20,
        alpha: 1.0,
        hexString: "#F2732F",
        publisherName: "Design Pro",
        publisherUserRecordID: CKRecord.ID(recordName: "sample-user-2"),
        createdOnDeviceName: "iPad Pro",
        originalCreatedAt: Date().addingTimeInterval(-86400 * 14),
        publishedAt: Date().addingTimeInterval(-86400 * 2),
        reportCount: 0,
        isHidden: false
    )

    private init(
        id: CKRecord.ID,
        originalColorID: UUID,
        name: String?,
        notes: String?,
        red: Double,
        green: Double,
        blue: Double,
        alpha: Double,
        hexString: String,
        publisherName: String,
        publisherUserRecordID: CKRecord.ID,
        createdOnDeviceName: String?,
        originalCreatedAt: Date,
        publishedAt: Date,
        reportCount: Int64,
        isHidden: Bool
    ) {
        self.id = id
        self.originalColorID = originalColorID
        self.name = name
        self.notes = notes
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.hexString = hexString
        self.publisherName = publisherName
        self.publisherUserRecordID = publisherUserRecordID
        self.createdOnDeviceName = createdOnDeviceName
        self.originalCreatedAt = originalCreatedAt
        self.publishedAt = publishedAt
        self.reportCount = reportCount
        self.isHidden = isHidden
    }
}

extension CommunityPalette {
    static let sample = CommunityPalette(
        id: CKRecord.ID(recordName: "sample-palette-1"),
        originalPaletteID: UUID(),
        name: "Sunset Vibes",
        notes: "Warm colors inspired by summer sunsets",
        tags: ["warm", "sunset", "summer"],
        colorCount: 5,
        previewImageData: nil,
        publisherName: "Sample User",
        publisherUserRecordID: CKRecord.ID(recordName: "sample-user-1"),
        createdOnDeviceName: "iPhone 15 Pro",
        originalCreatedAt: Date().addingTimeInterval(-86400 * 10),
        publishedAt: Date().addingTimeInterval(-86400 * 3),
        reportCount: 0,
        isHidden: false,
        colors: [CommunityColor.sample, CommunityColor.sample2]
    )

    private init(
        id: CKRecord.ID,
        originalPaletteID: UUID,
        name: String,
        notes: String?,
        tags: [String],
        colorCount: Int,
        previewImageData: Data?,
        publisherName: String,
        publisherUserRecordID: CKRecord.ID,
        createdOnDeviceName: String?,
        originalCreatedAt: Date,
        publishedAt: Date,
        reportCount: Int64,
        isHidden: Bool,
        colors: [CommunityColor]
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
}

extension CommunityPublisher {
    static let sample = CommunityPublisher(
        id: CKRecord.ID(recordName: "sample-user-1"),
        displayName: "Sample User",
        colorCount: 12,
        paletteCount: 3
    )
}

// MARK: - Color Classification

extension CommunityColor {
    /// HSL components (hue: 0-360, saturation: 0-1, lightness: 0-1)
    var hslComponents: (hue: Double, saturation: Double, lightness: Double) {
        let maxVal = max(red, green, blue)
        let minVal = min(red, green, blue)
        let delta = maxVal - minVal

        // Lightness
        let l = (maxVal + minVal) / 2

        // Saturation
        let s: Double
        if delta == 0 {
            s = 0
        } else {
            s = delta / (1 - abs(2 * l - 1))
        }

        // Hue
        var h: Double = 0
        if delta != 0 {
            switch maxVal {
            case red:
                h = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
            case green:
                h = 60 * (((blue - red) / delta) + 2)
            case blue:
                h = 60 * (((red - green) / delta) + 4)
            default:
                break
            }
        }
        if h < 0 { h += 360 }

        return (h, s, l)
    }

    /// Primary color family (red, orange, yellow, green, cyan, blue, purple, pink, gray, black, white, brown)
    var colorFamily: String {
        let (hue, saturation, lightness) = hslComponents
        let satPercent = saturation * 100
        let lightPercent = lightness * 100

        // Very dark colors are black (regardless of saturation)
        if lightPercent < 12 {
            return "black"
        }

        // Very light colors are white (unless highly saturated)
        // High lightness + low-to-moderate saturation = white
        if lightPercent > 92 && satPercent < 50 {
            return "white"
        }
        if lightPercent > 85 && satPercent < 25 {
            return "white"
        }

        // Low saturation colors are gray (achromatic)
        if satPercent < 15 {
            if lightPercent < 20 { return "black" }
            if lightPercent > 80 { return "white" }
            return "gray"
        }

        // Near-black dark colors with some saturation
        if lightPercent < 20 && satPercent < 40 {
            return "black"
        }

        // Brown detection (desaturated orange/red with low-medium lightness)
        if (hue < 45 || hue >= 345) && satPercent >= 20 && satPercent <= 65 && lightPercent >= 15 && lightPercent <= 50 {
            return "brown"
        }

        // Chromatic colors by hue (sufficiently saturated with moderate lightness)
        switch Int(hue) {
        case 0..<15, 345..<360: return "red"
        case 15..<45: return "orange"
        case 45..<75: return "yellow"
        case 75..<150: return "green"
        case 150..<195: return "cyan"
        case 195..<255: return "blue"
        case 255..<285: return "purple"
        case 285..<345: return "pink"
        default: return "unknown"
        }
    }

    /// All searchable color terms for this color
    var searchableColorTerms: [String] {
        let (_, saturation, lightness) = hslComponents
        let satPercent = saturation * 100
        let lightPercent = lightness * 100

        var terms: [String] = [colorFamily]

        // Add aliases for the color family
        switch colorFamily {
        case "gray": terms.append("grey")
        case "cyan": terms.append("teal")
        case "purple": terms.append("violet")
        case "pink": terms.append("magenta")
        case "brown": terms.append(contentsOf: ["tan", "beige"])
        default: break
        }

        // Get all family terms (including aliases) for compound modifiers
        let familyTerms = terms

        // Add brightness modifiers (only for chromatic colors)
        if colorFamily != "black" && colorFamily != "white" && colorFamily != "gray" {
            if lightPercent < 35 {
                terms.append("dark")
                for family in familyTerms {
                    terms.append("dark \(family)")
                }
            } else if lightPercent > 65 {
                terms.append("light")
                terms.append("pastel")
                for family in familyTerms {
                    terms.append("light \(family)")
                    terms.append("pastel \(family)")
                }
            }

            // Add saturation modifiers
            if satPercent < 45 && satPercent >= 15 {
                terms.append("muted")
                terms.append("dusty")
            } else if satPercent > 75 {
                terms.append("vibrant")
                terms.append("bright")
            }
        }

        return terms
    }

    /// Check if this color matches a search query based on color classification
    func matchesColorSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        return searchableColorTerms.contains { term in
            // Exact match
            if term == lowercaseQuery { return true }

            // Query matches start of term (e.g., "blu" matches "blue")
            if term.hasPrefix(lowercaseQuery) { return true }

            // Term matches start of query (e.g., "blue" matches "blueish")
            if lowercaseQuery.hasPrefix(term) && term.count >= 3 { return true }

            // For compound queries like "dark blue", check if all words match
            if lowercaseQuery.contains(" ") {
                let queryWords = lowercaseQuery.split(separator: " ").map(String.init)
                let termWords = term.split(separator: " ").map(String.init)

                // Check if the term matches the compound query
                if term == lowercaseQuery { return true }

                // Check if query words are present in term
                if termWords.count >= queryWords.count {
                    return queryWords.allSatisfy { queryWord in
                        termWords.contains { termWord in
                            termWord.hasPrefix(queryWord) || termWord == queryWord
                        }
                    }
                }
            }

            return false
        }
    }
}
