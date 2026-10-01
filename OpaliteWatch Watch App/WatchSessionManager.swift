//
//  WatchSessionManager.swift
//  OpaliteWatch Watch App
//
//  The watch side of the relay over the Core wire types: receives portfolio snapshots
//  (application context or direct message), asks the phone to copy a hex, and caches the
//  last snapshot so the app renders instantly while the phone is away.
//

import Foundation
import Observation
import WatchConnectivity
import WatchKit
import WidgetKit
import OpaliteCore
import os

enum HexCopyResult: Equatable {
    case copiedImmediately
    case queued
    case failed
}

@MainActor
@Observable
final class WatchSessionManager: NSObject {
    private(set) var isReachable = false
    private(set) var isSyncing = false
    private(set) var snapshot: WatchPortfolioSnapshot
    var lastCopyResult: HexCopyResult?

    @ObservationIgnored private var session: WCSession?
    @ObservationIgnored private let cache = WatchSnapshotCache(defaults: UserDefaults.standard)
    @ObservationIgnored private let widgetStore = WatchWidgetStore()

    override init() {
        snapshot = .empty
        super.init()
        if let cached = cache.load() { snapshot = cached }
    }

    func activate() {
        guard WCSession.isSupported(), session == nil else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    var hasCachedData: Bool { !snapshot.colors.isEmpty || !snapshot.palettes.isEmpty }
    var lastSyncDate: Date? { snapshot.timestamp == .distantPast ? nil : snapshot.timestamp }

    // MARK: - Sync

    /// Asks the phone for the full portfolio; falls back to the last application context.
    func requestSync() {
        guard let session, session.isReachable else {
            if let context = session?.receivedApplicationContext, let received = WatchPortfolioSnapshot(payload: context) {
                apply(received)
            }
            return
        }
        isSyncing = true
        session.sendMessage([WatchMessageKey.action: WatchAction.requestSync.rawValue], replyHandler: { reply in
            let received = WatchPortfolioSnapshot(payload: reply)
            Task { @MainActor in
                if let received { self.apply(received) }
                self.isSyncing = false
            }
        }, errorHandler: { error in
            Log.watch.error("Sync request failed: \(error.localizedDescription)")
            Task { @MainActor in self.isSyncing = false }
        })
    }

    /// Requests a sync and waits briefly for the reply. Returns whether data arrived.
    @discardableResult
    func refresh(timeout: Duration = .seconds(2)) async -> Bool {
        let before = snapshot.timestamp
        requestSync()
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline, snapshot.timestamp == before {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return snapshot.timestamp != before
    }

    private func apply(_ received: WatchPortfolioSnapshot) {
        snapshot = received
        cache.save(received)
        widgetStore.save(received.colors)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Copy hex on the phone

    func copyHexToPhone(_ hex: String, colorName: String?) {
        guard let session else {
            lastCopyResult = .failed
            WKInterfaceDevice.current().play(.failure)
            return
        }
        let payload: [String: Any] = [
            WatchMessageKey.action: WatchAction.copyHex.rawValue,
            WatchMessageKey.hex: hex,
            WatchMessageKey.colorName: colorName ?? "",
        ]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { reply in
                let result = WatchReply(dictionary: reply)
                Task { @MainActor in self.finishCopy(result) }
            }, errorHandler: { _ in
                Task { @MainActor in self.queueCopy(payload) }
            })
        } else {
            queueCopy(payload)
        }
    }

    private func finishCopy(_ reply: WatchReply) {
        switch reply {
        case .success(let queued):
            lastCopyResult = queued ? .queued : .copiedImmediately
            WKInterfaceDevice.current().play(queued ? .start : .success)
        case .failure:
            lastCopyResult = .failed
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func queueCopy(_ payload: [String: Any]) {
        guard let session else { return }
        for transfer in session.outstandingUserInfoTransfers where transfer.userInfo[WatchMessageKey.action] as? String == WatchAction.copyHex.rawValue {
            transfer.cancel()
        }
        session.transferUserInfo(payload)
        lastCopyResult = .queued
        WKInterfaceDevice.current().play(.start)
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error { Log.watch.error("Activation error: \(error.localizedDescription)") }
        let reachable = session.isReachable
        let received = WatchPortfolioSnapshot(payload: session.receivedApplicationContext)
        Task { @MainActor in
            self.isReachable = reachable
            if let received { self.apply(received) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if reachable { self.requestSync() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let received = WatchPortfolioSnapshot(payload: applicationContext)
        Task { @MainActor in if let received { self.apply(received) } }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message[WatchMessageKey.action] as? String == WatchAction.syncData.rawValue else { return }
        let received = WatchPortfolioSnapshot(payload: message)
        Task { @MainActor in if let received { self.apply(received) } }
    }
}
