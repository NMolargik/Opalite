//
//  CloudSyncManager.swift
//  OpaliteServices
//
//  Monitors iCloud/CloudKit sync for SwiftData by listening to the underlying
//  NSPersistentCloudKitContainer event stream (setup/import/export with errors) plus
//  remote-change pings, relaying imports into the portfolio change stream so screens
//  refresh mid-session. Also the app's single network-reachability source.
//

import Foundation
import SwiftData
import CoreData
import Network
import Observation
import OpaliteCore
import os

@MainActor @Observable
public final class CloudSyncManager {

    public enum SyncStatus: Equatable, Sendable {
        case idle
        case syncing
        case synced(Date)
        case error(String)
        case offline
        /// No iCloud account on this device.
        case unavailable

        public var isError: Bool {
            if case .error = self { return true }
            return false
        }

        public var systemImage: String {
            switch self {
            case .idle: "icloud"
            case .syncing: "arrow.triangle.2.circlepath.icloud"
            case .synced: "checkmark.icloud"
            case .error: "exclamationmark.icloud"
            case .offline: "icloud.slash"
            case .unavailable: "person.icloud"
            }
        }
    }

    public struct SyncErrorRecord: Equatable, Sendable {
        public let message: String
        public let date: Date

        public init(message: String, date: Date) {
            self.message = message
            self.date = date
        }
    }

    /// Whether the SwiftData container is CloudKit-backed. `OpaliteStore` falls back to a
    /// local or in-memory store when CloudKit can't be set up.
    public enum StoreMode: Equatable, Sendable {
        case cloudKit
        case localOnly
        case inMemory
    }

    public private(set) var syncStatus: SyncStatus = .idle
    public private(set) var isSyncing = false
    public private(set) var lastSyncDate: Date?
    public private(set) var hasReceivedRemoteChange = false
    public private(set) var lastErrorMessage: String?
    /// When CloudKit last reported a finished import or export that succeeded. Unlike
    /// `lastSyncDate`, local saves and manual refreshes never set it. Nil until an event
    /// arrives in this launch: the system does not report earlier syncs.
    public private(set) var lastSuccessfulSyncDate: Date?
    /// The most recent failure CloudKit reported this launch, kept after a later success.
    public private(set) var lastSyncError: SyncErrorRecord?
    /// How the library is stored on this device.
    public private(set) var storeMode: StoreMode = .cloudKit
    /// Whether the network is reachable.
    public private(set) var isOnline = true

    @ObservationIgnored private let changeCenter: PortfolioChangeCenter?
    @ObservationIgnored private let cloudAvailability: @MainActor () -> Bool
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var networkMonitor: NWPathMonitor?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    public init(
        changeCenter: PortfolioChangeCenter? = nil,
        cloudAvailability: @escaping @MainActor () -> Bool = { FileManager.default.ubiquityIdentityToken != nil }
    ) {
        self.changeCenter = changeCenter
        self.cloudAvailability = cloudAvailability
    }

    /// Records how the container was actually created (it can degrade from CloudKit).
    public func configure(storeMode mode: StoreMode) {
        storeMode = mode
        updateSyncStatus()
    }

    public func configure(with context: ModelContext) {
        guard modelContext == nil else { return }
        modelContext = context
        startMonitoring()
    }

    public func cleanup() {
        networkMonitor?.cancel()
        networkMonitor = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
    }

    public var isCloudAvailable: Bool {
        #if DEBUG
        if let debugCloudAvailable { return debugCloudAvailable }
        #endif
        return cloudAvailability()
    }

    #if DEBUG
    /// Debug builds only: pins the account check for `--simulate-icloud`.
    @ObservationIgnored private var debugCloudAvailable: Bool?

    /// Debug builds only: puts the manager in a state for screenshots and UI checks
    /// (`--simulate-icloud=synced|syncing|error|signedout|offline|local`).
    public func simulate(_ name: String) {
        debugCloudAvailable = name != "signedout"
        isOnline = name != "offline"
        isSyncing = name == "syncing"
        storeMode = name == "local" ? .localOnly : .cloudKit
        lastErrorMessage = name == "error" ? "iCloud storage is full" : nil
        lastSyncError = name == "error" ? SyncErrorRecord(message: "iCloud storage is full", date: Date()) : nil
        lastSuccessfulSyncDate = ["synced", "offline"].contains(name) ? Date().addingTimeInterval(-300) : nil
        lastSyncDate = lastSuccessfulSyncDate
        updateSyncStatus()
    }
    #endif

