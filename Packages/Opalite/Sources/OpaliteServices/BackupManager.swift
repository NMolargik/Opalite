//
//  BackupManager.swift
//  OpaliteServices
//
//  Automatic local backups of the library. Takes a snapshot of colors, palettes, notes,
//  names, and palette order into `BackupFileStore` (Application Support, never synced)
//  at most once a day, before bulk deletes, and on demand; keeps the newest ten. Restoring
//  is a merge that only ever adds what is missing: it never deletes and never overwrites
//  an item that already exists.
//

import Foundation
import SwiftData
import Observation
import OpaliteCore
import os

/// What a restore changed.
nonisolated public struct RestoreSummary: Equatable, Sendable {
    public var colorsAdded = 0
    public var palettesAdded = 0
    /// Items in the backup that were already in the library and were left exactly as they are.
    public var colorsKept = 0
    public var palettesKept = 0

    public init(colorsAdded: Int = 0, palettesAdded: Int = 0, colorsKept: Int = 0, palettesKept: Int = 0) {
        self.colorsAdded = colorsAdded
        self.palettesAdded = palettesAdded
        self.colorsKept = colorsKept
        self.palettesKept = palettesKept
    }

    public var addedAnything: Bool { colorsAdded + palettesAdded > 0 }
}

@MainActor @Observable
public final class BackupManager {
    public private(set) var records: [BackupRecord] = []
    public private(set) var isWorking = false
    /// The last failure, in plain language; cleared by the next success.
    public private(set) var lastErrorMessage: String?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let store: BackupFileStore
    @ObservationIgnored private let changeCenter: PortfolioChangeCenter?
    @ObservationIgnored private let deviceName: String
    @ObservationIgnored private let appVersion: String
    @ObservationIgnored private let currentPaletteOrder: @MainActor () -> [UUID]
    @ObservationIgnored private let applyPaletteOrder: @MainActor ([UUID]) -> Void
    @ObservationIgnored private let now: @MainActor () -> Date

    /// - Parameters:
    ///   - paletteOrder: The user's manual palette order (read for snapshots).
    ///   - applyPaletteOrder: Replaces the manual order after a restore added palettes.
    public init(
        container: ModelContainer,
        store: BackupFileStore = BackupFileStore(directory: BackupFileStore.defaultDirectory()),
        changeCenter: PortfolioChangeCenter? = nil,
        deviceName: String = "This Device",
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
        paletteOrder: @escaping @MainActor () -> [UUID] = { [] },
        applyPaletteOrder: @escaping @MainActor ([UUID]) -> Void = { _ in },
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.context = container.mainContext
        self.store = store
        self.changeCenter = changeCenter
        self.deviceName = deviceName
        self.appVersion = appVersion
        self.currentPaletteOrder = paletteOrder
        self.applyPaletteOrder = applyPaletteOrder
        self.now = now
        reload()
    }

    public func reload() {
        records = store.list()
    }

    /// When the newest app-made backup was taken.
    public var lastBackupDate: Date? { records.first { $0.header.reason != .imported }?.createdAt }

    // MARK: - Taking backups

    /// The daily backup: call on launch and when the app returns to the foreground. Does
    /// nothing if one was taken in the last 24 hours or the library is empty (an empty
    /// snapshot must never push a good backup out of the list).
    @discardableResult
    public func backUpIfDue() -> BackupRecord? {
        reload()
        guard BackupSchedule.isDue(reason: .automatic, lastBackup: lastBackupDate, now: now()) else { return nil }
        return takeBackup(reason: .automatic, skipWhenEmpty: true)
    }

    /// Call before a bulk delete. Throttled so a run of deletes doesn't flush older backups.
    @discardableResult
    public func backUpBeforeDelete() -> BackupRecord? {
        reload()
        guard BackupSchedule.isDue(reason: .beforeDelete, lastBackup: lastBackupDate, now: now()) else { return nil }
        return takeBackup(reason: .beforeDelete, skipWhenEmpty: true)
    }

    /// "Back Up Now": always takes a backup.
    @discardableResult
    public func backUpNow() -> BackupRecord? {
        takeBackup(reason: .manual, skipWhenEmpty: false)
    }

