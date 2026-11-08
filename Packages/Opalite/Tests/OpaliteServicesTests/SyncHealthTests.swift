//
//  SyncHealthTests.swift
//  OpaliteServicesTests
//
//  What the sync manager reports for the Settings sync-health rows: only what CloudKit
//  events actually said.
//

import Foundation
import Testing
import OpaliteCore
@testable import OpaliteServices

@Suite("Sync health")
struct SyncHealthTests {
    typealias Event = CloudSyncManager.CloudEventSnapshot

    private func makeManager() -> CloudSyncManager {
        CloudSyncManager(cloudAvailability: { true })
    }

    @Test func nothingIsReportedBeforeTheFirstEvent() {
        let manager = makeManager()
        #expect(manager.lastSuccessfulSyncDate == nil && manager.lastSyncError == nil)
        #expect(manager.storeMode == .cloudKit)
    }

    @Test func remoteChangePingsAreNotSyncs() {
        let manager = makeManager()
        manager.handleRemoteChange()
        #expect(manager.lastSuccessfulSyncDate == nil, "a store-change ping also fires for local saves")
    }

    @Test func successfulEventsSetTheLastSuccessfulSync() {
        let manager = makeManager()
        manager.handleCloudEvent(Event(isImport: false, isFinished: false, succeeded: false, errorDescription: nil))
        #expect(manager.lastSuccessfulSyncDate == nil, "an unfinished event is not a success")
        manager.handleCloudEvent(Event(isImport: false, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(manager.lastSuccessfulSyncDate != nil)
    }

    @Test func errorsAreRememberedAfterRecovery() {
        let manager = makeManager()
        manager.handleCloudEvent(Event(isImport: false, isFinished: true, succeeded: false, errorDescription: "Quota exceeded"))
        #expect(manager.lastSyncError?.message == "Quota exceeded")
        #expect(manager.lastSuccessfulSyncDate == nil)
        manager.handleCloudEvent(Event(isImport: true, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(manager.lastErrorMessage == nil, "the live status clears")
        #expect(manager.lastSyncError?.message == "Quota exceeded", "the history stays")
        #expect(manager.lastSuccessfulSyncDate != nil)
    }

    @Test func storeModeIsWhateverTheContainerWas() {
        let manager = makeManager()
        manager.configure(storeMode: .localOnly)
        #expect(manager.storeMode == .localOnly)
    }
}