    // MARK: - Monitoring

    private func startMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            Task { @MainActor in self?.handleNetworkChange(isAvailable: available) }
        }
        monitor.start(queue: DispatchQueue(label: "com.molargiksoftware.Opalite.network"))
        networkMonitor = monitor

        observers.append(NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleRemoteChange() }
        })

        observers.append(NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { [weak self] notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return }
            let snapshot = CloudEventSnapshot(event)
            Task { @MainActor in self?.handleCloudEvent(snapshot) }
        })

        updateSyncStatus()
    }

    /// Sendable snapshot of the fields we need from a CloudKit container event.
    nonisolated struct CloudEventSnapshot: Sendable {
        let isImport: Bool
        let isFinished: Bool
        let succeeded: Bool
        let errorDescription: String?

        init(_ event: NSPersistentCloudKitContainer.Event) {
            isImport = event.type == .import
            isFinished = event.endDate != nil
            succeeded = event.succeeded
            errorDescription = event.error?.localizedDescription
        }

        init(isImport: Bool, isFinished: Bool, succeeded: Bool, errorDescription: String?) {
            self.isImport = isImport
            self.isFinished = isFinished
            self.succeeded = succeeded
            self.errorDescription = errorDescription
        }
    }

    func handleCloudEvent(_ event: CloudEventSnapshot) {
        if !event.isFinished {
            isSyncing = true
        } else {
            isSyncing = false
            if event.succeeded {
                lastSyncDate = Date()
                lastSuccessfulSyncDate = lastSyncDate
                lastErrorMessage = nil
                if event.isImport { markRemoteChangeReceived() }
            } else if let message = event.errorDescription {
                lastErrorMessage = message
                lastSyncError = SyncErrorRecord(message: message, date: Date())
                Log.sync.error("CloudKit sync event failed: \(message)")
            }
        }
        updateSyncStatus()
    }

    func handleNetworkChange(isAvailable: Bool) {
        isOnline = isAvailable
        updateSyncStatus()
    }

    func handleRemoteChange() {
        lastSyncDate = Date()
        markRemoteChangeReceived()
        updateSyncStatus()
    }

    private func markRemoteChangeReceived() {
        hasReceivedRemoteChange = true
        changeCenter?.notify(.bulk)
    }

    private func updateSyncStatus() {
        if !isOnline {
            syncStatus = .offline
        } else if !isCloudAvailable {
            syncStatus = .unavailable
        } else if isSyncing {
            syncStatus = .syncing
        } else if let message = lastErrorMessage {
            syncStatus = .error(message)
        } else if let lastSyncDate {
            syncStatus = .synced(lastSyncDate)
        } else {
            syncStatus = .idle
        }
    }

    // MARK: - Manual sync

    public var manualSyncTimeout: Duration = .seconds(6)

    /// Saves pending changes (which schedules a CloudKit export) and waits for the event
    /// stream to settle so Settings can show a truthful "Last synced" time.
    public func triggerSync() async {
        guard isOnline else { syncStatus = .offline; return }
        guard isCloudAvailable else { syncStatus = .unavailable; return }
        guard let context = modelContext else { syncStatus = .error("Not configured"); return }
        do {
            if context.hasChanges { try context.save() }
            let deadline = ContinuousClock.now.advanced(by: manualSyncTimeout)
            try await Task.sleep(for: .milliseconds(300))
            while isSyncing, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(150))
            }
            if !isSyncing, lastErrorMessage == nil { lastSyncDate = Date() }
            updateSyncStatus()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    /// Waits for a remote change or timeout, whichever comes first.
    public func waitForRemoteChange(timeout: TimeInterval, pollInterval: Duration = .milliseconds(200)) async -> Bool {
        if hasReceivedRemoteChange { return true }
        guard isCloudAvailable, isOnline else { return false }
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while ContinuousClock.now < deadline {
            if hasReceivedRemoteChange { return true }
            do { try await Task.sleep(for: pollInterval) } catch { return hasReceivedRemoteChange }
        }
        return hasReceivedRemoteChange
    }

    public func resetRemoteChangeTracking() {
        hasReceivedRemoteChange = false
    }
}
