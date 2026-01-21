//
//  WatchSessionManager.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import Foundation
import WatchConnectivity
import WatchKit

@MainActor
@Observable
class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    private var session: WCSession?

    var isReachable: Bool = false
    var lastCopySucceeded: Bool?
    var isSyncing: Bool = false
    var lastSyncTimestamp: Date?

    /// Callback when new data is received from iPhone
    var onDataReceived: (([WatchColor], [WatchPalette]) -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Request Sync from iPhone

    /// Requests a full sync from the iPhone
    func requestSync() {
        guard let session = session, session.isReachable else {
            #if DEBUG
            print("[WatchSessionManager] Cannot request sync: iPhone not reachable")
            #endif
            // Try to load from application context if available
            if let context = session?.receivedApplicationContext, !context.isEmpty {
                processReceivedData(context)
            }
            return
        }

        isSyncing = true

        let message: [String: Any] = ["action": "requestSync"]

        session.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                self?.processReceivedData(reply)
                self?.isSyncing = false
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.isSyncing = false
                #if DEBUG
                print("[WatchSessionManager] Sync request failed: \(error)")
                #endif
            }
        })
    }

    // MARK: - Process Received Data

    private func processReceivedData(_ data: [String: Any]) {
        var colors: [WatchColor] = []
        var palettes: [WatchPalette] = []

        if let colorsArray = data["colors"] as? [[String: Any]] {
            colors = colorsArray.compactMap { WatchColor(from: $0) }
        }

        if let palettesArray = data["palettes"] as? [[String: Any]] {
            palettes = palettesArray.compactMap { WatchPalette(from: $0) }
        }

        if let timestamp = data["syncTimestamp"] as? TimeInterval {
            lastSyncTimestamp = Date(timeIntervalSince1970: timestamp)
        }

        #if DEBUG
        print("[WatchSessionManager] Received \(colors.count) colors and \(palettes.count) palettes")
        #endif

        // Save to local storage
        saveToLocalStorage(colors: colors, palettes: palettes)

        // Notify listeners
        onDataReceived?(colors, palettes)
    }

    // MARK: - Local Storage

    private let colorsKey = "watchColors"
    private let palettesKey = "watchPalettes"
    private let lastSyncKey = "lastSyncTimestamp"

    private func saveToLocalStorage(colors: [WatchColor], palettes: [WatchPalette]) {
        let encoder = JSONEncoder()

        if let colorsData = try? encoder.encode(colors) {
            UserDefaults.standard.set(colorsData, forKey: colorsKey)
        }

        if let palettesData = try? encoder.encode(palettes) {
            UserDefaults.standard.set(palettesData, forKey: palettesKey)
        }

        if let timestamp = lastSyncTimestamp {
            UserDefaults.standard.set(timestamp.timeIntervalSince1970, forKey: lastSyncKey)
        }
    }

    func loadFromLocalStorage() -> (colors: [WatchColor], palettes: [WatchPalette]) {
        let decoder = JSONDecoder()
        var colors: [WatchColor] = []
        var palettes: [WatchPalette] = []

        if let colorsData = UserDefaults.standard.data(forKey: colorsKey),
           let decoded = try? decoder.decode([WatchColor].self, from: colorsData) {
            colors = decoded
        }

        if let palettesData = UserDefaults.standard.data(forKey: palettesKey),
           let decoded = try? decoder.decode([WatchPalette].self, from: palettesData) {
            palettes = decoded
        }

        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? TimeInterval {
            lastSyncTimestamp = Date(timeIntervalSince1970: timestamp)
        }

        return (colors, palettes)
    }

    // MARK: - Copy Hex to iPhone

    /// Sends a hex code to the iPhone to be copied to clipboard.
    func copyHexToiPhone(_ hex: String, colorName: String?) {
        guard let session = session, session.isReachable else {
            WKInterfaceDevice.current().play(.failure)
            lastCopySucceeded = false
            return
        }

        var message: [String: Any] = [
            "action": "copyHex",
            "hex": hex
        ]

        if let name = colorName {
            message["colorName"] = name
        }

        session.sendMessage(message, replyHandler: { [weak self] reply in
            Task { @MainActor in
                if let success = reply["success"] as? Bool, success {
                    self?.lastCopySucceeded = true
                    WKInterfaceDevice.current().play(.success)
                } else {
                    self?.lastCopySucceeded = false
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }, errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.lastCopySucceeded = false
                WKInterfaceDevice.current().play(.failure)
                #if DEBUG
                print("[WatchSessionManager] Error sending message: \(error)")
                #endif
            }
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable

            // Check for any pending application context
            if !session.receivedApplicationContext.isEmpty {
                self.processReceivedData(session.receivedApplicationContext)
            }
        }
        #if DEBUG
        if let error = error {
            print("[WatchSessionManager] Activation error: \(error)")
        } else {
            print("[WatchSessionManager] Activated with state: \(activationState.rawValue)")
        }
        #endif
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable

            // When iPhone becomes reachable, request a sync
            if session.isReachable {
                self.requestSync()
            }
        }
    }

    /// Called when iPhone sends new application context
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.processReceivedData(applicationContext)
        }
    }

    /// Called when iPhone sends a direct message
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        if action == "syncData" {
            Task { @MainActor in
                self.processReceivedData(message)
            }
        }
    }
}
