//
//  LibraryBackupTests.swift
//  OpaliteCoreTests
//
//  The backup format (round trip, versioning), the file store (listing, retention,
//  imports), and the schedule.
//

import Foundation
import Testing
@testable import OpaliteCore

enum BackupFixtures {
    static let paletteA = UUID()
    static let paletteB = UUID()

    static func backup(createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000), reason: BackupReason = .manual, colors: Int = 3) -> LibraryBackup {
        let palettes = [
            BackupPalette(id: paletteA, name: "Sunset", notes: "Warm\nand loud", tags: ["warm", "brand"], createdByDisplayName: "Nick", previewBackgroundRaw: "dark", isArchived: false, createdAt: Date(timeIntervalSince1970: 1_600_000_000), updatedAt: Date(timeIntervalSince1970: 1_650_000_000)),
            BackupPalette(id: paletteB, name: "Archive", notes: nil, tags: [], createdByDisplayName: nil, previewBackgroundRaw: nil, isArchived: true, createdAt: Date(timeIntervalSince1970: 1_610_000_000), updatedAt: Date(timeIntervalSince1970: 1_610_000_000)),
        ]
        let colors = (0..<colors).map { index in
            BackupColor(id: UUID(), name: index == 1 ? nil : "Color \(index)", notes: index == 0 ? "夕焼け ☀️" : nil, createdByDisplayName: "Nick", createdOnDeviceName: "iPhone", updatedOnDeviceName: "iPad", createdAt: Date(timeIntervalSince1970: 1_620_000_000 + Double(index)), updatedAt: Date(timeIntervalSince1970: 1_630_000_000 + Double(index)), red: 0.1 * Double(index), green: 0.5, blue: 1.1, alpha: index == 2 ? 0.25 : 1, paletteID: index == 2 ? nil : paletteA)
        }
        return LibraryBackup(createdAt: createdAt, reason: reason, appVersion: "2.5", deviceName: "iPhone 18 Pro", colors: colors, palettes: palettes, paletteOrder: [paletteB, paletteA])
    }

    static func tempDirectory() -> URL {
        URL.temporaryDirectory.appendingPathComponent("opalite-backups-\(UUID().uuidString)", isDirectory: true)
    }
}

@Suite("Library backup format")
struct LibraryBackupFormatTests {
    @Test func roundTripsEveryField() throws {
        let original = BackupFixtures.backup()
        let decoded = try LibraryBackup.decode(from: original.encoded())
        #expect(decoded == original)
        #expect(decoded.colors[1].name == nil)
        #expect(decoded.colors[0].blue == 1.1, "extended-range components survive")
        #expect(decoded.header.colorCount == 3 && decoded.header.paletteCount == 2)
        #expect(decoded.header.formatVersion == LibraryBackup.currentFormatVersion)
    }

    @Test func headerAloneDecodes() throws {
        let data = try BackupFixtures.backup(reason: .beforeDelete).encoded()
        let header = try LibraryBackup.decodeHeader(from: data)
        #expect(header.reason == .beforeDelete && header.deviceName == "iPhone 18 Pro")
    }

    @Test func garbageIsUnreadable() {
        #expect(throws: BackupError.unreadable) { try LibraryBackup.decode(from: Data("hello".utf8)) }
        #expect(throws: BackupError.unreadable) { try LibraryBackup.decode(from: Data("{\"header\": {}}".utf8)) }
        #expect(throws: BackupError.unreadable) { try LibraryBackup.decodeHeader(from: Data()) }
    }

    @Test func newerFormatsAreRefusedNotMisread() throws {
        var backup = BackupFixtures.backup()
        backup.header.formatVersion = LibraryBackup.currentFormatVersion + 1
        let data = try backup.encoded()
        #expect(throws: BackupError.newerFormat(LibraryBackup.currentFormatVersion + 1)) { try LibraryBackup.decode(from: data) }
    }

    @Test func unknownFutureFieldsAreIgnored() throws {
        let original = BackupFixtures.backup()
        let data = try original.encoded()
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["addedInVersionOne"] = ["x": 1]
        let decoded = try LibraryBackup.decode(from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded == original)
    }

    @Test func fractionalSecondsSurvive() throws {
        var original = BackupFixtures.backup()
        original.colors[0].updatedAt = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let decoded = try LibraryBackup.decode(from: original.encoded())
        #expect(decoded.colors[0].updatedAt == original.colors[0].updatedAt)
    }
}

