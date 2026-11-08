//
//  BackupManagerTests.swift
//  OpaliteServicesTests
//
//  Snapshots, the daily/pre-delete schedule, retention, and restoring (merge) into an
//  empty and a non-empty store, over unique on-disk temporary stores.
//

import Foundation
import SwiftData
import Testing
import OpaliteCore
import OpaliteData
@testable import OpaliteServices

@MainActor
private final class Harness {
    let container: ModelContainer
    let directory = URL.temporaryDirectory.appendingPathComponent("opalite-bm-\(UUID().uuidString)", isDirectory: true)
    var clock = Date(timeIntervalSince1970: 1_700_000_000)
    var order: [UUID] = []
    let changeCenter = PortfolioChangeCenter()
    private(set) lazy var manager = BackupManager(
        container: container,
        store: BackupFileStore(directory: directory),
        changeCenter: changeCenter,
        deviceName: "Test Phone",
        appVersion: "9.9",
        paletteOrder: { [unowned self] in order },
        applyPaletteOrder: { [unowned self] in order = $0 },
        now: { [unowned self] in clock }
    )

    init() throws { container = try OpaliteStore.makeTemporaryContainer() }

    deinit {
        try? FileManager.default.removeItem(at: directory)
        if let url = container.configurations.first?.url { try? FileManager.default.removeItem(at: url) }
    }

    var context: ModelContext { container.mainContext }

    @discardableResult
    func addPalette(_ name: String, colors: [(String?, Double)] = []) throws -> OpalitePalette {
        let palette = OpalitePalette(name: name, notes: "notes for \(name)", tags: ["t"])
        context.insert(palette)
        for (colorName, red) in colors {
            let color = OpaliteColor(name: colorName, notes: "n", red: red, green: 0.2, blue: 0.3)
            context.insert(color)
            color.palette = palette
        }
        try context.save()
        return palette
    }

    @discardableResult
    func addLoose(_ name: String) throws -> OpaliteColor {
        let color = OpaliteColor(name: name, red: 0.9, green: 0.8, blue: 0.7, alpha: 0.5)
        context.insert(color)
        try context.save()
        return color
    }

    func counts() throws -> (colors: Int, palettes: Int) {
        (try context.fetchCount(FetchDescriptor<OpaliteColor>()), try context.fetchCount(FetchDescriptor<OpalitePalette>()))
    }
}

@Suite("BackupManager", .serialized)
@MainActor
struct BackupManagerTests {
    @Test func snapshotCapturesTheLibrary() throws {
        let h = try Harness()
        let sunset = try h.addPalette("Sunset", colors: [("Dusk", 0.8), (nil, 0.6)])
        try h.addLoose("Loose")
        h.order = [sunset.id, UUID()]
        let backup = try h.manager.snapshot(reason: .manual)
        #expect(backup.header.colorCount == 3 && backup.header.paletteCount == 1)
        #expect(backup.header.deviceName == "Test Phone" && backup.header.appVersion == "9.9")
        #expect(backup.paletteOrder == [sunset.id], "ids of palettes that no longer exist are dropped")
        let dusk = try #require(backup.colors.first { $0.name == "Dusk" })
        #expect(dusk.paletteID == sunset.id && dusk.notes == "n" && dusk.red == 0.8)
        #expect(try #require(backup.colors.first { $0.name == "Loose" }).paletteID == nil)
        #expect(backup.palettes[0].tags == ["t"] && backup.palettes[0].notes == "notes for Sunset")
    }

    @Test func restoreIntoAnEmptyStoreRebuildsEverything() async throws {
        let source = try Harness()
        let sunset = try source.addPalette("Sunset", colors: [("Dusk", 0.8), ("Dawn", 0.4)])
        let ocean = try source.addPalette("Ocean", colors: [("Deep", 0.1)])
        try source.addLoose("Loose")
        source.order = [ocean.id, sunset.id]
        let backup = try source.manager.snapshot(reason: .manual)

        let target = try Harness()
        let stream = target.changeCenter.changes()
        let listener = Task { () -> Bool in
            for await change in stream where change == .bulk { return true }
            return false
        }
        let summary = try target.manager.restore(backup)
        #expect(summary == RestoreSummary(colorsAdded: 4, palettesAdded: 2, colorsKept: 0, palettesKept: 0))
        #expect(try target.counts() == (4, 2))
        #expect(target.order == [ocean.id, sunset.id], "the manual order comes back")
        #expect(await listener.value, "the portfolio is told to refresh")

        let restored = try target.context.fetch(FetchDescriptor<OpalitePalette>())
        let restoredSunset = try #require(restored.first { $0.id == sunset.id })
        #expect(restoredSunset.colorCount == 2 && restoredSunset.notes == "notes for Sunset")
        #expect(Set(restoredSunset.colors?.map(\.id) ?? []) == Set(sunset.colors?.map(\.id) ?? []))
        let loose = try #require(try target.context.fetch(FetchDescriptor<OpaliteColor>()).first { $0.name == "Loose" })
        #expect(loose.palette == nil && loose.alpha == 0.5)
    }

