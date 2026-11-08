//
//  LibraryBackup.swift
//  OpaliteCore
//
//  The versioned, Codable snapshot of a user's library (colors, palettes, notes, names,
//  palette order) used for automatic local backups and for backup files the user exports
//  and imports. Pure values: reading and writing the store lives in OpaliteServices.
//
//  Canvases are not part of a backup. Their drawing blobs can be large, they already have
//  their own iCloud copy, and a palette's canvas link is the only thing lost on restore.
//

import Foundation

/// Why a backup was taken.
nonisolated public enum BackupReason: String, Codable, Sendable, CaseIterable {
    /// The daily backup taken on launch or when the app returns to the foreground.
    case automatic
    /// "Back Up Now".
    case manual
    /// Taken just before a bulk delete.
    case beforeDelete
    /// A backup file the user imported from elsewhere.
    case imported
}

nonisolated public struct BackupColor: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String?
    public var notes: String?
    public var createdByDisplayName: String?
    public var createdOnDeviceName: String?
    public var updatedOnDeviceName: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    /// The palette the color belonged to; nil for a loose color.
    public var paletteID: UUID?

    public init(id: UUID, name: String?, notes: String?, createdByDisplayName: String?, createdOnDeviceName: String?, updatedOnDeviceName: String?, createdAt: Date, updatedAt: Date, red: Double, green: Double, blue: Double, alpha: Double, paletteID: UUID?) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdByDisplayName = createdByDisplayName
        self.createdOnDeviceName = createdOnDeviceName
        self.updatedOnDeviceName = updatedOnDeviceName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.paletteID = paletteID
    }
}

nonisolated public struct BackupPalette: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var notes: String?
    public var tags: [String]
    public var createdByDisplayName: String?
    public var previewBackgroundRaw: String?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, notes: String?, tags: [String], createdByDisplayName: String?, previewBackgroundRaw: String?, isArchived: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.notes = notes
        self.tags = tags
        self.createdByDisplayName = createdByDisplayName
        self.previewBackgroundRaw = previewBackgroundRaw
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// What a backup file says about itself without decoding the library.
nonisolated public struct BackupHeader: Codable, Sendable, Equatable {
    public var formatVersion: Int
    public var createdAt: Date
    public var reason: BackupReason
    public var appVersion: String
    public var deviceName: String
    public var colorCount: Int
    public var paletteCount: Int

    public init(formatVersion: Int, createdAt: Date, reason: BackupReason, appVersion: String, deviceName: String, colorCount: Int, paletteCount: Int) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.reason = reason
        self.appVersion = appVersion
        self.deviceName = deviceName
        self.colorCount = colorCount
        self.paletteCount = paletteCount
    }
}

nonisolated public enum BackupError: LocalizedError, Equatable, Sendable {
    /// Not an Opalite backup, or damaged.
    case unreadable
    /// Written by a newer version of Opalite.
    case newerFormat(Int)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable: String(localized: "This file isn't an Opalite backup, or it's damaged.")
        case .newerFormat: String(localized: "This backup was made by a newer version of Opalite. Update Opalite to restore it.")
        case .writeFailed(let reason): String(localized: "The backup couldn't be saved: \(reason)")
        }
    }
}

nonisolated public struct LibraryBackup: Codable, Sendable, Equatable {
    /// The format this build writes. Bump only for changes older builds can't read; adding
    /// optional fields doesn't need a bump.
    public static let currentFormatVersion = 1

    public var header: BackupHeader
    public var colors: [BackupColor]
    public var palettes: [BackupPalette]
    /// The user's manual palette order.
    public var paletteOrder: [UUID]

    public init(header: BackupHeader, colors: [BackupColor], palettes: [BackupPalette], paletteOrder: [UUID]) {
        self.header = header
        self.colors = colors
        self.palettes = palettes
        self.paletteOrder = paletteOrder
    }

    public init(createdAt: Date, reason: BackupReason, appVersion: String, deviceName: String, colors: [BackupColor], palettes: [BackupPalette], paletteOrder: [UUID]) {
        self.init(
            header: BackupHeader(formatVersion: Self.currentFormatVersion, createdAt: createdAt, reason: reason, appVersion: appVersion, deviceName: deviceName, colorCount: colors.count, paletteCount: palettes.count),
            colors: colors,
            palettes: palettes,
            paletteOrder: paletteOrder
        )
    }

    public var isEmpty: Bool { colors.isEmpty && palettes.isEmpty }

    // MARK: Coding

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    public func encoded() throws(BackupError) -> Data {
        do {
            return try Self.makeEncoder().encode(self)
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
    }

    /// Reads only the header, so listing backups doesn't decode every color.
    public static func decodeHeader(from data: Data) throws(BackupError) -> BackupHeader {
        struct HeaderOnly: Decodable { let header: BackupHeader }
        guard let wrapper = try? makeDecoder().decode(HeaderOnly.self, from: data) else { throw .unreadable }
        if wrapper.header.formatVersion > currentFormatVersion { throw .newerFormat(wrapper.header.formatVersion) }
        return wrapper.header
    }

    public static func decode(from data: Data) throws(BackupError) -> LibraryBackup {
        _ = try decodeHeader(from: data)
        guard let backup = try? makeDecoder().decode(LibraryBackup.self, from: data) else { throw .unreadable }
        return backup
    }
}

// MARK: - Schedule

nonisolated public enum BackupSchedule {
    /// Automatic backups are taken at most this often.
    public static let automaticInterval: TimeInterval = 24 * 60 * 60
    /// Backups before bulk deletes are taken at most this often, so a run of deletes
    /// doesn't push every older backup out of the list.
    public static let preDeleteInterval: TimeInterval = 15 * 60
    /// Automatic, manual, and pre-delete backups kept on disk (newest first).
    public static let retainedCount = 10
    /// Imported backup files kept in addition to the above.
    public static let retainedImportCount = 5

    /// Whether `reason` should produce a backup now, given when the last one of any
    /// non-imported kind was taken.
    public static func isDue(reason: BackupReason, lastBackup: Date?, now: Date) -> Bool {
        guard let lastBackup else { return true }
        let elapsed = now.timeIntervalSince(lastBackup)
        // A clock that moved backwards must not suppress backups forever.
        if elapsed < 0 { return true }
        switch reason {
        case .automatic: return elapsed >= automaticInterval
        case .beforeDelete: return elapsed >= preDeleteInterval
        case .manual, .imported: return true
        }
    }
}
