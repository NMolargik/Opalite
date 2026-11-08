//
//  SyncHealthPresentationTests.swift
//  OpaliteFeatureSettingsTests
//

import Foundation
import Testing
import OpaliteCore
import OpaliteServices
@testable import OpaliteFeatureSettings

@Suite("Sync health wording")
struct SyncHealthPresentationTests {
    @Test func accountAndStorage() {
        #expect(SyncHealthPresentation.account(isAvailable: true) != SyncHealthPresentation.account(isAvailable: false))
        #expect(SyncHealthPresentation.storageExplanation(.cloudKit) == nil)
        #expect(SyncHealthPresentation.storageExplanation(.localOnly) != nil)
        #expect(SyncHealthPresentation.storageExplanation(.inMemory) != nil)
        #expect(Set([CloudSyncManager.StoreMode.cloudKit, .localOnly, .inMemory].map(SyncHealthPresentation.storage)).count == 3)
    }

    @Test func nothingIsInventedBeforeASyncIsReported() {
        #expect(SyncHealthPresentation.lastSynced(nil) == "Not Yet This Session")
        #expect(SyncHealthPresentation.lastSynced(Date()) != "Not Yet This Session")
    }

    @Test func problemsSayWhetherTheyWereResolved() {
        let error = CloudSyncManager.SyncErrorRecord(message: "Quota exceeded", date: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(SyncHealthPresentation.lastProblem(error, lastSuccess: nil).contains("Quota exceeded"))
        #expect(!SyncHealthPresentation.lastProblem(error, lastSuccess: nil).contains("resolved"))
        #expect(!SyncHealthPresentation.lastProblem(error, lastSuccess: error.date.addingTimeInterval(-5)).contains("resolved"))
        #expect(SyncHealthPresentation.lastProblem(error, lastSuccess: error.date.addingTimeInterval(5)).contains("resolved"))
    }

    @Test func backupWording() {
        let header = BackupHeader(formatVersion: 1, createdAt: Date(), reason: .automatic, appVersion: "", deviceName: "", colorCount: 1, paletteCount: 2)
        #expect(BackupPresentation.counts(header).contains("1") && BackupPresentation.counts(header).contains("2"))
        #expect(Set(BackupReason.allCases.map(BackupPresentation.reason)).count == BackupReason.allCases.count)
        #expect(BackupPresentation.restoreResult(RestoreSummary(colorsKept: 3)).hasPrefix("Nothing to restore"))
        #expect(BackupPresentation.restoreResult(RestoreSummary(colorsAdded: 3, palettesAdded: 1)).contains("3"))
    }
}
