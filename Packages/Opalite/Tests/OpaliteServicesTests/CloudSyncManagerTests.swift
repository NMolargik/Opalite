//
//  CloudSyncManagerTests.swift
//  OpaliteServicesTests
//
//  The sync state machine driven through the internal event/network/remote-change hooks.
//

import Foundation
import Testing
import OpaliteCore
@testable import OpaliteServices

@Suite("CloudSyncManager")
struct CloudSyncManagerTests {
    typealias Event = CloudSyncManager.CloudEventSnapshot

    private func makeManager(cloudAvailable: Bool = true, changeCenter: PortfolioChangeCenter? = nil) -> CloudSyncManager {
        CloudSyncManager(changeCenter: changeCenter, cloudAvailability: { cloudAvailable })
    }

    @Test func initialState() {
        let manager = makeManager()
        #expect(manager.syncStatus == .idle)
        #expect(!manager.isSyncing)
        #expect(manager.isOnline)
        #expect(manager.lastSyncDate == nil)
        #expect(!manager.hasReceivedRemoteChange)
        #expect(manager.isCloudAvailable)
        #expect(!makeManager(cloudAvailable: false).isCloudAvailable)
    }

    @Test func networkLossGoesOfflineAndBack() {
        let manager = makeManager()
        manager.handleNetworkChange(isAvailable: false)
        #expect(manager.syncStatus == .offline && !manager.isOnline)
        manager.handleNetworkChange(isAvailable: true)
        #expect(manager.syncStatus == .idle && manager.isOnline)
    }

    @Test func offlineOutranksEveryOtherState() {
        let manager = makeManager()
        manager.handleCloudEvent(Event(isImport: false, isFinished: false, succeeded: false, errorDescription: nil))
        manager.handleNetworkChange(isAvailable: false)
        #expect(manager.syncStatus == .offline)
        manager.handleNetworkChange(isAvailable: true)
        #expect(manager.syncStatus == .syncing)
    }

    @Test func missingAccountIsUnavailable() {
        let manager = makeManager(cloudAvailable: false)
        manager.handleNetworkChange(isAvailable: true)
        #expect(manager.syncStatus == .unavailable)
        manager.handleCloudEvent(Event(isImport: true, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(manager.syncStatus == .unavailable, "an account outage masks sync events")
        #expect(manager.lastSyncDate != nil)
    }

    @Test func inFlightEventsShowSyncing() {
        let manager = makeManager()
        manager.handleCloudEvent(Event(isImport: false, isFinished: false, succeeded: false, errorDescription: nil))
        #expect(manager.isSyncing)
        #expect(manager.syncStatus == .syncing)
    }

    @Test func successfulExportRecordsSyncDateWithoutARemoteChange() throws {
        let center = PortfolioChangeCenter()
        let manager = makeManager(changeCenter: center)
        manager.handleCloudEvent(Event(isImport: false, isFinished: false, succeeded: false, errorDescription: nil))
        manager.handleCloudEvent(Event(isImport: false, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(!manager.isSyncing)
        let date = try #require(manager.lastSyncDate)
        #expect(manager.syncStatus == .synced(date))
        #expect(!manager.hasReceivedRemoteChange)
        #expect(manager.lastErrorMessage == nil)
    }

    @Test func successfulImportRelaysABulkChange() async {
        let center = PortfolioChangeCenter()
        let stream = center.changes()
        let manager = makeManager(changeCenter: center)
        manager.handleCloudEvent(Event(isImport: true, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(manager.hasReceivedRemoteChange)
        var iterator = stream.makeAsyncIterator()
        let change = await iterator.next()
        #expect(change == .bulk)
    }

    @Test func failedEventSurfacesTheErrorUntilTheNextSuccess() {
        let manager = makeManager()
        manager.handleCloudEvent(Event(isImport: false, isFinished: true, succeeded: false, errorDescription: "Quota exceeded"))
        #expect(manager.syncStatus == .error("Quota exceeded"))
        #expect(manager.syncStatus.isError)
        #expect(manager.lastErrorMessage == "Quota exceeded")
        #expect(manager.lastSyncDate == nil)

        manager.handleCloudEvent(Event(isImport: false, isFinished: true, succeeded: true, errorDescription: nil))
        #expect(!manager.syncStatus.isError)
        #expect(manager.lastErrorMessage == nil)
        if case .synced = manager.syncStatus {} else { Issue.record("expected synced, got \(manager.syncStatus)") }
    }

    @Test func failedEventWithoutAMessageStaysQuiet() {
        let manager = makeManager()
        manager.handleCloudEvent(Event(isImport: false, isFinished: true, succeeded: false, errorDescription: nil))
        #expect(manager.syncStatus == .idle)
        #expect(manager.lastErrorMessage == nil)
    }

    @Test func remoteChangeMarksSyncedAndNotifies() async {
        let center = PortfolioChangeCenter()
        let stream = center.changes()
        let manager = makeManager(changeCenter: center)
        manager.handleRemoteChange()
        #expect(manager.hasReceivedRemoteChange)
        #expect(manager.lastSyncDate != nil)
        if case .synced = manager.syncStatus {} else { Issue.record("expected synced, got \(manager.syncStatus)") }
        var iterator = stream.makeAsyncIterator()
        let change = await iterator.next()
        #expect(change == .bulk)
        manager.resetRemoteChangeTracking()
        #expect(!manager.hasReceivedRemoteChange)
    }

    @Test func waitForRemoteChangeShortCircuits() async {
        let manager = makeManager()
        manager.handleRemoteChange()
        #expect(await manager.waitForRemoteChange(timeout: 0.01))

        let unavailable = makeManager(cloudAvailable: false)
        #expect(await unavailable.waitForRemoteChange(timeout: 0.01) == false)

        let offline = makeManager()
        offline.handleNetworkChange(isAvailable: false)
        #expect(await offline.waitForRemoteChange(timeout: 0.01) == false)
    }

    @Test func waitForRemoteChangeTimesOutThenSeesALateChange() async {
        let manager = makeManager()
        #expect(await manager.waitForRemoteChange(timeout: 0.05, pollInterval: .milliseconds(10)) == false)
        let waiter = Task { await manager.waitForRemoteChange(timeout: 2, pollInterval: .milliseconds(10)) }
        try? await Task.sleep(for: .milliseconds(30))
        manager.handleRemoteChange()
        #expect(await waiter.value)
    }

    @Test func triggerSyncGuards() async {
        let offline = makeManager()
        offline.handleNetworkChange(isAvailable: false)
        await offline.triggerSync()
        #expect(offline.syncStatus == .offline)

        let unavailable = makeManager(cloudAvailable: false)
        await unavailable.triggerSync()
        #expect(unavailable.syncStatus == .unavailable)

        let unconfigured = makeManager()
        await unconfigured.triggerSync()
        #expect(unconfigured.syncStatus == .error("Not configured"))
    }

    @Test func cleanupBeforeConfigureIsHarmless() {
        let manager = makeManager()
        manager.cleanup()
        #expect(manager.syncStatus == .idle)
    }

    @Test func statusSymbols() {
        let statuses: [CloudSyncManager.SyncStatus] = [.idle, .syncing, .synced(Date()), .error("x"), .offline, .unavailable]
        #expect(Set(statuses.map(\.systemImage)).count == statuses.count)
        #expect(statuses.filter(\.isError).count == 1)
        #expect(CloudSyncManager.SyncStatus.offline.systemImage == "icloud.slash")
    }
}