    private func takeBackup(reason: BackupReason, skipWhenEmpty: Bool) -> BackupRecord? {
        isWorking = true
        defer { isWorking = false }
        do {
            let backup = try snapshot(reason: reason)
            if skipWhenEmpty, backup.isEmpty { return nil }
            let record = try store.write(backup)
            store.prune()
            lastErrorMessage = nil
            reload()
            Log.backup.info("Backed up \(backup.header.colorCount) colors, \(backup.header.paletteCount) palettes (\(reason.rawValue, privacy: .public))")
            return record
        } catch {
            lastErrorMessage = error.localizedDescription
            Log.backup.error("Backup failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Snapshot

    /// A snapshot of the whole library right now.
    public func snapshot(reason: BackupReason) throws(BackupError) -> LibraryBackup {
        let colors: [OpaliteColor]
        let palettes: [OpalitePalette]
        do {
            colors = try context.fetch(FetchDescriptor<OpaliteColor>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)]))
            palettes = try context.fetch(FetchDescriptor<OpalitePalette>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)]))
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
        let paletteIDs = Set(palettes.map(\.id))
        return LibraryBackup(
            createdAt: now(),
            reason: reason,
            appVersion: appVersion,
            deviceName: deviceName,
            colors: colors.map {
                BackupColor(id: $0.id, name: $0.name, notes: $0.notes, createdByDisplayName: $0.createdByDisplayName, createdOnDeviceName: $0.createdOnDeviceName, updatedOnDeviceName: $0.updatedOnDeviceName, createdAt: $0.createdAt, updatedAt: $0.updatedAt, red: $0.red, green: $0.green, blue: $0.blue, alpha: $0.alpha, paletteID: $0.palette?.id)
            },
            palettes: palettes.map {
                BackupPalette(id: $0.id, name: $0.name, notes: $0.notes, tags: $0.tags, createdByDisplayName: $0.createdByDisplayName, previewBackgroundRaw: $0.previewBackgroundRaw, isArchived: $0.isArchived, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            paletteOrder: currentPaletteOrder().filter { paletteIDs.contains($0) }
        )
    }

    // MARK: - Restore

    /// Merges a backup into the library. Adds colors and palettes whose ids are missing;
    /// everything already present is left untouched and nothing is ever deleted.
    @discardableResult
    public func restore(_ record: BackupRecord) throws(BackupError) -> RestoreSummary {
        let backup = try store.load(record)
        return try restore(backup)
    }

    @discardableResult
    public func restore(_ backup: LibraryBackup) throws(BackupError) -> RestoreSummary {
        var summary = RestoreSummary()
        do {
            var palettesByID: [UUID: OpalitePalette] = [:]
            for palette in try context.fetch(FetchDescriptor<OpalitePalette>()) where palettesByID[palette.id] == nil {
                palettesByID[palette.id] = palette
            }
            var existingColorIDs = Set<UUID>()
            for color in try context.fetch(FetchDescriptor<OpaliteColor>()) { existingColorIDs.insert(color.id) }

            var addedPaletteIDs: [UUID] = []
            for source in backup.palettes {
                if palettesByID[source.id] != nil {
                    summary.palettesKept += 1
                    continue
                }
                let palette = OpalitePalette(
                    id: source.id, name: source.name, createdAt: source.createdAt, updatedAt: source.updatedAt,
                    createdByDisplayName: source.createdByDisplayName, notes: source.notes, tags: source.tags, isArchived: source.isArchived
                )
                palette.previewBackgroundRaw = source.previewBackgroundRaw
                context.insert(palette)
                palettesByID[source.id] = palette
                addedPaletteIDs.append(source.id)
                summary.palettesAdded += 1
            }

            for source in backup.colors {
                if existingColorIDs.contains(source.id) {
                    summary.colorsKept += 1
                    continue
                }
                let color = OpaliteColor(
                    id: source.id, name: source.name, notes: source.notes,
                    createdByDisplayName: source.createdByDisplayName, createdOnDeviceName: source.createdOnDeviceName,
                    updatedOnDeviceName: source.updatedOnDeviceName, createdAt: source.createdAt, updatedAt: source.updatedAt,
                    red: source.red, green: source.green, blue: source.blue, alpha: source.alpha
                )
                context.insert(color)
                color.palette = source.paletteID.flatMap { palettesByID[$0] }
                existingColorIDs.insert(source.id)
                summary.colorsAdded += 1
            }

            if context.hasChanges { try context.save() }

            if !addedPaletteIDs.isEmpty {
                // Existing order first, then the restored palettes in the order they had.
                let restoredOrder = backup.paletteOrder.filter(addedPaletteIDs.contains)
                let rest = addedPaletteIDs.filter { !restoredOrder.contains($0) }
                applyPaletteOrder(currentPaletteOrder() + restoredOrder + rest)
            }
        } catch {
            context.rollback()
            throw .writeFailed(error.localizedDescription)
        }
        if summary.addedAnything { changeCenter?.notify(.bulk) }
        Log.backup.info("Restored \(summary.colorsAdded) colors and \(summary.palettesAdded) palettes")
        return summary
    }

    // MARK: - Files

    /// Reads a backup file the user picked and adds it to the list. It is not applied
    /// until the user chooses Restore.
    @discardableResult
    public func importBackup(from url: URL) throws(BackupError) -> BackupRecord {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw .unreadable }
        let record = try store.importBackup(data)
        store.prune()
        reload()
        return record
    }

    /// A copy of the backup under a friendly name in the temp directory, for the share sheet.
    public func shareCopy(of record: BackupRecord) throws(BackupError) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(BackupFileStore.shareFileName(for: record.header))
        do {
            try? FileManager.default.removeItem(at: url)
            try FileManager.default.copyItem(at: record.url, to: url)
            return url
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
    }

    public func delete(_ record: BackupRecord) {
        store.delete(record)
        reload()
    }
}

#if DEBUG
extension BackupManager {
    /// An in-memory library with a few backups on disk, for previews.
    public static func preview() -> BackupManager {
        let schema = Schema([OpaliteColor.self, OpalitePalette.self, CanvasFile.self])
        // Previews only: a throwaway store in the temp directory.
        let url = URL.temporaryDirectory.appending(path: "opalite-preview-\(UUID().uuidString).store")
        let container = (try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)))
            ?? (try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let directory = URL.temporaryDirectory.appending(path: "opalite-preview-backups-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = BackupFileStore(directory: directory)
        for (index, reason) in [BackupReason.automatic, .beforeDelete, .manual].enumerated() {
            let colors = (0..<(4 + index * 3)).map { n in
                BackupColor(id: UUID(), name: nil, notes: nil, createdByDisplayName: nil, createdOnDeviceName: nil, updatedOnDeviceName: nil, createdAt: .now, updatedAt: .now, red: Double(n) / 10, green: 0.4, blue: 0.7, alpha: 1, paletteID: nil)
            }
            let backup = LibraryBackup(createdAt: Date().addingTimeInterval(-Double(index) * 86_400), reason: reason, appVersion: "2.5", deviceName: "iPhone 18 Pro", colors: colors, palettes: [], paletteOrder: [])
            _ = try? store.write(backup)
        }
        return BackupManager(container: container, store: store, deviceName: "iPhone 18 Pro")
    }
}
#endif