    @Test func restoreIntoANonEmptyStoreOnlyAdds() throws {
        let h = try Harness()
        let sunset = try h.addPalette("Sunset", colors: [("Dusk", 0.8)])
        let loose = try h.addLoose("Loose")
        let existingOrder = [sunset.id]
        h.order = existingOrder
        let backup = try h.manager.snapshot(reason: .manual)

        // Afterwards the user edits, deletes, and adds things.
        sunset.name = "Sunset (edited)"
        let dusk = try #require(sunset.colors?.first)
        dusk.red = 0.0
        dusk.name = "Edited"
        let duskID = dusk.id
        h.context.delete(loose)
        let fresh = try h.addPalette("Brand new", colors: [("Fresh", 0.5)])
        h.order = [fresh.id, sunset.id]

        let summary = try h.manager.restore(backup)
        #expect(summary.colorsKept == 1 && summary.palettesKept == 1)
        #expect(summary.colorsAdded == 1 && summary.palettesAdded == 0, "only the deleted loose color returns")

        let colors = try h.context.fetch(FetchDescriptor<OpaliteColor>())
        #expect(colors.count == 3)
        let keptDusk = try #require(colors.first { $0.id == duskID })
        #expect(keptDusk.name == "Edited" && keptDusk.red == 0.0, "existing items are never overwritten")
        #expect(colors.contains { $0.name == "Fresh" }, "nothing is deleted")
        let palettes = try h.context.fetch(FetchDescriptor<OpalitePalette>())
        #expect(palettes.count == 2 && palettes.contains { $0.name == "Sunset (edited)" })
        #expect(h.order == [fresh.id, sunset.id], "the order is only touched when palettes were added")
    }

    @Test func restoreTwiceIsIdempotent() throws {
        let h = try Harness()
        try h.addPalette("Sunset", colors: [("Dusk", 0.8)])
        let backup = try h.manager.snapshot(reason: .manual)
        let other = try Harness()
        _ = try other.manager.restore(backup)
        let second = try other.manager.restore(backup)
        #expect(second == RestoreSummary(colorsAdded: 0, palettesAdded: 0, colorsKept: 1, palettesKept: 1))
        #expect(try other.counts() == (1, 1))
    }

    @Test func restoredPalettesAppendAfterTheExistingOrder() throws {
        let source = try Harness()
        let a = try source.addPalette("A")
        let b = try source.addPalette("B")
        source.order = [b.id, a.id]
        let backup = try source.manager.snapshot(reason: .manual)
        let target = try Harness()
        let mine = try target.addPalette("Mine")
        target.order = [mine.id]
        _ = try target.manager.restore(backup)
        #expect(target.order == [mine.id, b.id, a.id])
    }

    @Test func backUpNowWritesALoadableFile() throws {
        let h = try Harness()
        try h.addPalette("Sunset", colors: [("Dusk", 0.8)])
        let record = try #require(h.manager.backUpNow())
        #expect(h.manager.records.map(\.id) == [record.id])
        #expect(record.header.colorCount == 1 && record.header.reason == .manual)
        #expect(h.manager.lastBackupDate == h.clock)
        // Restoring a record from disk works the same as restoring a snapshot.
        let other = try Harness()
        #expect(try other.manager.restore(record).colorsAdded == 1)
    }

    @Test func dailyBackupHappensOncePerDayAndSkipsEmptyLibraries() throws {
        let h = try Harness()
        #expect(h.manager.backUpIfDue() == nil, "an empty library is never backed up automatically")
        try h.addLoose("Loose")
        #expect(h.manager.backUpIfDue() != nil)
        h.clock.addTimeInterval(3600)
        #expect(h.manager.backUpIfDue() == nil)
        h.clock.addTimeInterval(24 * 3600)
        #expect(h.manager.backUpIfDue() != nil)
        #expect(h.manager.records.count == 2)
    }

    @Test func beforeDeleteBackupsAreThrottled() throws {
        let h = try Harness()
        try h.addLoose("Loose")
        #expect(h.manager.backUpBeforeDelete() != nil)
        h.clock.addTimeInterval(120)
        #expect(h.manager.backUpBeforeDelete() == nil)
        h.clock.addTimeInterval(16 * 60)
        #expect(h.manager.backUpBeforeDelete()?.header.reason == .beforeDelete)
    }

    @Test func onlyTheNewestTenSurvive() throws {
        let h = try Harness()
        try h.addLoose("Loose")
        for _ in 0..<13 {
            h.clock.addTimeInterval(25 * 3600)
            #expect(h.manager.backUpIfDue() != nil)
        }
        #expect(h.manager.records.count == 10)
        #expect(h.manager.records.first?.createdAt == h.clock)
    }

    @Test func importedBackupsJoinTheListWithoutRestoringAnything() throws {
        let source = try Harness()
        try source.addPalette("Sunset", colors: [("Dusk", 0.8)])
        let record = try #require(source.manager.backUpNow())
        let file = try source.manager.shareCopy(of: record)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(file.lastPathComponent.hasPrefix("Opalite Backup "))

        let target = try Harness()
        let imported = try target.manager.importBackup(from: file)
        #expect(imported.header.reason == .imported && target.manager.records.count == 1)
        #expect(try target.counts() == (0, 0))
        #expect(try target.manager.restore(imported).colorsAdded == 1)

        let junk = URL.temporaryDirectory.appendingPathComponent("junk-\(UUID().uuidString).json")
        try Data("nope".utf8).write(to: junk)
        defer { try? FileManager.default.removeItem(at: junk) }
        #expect(throws: BackupError.unreadable) { try target.manager.importBackup(from: junk) }
    }

    @Test func failedRestoreLeavesTheLibraryAlone() throws {
        let h = try Harness()
        try h.addLoose("Loose")
        let missing = BackupRecord(url: h.directory.appendingPathComponent("nope.json"), header: BackupHeader(formatVersion: 1, createdAt: h.clock, reason: .manual, appVersion: "", deviceName: "", colorCount: 0, paletteCount: 0))
        #expect(throws: BackupError.unreadable) { try h.manager.restore(missing) }
        #expect(try h.counts() == (1, 0))
    }
}
