//
//  PhoneConnectivityManager.swift
//  OpaliteServices
//
//  The iPhone side of the watch relay: pushes the portfolio snapshot through the
//  application context, answers `requestSync`, and services `copyHex` /
//  `copyColorFile` by writing the pasteboard (or queuing a notification when the app is
//  in the background, since the pasteboard needs the foreground). Delegate callbacks are
//  `nonisolated` and extract Sendable values before hopping to the main actor.
//

#if os(iOS) && canImport(WatchConnectivity)
import Foundation
import Observation
import UIKit
import UserNotifications
import WatchConnectivity
import OpaliteCore
import os

@MainActor
@Observable
public final class PhoneConnectivityManager: NSObject, WatchPortfolioPushing {
    public private(set) var isReachable = false
    public private(set) var isPaired = false
    public private(set) var isWatchAppInstalled = false
    public private(set) var lastSyncDate: Date?
    public private(set) var lastSyncColorCount = 0
    public private(set) var lastSyncPaletteCount = 0

    @ObservationIgnored private var session: WCSession?
    @ObservationIgnored private var snapshotProvider: (@MainActor () -> WatchPortfolioSnapshot)?
    @ObservationIgnored private var pasteboard: (any Pasteboarding)?
    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private var lastPushedPayloadStamp: Double = 0

    public init(defaults: any KeyValueStoring = UserDefaults.standard) {
        self.defaults = defaults
        super.init()
        lastSyncDate = defaults.object(forKey: AppStorageKeys.lastWatchSyncTimestamp) as? Date
        lastSyncColorCount = defaults.integer(forKey: AppStorageKeys.lastWatchSyncColorCount)
        lastSyncPaletteCount = defaults.integer(forKey: AppStorageKeys.lastWatchSyncPaletteCount)
    }

    /// Wires the data sources. Call once from the composition root.
    public func configure(snapshotProvider: @escaping @MainActor () -> WatchPortfolioSnapshot, pasteboard: any Pasteboarding) {
        self.snapshotProvider = snapshotProvider
        self.pasteboard = pasteboard
    }

    /// Activates the session (no-op when unsupported, e.g. iPad without a watch).
    public func activate() {
        guard WCSession.isSupported(), session == nil else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
        refreshState()
    }

    private func refreshState() {
        guard let session else { return }
        isReachable = session.isReachable
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
    }

    // MARK: - Push

    public func push(_ snapshot: WatchPortfolioSnapshot) {
        guard let session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(snapshot.payload)
            trackSync(snapshot)
        } catch {
            Log.watch.error("updateApplicationContext failed: \(error.localizedDescription)")
        }
        if session.isReachable {
            session.sendMessage(snapshot.messagePayload, replyHandler: nil) { error in
                Log.watch.notice("Immediate watch update failed: \(error.localizedDescription)")
            }
        }
    }

    private func trackSync(_ snapshot: WatchPortfolioSnapshot) {
        lastSyncDate = Date()
        lastSyncColorCount = snapshot.colors.count
        lastSyncPaletteCount = snapshot.palettes.count
        defaults.set(lastSyncDate, forKey: AppStorageKeys.lastWatchSyncTimestamp)
        defaults.set(lastSyncColorCount, forKey: AppStorageKeys.lastWatchSyncColorCount)
        defaults.set(lastSyncPaletteCount, forKey: AppStorageKeys.lastWatchSyncPaletteCount)
    }

    // MARK: - Pending hex copy (background)

    /// The hex queued while the app was in the background, if any.
    public var pendingHexCopy: String? {
        get { defaults.string(forKey: AppStorageKeys.pendingWatchHexCopy) }
        set { defaults.set(newValue, forKey: AppStorageKeys.pendingWatchHexCopy) }
    }

    /// Copies a queued hex now that the app is active. Returns the hex copied, if any.
    @discardableResult
    public func processPendingHexCopy() -> String? {
        guard let hex = pendingHexCopy else { return nil }
        pendingHexCopy = nil
        pasteboard?.copy(string: hex)
        return hex
    }

    private func handleCopyHex(hex: String, colorName: String) -> WatchReply {
        if UIApplication.shared.applicationState == .active {
            pasteboard?.copy(string: hex)
            return .success(queued: false)
        }
        pendingHexCopy = hex
        Task { await postCopyNotification(hex: hex) }
        return .success(queued: true)
    }

    private func postCopyNotification(hex: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Color from Apple Watch")
        content.body = String(localized: "Tap to copy \(hex) to your clipboard")
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: "watchHexCopy", content: content, trigger: nil))
    }

    private func handleCopyColorFile(data: Data) -> WatchReply {
        pasteboard?.copy(data: data, type: OpaliteFileType.colorIdentifier, fallbackString: String(data: data, encoding: .utf8))
        return .success(queued: false)
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error { Log.watch.error("Activation error: \(error.localizedDescription)") }
        Task { @MainActor in self.refreshState() }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[WatchMessageKey.action] as? String == WatchAction.copyHex.rawValue,
              let hex = userInfo[WatchMessageKey.hex] as? String else { return }
        let name = userInfo[WatchMessageKey.colorName] as? String ?? ""
        Task { @MainActor in _ = self.handleCopyHex(hex: hex, colorName: name) }
    }

    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let reply = UncheckedSendableBox(value: replyHandler)
        guard let actionRaw = message[WatchMessageKey.action] as? String, let action = WatchAction(rawValue: actionRaw) else {
            replyHandler(WatchReply.failure("Unknown action").dictionary)
            return
        }
        let hex = message[WatchMessageKey.hex] as? String
        let name = message[WatchMessageKey.colorName] as? String ?? ""
        let data = message[WatchMessageKey.colorData] as? Data

        Task { @MainActor in
            switch action {
            case .requestSync:
                guard let snapshot = self.snapshotProvider?() else {
                    reply.value(WatchReply.failure("Portfolio unavailable").dictionary)
                    return
                }
                var payload = snapshot.payload
                payload[WatchMessageKey.success] = true
                reply.value(payload)
                self.trackSync(snapshot)
            case .copyHex:
                guard let hex else { reply.value(WatchReply.failure("No hex value provided").dictionary); return }
                reply.value(self.handleCopyHex(hex: hex, colorName: name).dictionary)
            case .copyColorFile:
                guard let data else { reply.value(WatchReply.failure("No color data provided").dictionary); return }
                reply.value(self.handleCopyColorFile(data: data).dictionary)
            case .syncData:
                reply.value(WatchReply.failure("Unexpected action").dictionary)
            }
        }
    }
}
#endif
