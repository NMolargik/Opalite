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

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    /// Sends a hex code to the iPhone to be copied to clipboard.
    func copyHexToiPhone(_ hex: String, colorName: String?) {
        guard let session = session, session.isReachable else {
            // iPhone not reachable, play failure haptic
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
        }
    }
}