@Suite("Backup file store")
struct BackupFileStoreTests {
    private func makeStore() -> BackupFileStore { BackupFileStore(directory: BackupFixtures.tempDirectory()) }

    @Test func emptyDirectoryListsNothing() {
        #expect(makeStore().list().isEmpty)
        #expect(makeStore().lastBackupDate() == nil)
    }

    @Test func writesAndListsNewestFirst() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        for day in 0..<3 {
            try store.write(BackupFixtures.backup(createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400)))
        }
        let records = store.list()
        #expect(records.count == 3)
        #expect(records.map(\.createdAt) == records.map(\.createdAt).sorted(by: >))
        #expect(store.lastBackupDate() == records[0].createdAt)
        #expect(try store.load(records[0]).colors.count == 3)
    }

    @Test func twoBackupsInTheSameSecondDoNotOverwrite() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try store.write(BackupFixtures.backup())
        try store.write(BackupFixtures.backup())
        #expect(store.list().count == 2)
    }

    @Test func pruneKeepsTheNewestTen() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        for day in 0..<14 {
            try store.write(BackupFixtures.backup(createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400)))
        }
        store.prune()
        let records = store.list()
        #expect(records.count == BackupSchedule.retainedCount)
        #expect(records.last?.createdAt == Date(timeIntervalSince1970: 1_700_000_000 + 4 * 86_400), "the four oldest are gone")
    }

    @Test func importsAreKeptSeparatelyAndNeverPushOutOwnBackups() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        for day in 0..<10 {
            try store.write(BackupFixtures.backup(createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400)))
        }
        // An old file imported from elsewhere is older than everything, yet survives pruning.
        let imported = try store.importBackup(BackupFixtures.backup(createdAt: Date(timeIntervalSince1970: 1_500_000_000)).encoded())
        #expect(imported.header.reason == .imported)
        store.prune()
        #expect(store.list().count == 11)
        #expect(store.lastBackupDate() == Date(timeIntervalSince1970: 1_700_000_000 + 9 * 86_400), "imports don't count as the last backup")
    }

    @Test func importRejectsNonBackups() {
        let store = makeStore()
        #expect(throws: BackupError.unreadable) { try store.importBackup(Data("nope".utf8)) }
        #expect(!FileManager.default.fileExists(atPath: store.directory.path))
    }

    @Test func unreadableFilesAreSkippedAndKept() throws {
        let store = makeStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try store.write(BackupFixtures.backup())
        let stray = store.directory.appendingPathComponent("Opalite-Backup-broken.json")
        try Data("not json".utf8).write(to: stray)
        #expect(store.list().count == 1)
        store.prune(limit: 0, importLimit: 0)
        #expect(FileManager.default.fileExists(atPath: stray.path), "files that aren't backups are never deleted")
    }

    @Test func shareFileNameIsFriendly() {
        let name = BackupFileStore.shareFileName(for: BackupFixtures.backup().header)
        #expect(name.hasPrefix("Opalite Backup 20") && name.hasSuffix(".json"))
    }
}

@Suite("Backup schedule")
struct BackupScheduleTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func automaticBackupsAreDailyAtMost() {
        #expect(BackupSchedule.isDue(reason: .automatic, lastBackup: nil, now: now))
        #expect(!BackupSchedule.isDue(reason: .automatic, lastBackup: now.addingTimeInterval(-23 * 3600), now: now))
        #expect(BackupSchedule.isDue(reason: .automatic, lastBackup: now.addingTimeInterval(-24 * 3600), now: now))
    }

    @Test func preDeleteBackupsAreThrottled() {
        #expect(!BackupSchedule.isDue(reason: .beforeDelete, lastBackup: now.addingTimeInterval(-60), now: now))
        #expect(BackupSchedule.isDue(reason: .beforeDelete, lastBackup: now.addingTimeInterval(-16 * 60), now: now))
    }

    @Test func manualBackupsAreAlwaysDueAndClockSkewDoesNotBlock() {
        #expect(BackupSchedule.isDue(reason: .manual, lastBackup: now, now: now))
        #expect(BackupSchedule.isDue(reason: .automatic, lastBackup: now.addingTimeInterval(3600), now: now), "last backup in the future")
    }
}
