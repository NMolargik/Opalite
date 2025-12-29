//
//  PhoneSessionManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/29/25.
//

import Foundation
import WatchConnectivity
#if canImport(UIKit)
import UIKit
#endif

/// Handles WatchConnectivity messages from the Apple Watch companion app.
/// Receives requests to copy hex codes or color files to the iPhone clipboard.
@MainActor
@Observable
class PhoneSessionManager: NSObject {
    static let shared = PhoneSessionManager()

    private var session: WCSession?

    override init() {
        super.init()
        #if os(iOS)
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        #endif
    }
}

#if os(iOS)
// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if DEBUG
        if let error = error {
            print("[PhoneSessionManager] Activation error: \(error)")
        } else {
            print("[PhoneSessionManager] Activated with state: \(activationState.rawValue)")
        }
        #endif
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
        print("[PhoneSessionManager] Session became inactive")
        #endif
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        #if DEBUG
        print("[PhoneSessionManager] Session deactivated, reactivating...")
        #endif
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let action = message["action"] as? String else {
            replyHandler(["success": false, "error": "No action specified"])
            return
        }

        switch action {
        case "copyHex":
            handleCopyHex(message: message, replyHandler: replyHandler)

        case "copyColorFile":
            handleCopyColorFile(message: message, replyHandler: replyHandler)

        default:
            replyHandler(["success": false, "error": "Unknown action: \(action)"])
        }
    }

    private nonisolated func handleCopyHex(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let hex = message["hex"] as? String else {
            replyHandler(["success": false, "error": "No hex value provided"])
            return
        }

        Task { @MainActor in
            UIPasteboard.general.string = hex
            #if DEBUG
            let colorName = message["colorName"] as? String ?? "Unknown"
            print("[PhoneSessionManager] Copied hex '\(hex)' for color '\(colorName)' to clipboard")
            #endif
            replyHandler(["success": true])
        }
    }

    private nonisolated func handleCopyColorFile(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let colorData = message["colorData"] as? Data else {
            replyHandler(["success": false, "error": "No color data provided"])
            return
        }

        Task { @MainActor in
            // Set the color data with the opaliteColor UTType
            UIPasteboard.general.setData(colorData, forPasteboardType: "com.molargiksoftware.opalite.color")

            // Also set as plain text JSON for broader compatibility
            if let jsonString = String(data: colorData, encoding: .utf8) {
                UIPasteboard.general.string = jsonString
            }

            #if DEBUG
            let colorName = message["colorName"] as? String ?? "Unknown"
            print("[PhoneSessionManager] Copied color file for '\(colorName)' to clipboard")
            #endif
            replyHandler(["success": true])
        }
    }
}
#endif
