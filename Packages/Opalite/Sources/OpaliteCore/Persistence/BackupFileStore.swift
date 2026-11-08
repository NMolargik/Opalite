//
//  BackupFileStore.swift
//  OpaliteCore
//
//  Backup files in one directory (Application Support/Opalite/Backups in the app), newest
//  first, with retention. Plain Foundation file I/O so it is host-tested against a temp
//  directory. Application Support is not synced to iCloud Drive; backups stay on the device.
//

import Foundation

/// A backup file on disk.
nonisolated public struct BackupRecord: Identifiable, Equatable, Sendable {
    public let url: URL
    public let header: BackupHeader
    public var id: String { url.lastPathComponent }
    public var createdAt: Date { header.createdAt }

    public init(url: URL, header: BackupHeader) {
        self.url = url
        self.header = header
    }
}

nonisolated public struct BackupFileStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/Opalite/Backups`.
    public static func defaultDirectory() -> URL {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("Opalite", isDirectory: true).appendingPathComponent("Backups", isDirectory: true)
    }

    public static let fileExtension = "json"
    private static let prefix = "Opalite-Backup-"

    // MARK: Reading

    /// Every readable backup, newest first. Unreadable files are skipped, never deleted.
    public func list() -> [BackupRecord] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.lastPathComponent.hasPrefix(Self.prefix) && $0.pathExtension == Self.fileExtension }
            .compactMap { url -> BackupRecord? in
                guard let data = try? Data(contentsOf: url), let header = try? LibraryBackup.decodeHeader(from: data) else { return nil }
                return BackupRecord(url: url, header: header)
            }
            .sorted { $0.createdAt > $1.createdAt || ($0.createdAt == $1.createdAt && $0.id > $1.id) }
    }

    public func load(_ record: BackupRecord) throws(BackupError) -> LibraryBackup {
        guard let data = try? Data(contentsOf: record.url) else { throw .unreadable }
        return try LibraryBackup.decode(from: data)
    }

    /// The newest backup that was taken by the app (imports don't count).
    public func lastBackupDate() -> Date? {
        list().first { $0.header.reason != .imported }?.createdAt
    }

    // MARK: Writing

    @discardableResult
    public func write(_ backup: LibraryBackup) throws(BackupError) -> BackupRecord {
        let data = try backup.encoded()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(Self.fileName(for: backup.header))
            try data.write(to: url, options: .atomic)
            return BackupRecord(url: url, header: backup.header)
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
    }

    /// Validates `data` as a backup and stores it as an imported backup.
    @discardableResult
    public func importBackup(_ data: Data) throws(BackupError) -> BackupRecord {
        var backup = try LibraryBackup.decode(from: data)
        backup.header.reason = .imported
        return try write(backup)
    }

    public func delete(_ record: BackupRecord) {
        try? FileManager.default.removeItem(at: record.url)
    }

    /// Removes everything beyond the newest `limit` app-made backups and the newest
    /// `importLimit` imported ones.
    public func prune(limit: Int = BackupSchedule.retainedCount, importLimit: Int = BackupSchedule.retainedImportCount) {
        let records = list()
        let own = records.filter { $0.header.reason != .imported }
        let imported = records.filter { $0.header.reason == .imported }
        for record in own.dropFirst(max(0, limit)) { delete(record) }
        for record in imported.dropFirst(max(0, importLimit)) { delete(record) }
    }

    // MARK: Names

    /// "Opalite-Backup-20261108-093015-automatic-1a2b.json": sortable, and unique even for
    /// two backups in the same second.
    static func fileName(for header: BackupHeader) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let token = UUID().uuidString.prefix(4).lowercased()
        return "\(prefix)\(formatter.string(from: header.createdAt))-\(header.reason.rawValue)-\(token).\(fileExtension)"
    }

    /// A friendly name for sharing a backup: "Opalite Backup 2026-11-08.json".
    public static func shareFileName(for header: BackupHeader) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return "Opalite Backup \(formatter.string(from: header.createdAt)).\(fileExtension)"
    }
}
