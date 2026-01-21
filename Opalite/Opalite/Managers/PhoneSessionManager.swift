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
/// Sends colors and palettes to the Watch and receives requests to copy hex codes.
@MainActor
@Observable
class PhoneSessionManager: NSObject {
    static let shared = PhoneSessionManager()

    private var session: WCSession?

    /// Reference to ColorManager for sending data to Watch
    weak var colorManager: ColorManager?

    /// Whether the Watch is currently reachable
    var isWatchReachable: Bool {
        session?.isReachable ?? false
    }

    /// Whether a paired Watch exists
    var isPaired: Bool {
        #if os(iOS)
        return session?.isPaired ?? false
        #else
        return false
        #endif
    }

    /// Whether the Watch app is installed
    var isWatchAppInstalled: Bool {
        #if os(iOS)
        return session?.isWatchAppInstalled ?? false
        #else
        return false
        #endif
    }

    /// Timestamp of the last successful sync to Watch
    var lastSyncToWatch: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastWatchSyncTimestamp") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastWatchSyncTimestamp")
        }
    }

    /// Number of colors in the last sync
    var lastSyncColorCount: Int {
        get { UserDefaults.standard.integer(forKey: "lastWatchSyncColorCount") }
        set { UserDefaults.standard.set(newValue, forKey: "lastWatchSyncColorCount") }
    }

    /// Number of palettes in the last sync
    var lastSyncPaletteCount: Int {
        get { UserDefaults.standard.integer(forKey: "lastWatchSyncPaletteCount") }
        set { UserDefaults.standard.set(newValue, forKey: "lastWatchSyncPaletteCount") }
    }

    /// Pending hex code to copy when app becomes active (pasteboard requires foreground)
    var pendingHexCopy: String? {
        get { UserDefaults.standard.string(forKey: "pendingWatchHexCopy") }
        set { UserDefaults.standard.set(newValue, forKey: "pendingWatchHexCopy") }
    }

    /// Processes any pending hex copy from Watch (call when app becomes active)
    /// Returns the hex that was copied, or nil if nothing was pending
    @discardableResult
    func processPendingHexCopy() -> String? {
        #if os(iOS)
        guard let hex = pendingHexCopy else { return nil }
        pendingHexCopy = nil

        UIPasteboard.general.string = hex
        #if DEBUG
        print("[PhoneSessionManager] Processed pending hex copy: \(hex)")
        #endif
        return hex
        #else
        return nil
        #endif
    }

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

    // MARK: - Sync to Watch

    /// Sends all colors and palettes to the Watch via application context.
    /// This data persists until the Watch receives it, even if the app is terminated.
    func syncToWatch() {
        #if os(iOS)
        guard let session = session, session.activationState == .activated else {
            #if DEBUG
            print("[PhoneSessionManager] Cannot sync: session not activated")
            #endif
            return
        }

        guard let colorManager = colorManager else {
            #if DEBUG
            print("[PhoneSessionManager] Cannot sync: colorManager not set")
            #endif
            return
        }

        // Serialize colors (only essential data for Watch)
        // Note: WatchConnectivity doesn't support NSNull, so we use empty string for nil values
        let colorsData: [[String: Any]] = colorManager.colors.map { color in
            [
                "id": color.id.uuidString,
                "name": color.name ?? "",
                "red": color.red,
                "green": color.green,
                "blue": color.blue,
                "alpha": color.alpha,
                "paletteId": color.palette?.id.uuidString ?? "",
                "createdAt": color.createdAt.timeIntervalSince1970,
                "updatedAt": color.updatedAt.timeIntervalSince1970
            ]
        }

        // Serialize palettes
        let palettesData: [[String: Any]] = colorManager.palettes.map { palette in
            [
                "id": palette.id.uuidString,
                "name": palette.name,
                "createdAt": palette.createdAt.timeIntervalSince1970,
                "updatedAt": palette.updatedAt.timeIntervalSince1970
            ]
        }

        let context: [String: Any] = [
            "colors": colorsData,
            "palettes": palettesData,
            "syncTimestamp": Date().timeIntervalSince1970
        ]

        do {
            try session.updateApplicationContext(context)
            // Track the sync
            lastSyncToWatch = Date()
            lastSyncColorCount = colorsData.count
            lastSyncPaletteCount = palettesData.count
            #if DEBUG
            print("[PhoneSessionManager] Synced \(colorsData.count) colors and \(palettesData.count) palettes to Watch")
            #endif
        } catch {
            #if DEBUG
            print("[PhoneSessionManager] Failed to update application context: \(error)")
            #endif
        }
        #endif
    }

    /// Sends data immediately if Watch is reachable (for real-time updates)
    func sendImmediateUpdate() {
        #if os(iOS)
        guard let session = session, session.isReachable else {
            // Fall back to application context for background delivery
            syncToWatch()
            return
        }

        guard let colorManager = colorManager else { return }

        let colorsData: [[String: Any]] = colorManager.colors.map { color in
            [
                "id": color.id.uuidString,
                "name": color.name ?? "",
                "red": color.red,
                "green": color.green,
                "blue": color.blue,
                "alpha": color.alpha,
                "paletteId": color.palette?.id.uuidString ?? "",
                "createdAt": color.createdAt.timeIntervalSince1970,
                "updatedAt": color.updatedAt.timeIntervalSince1970
            ]
        }

        let palettesData: [[String: Any]] = colorManager.palettes.map { palette in
            [
                "id": palette.id.uuidString,
                "name": palette.name,
                "createdAt": palette.createdAt.timeIntervalSince1970,
                "updatedAt": palette.updatedAt.timeIntervalSince1970
            ]
        }

        let message: [String: Any] = [
            "action": "syncData",
            "colors": colorsData,
            "palettes": palettesData,
            "syncTimestamp": Date().timeIntervalSince1970
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            #if DEBUG
            print("[PhoneSessionManager] Failed to send immediate update: \(error)")
            #endif
            // Fall back to application context
            Task { @MainActor in
                self.syncToWatch()
            }
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

        case "requestSync":
            handleRequestSync(replyHandler: replyHandler)

        default:
            replyHandler(["success": false, "error": "Unknown action: \(action)"])
        }
    }

    private nonisolated func handleRequestSync(replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            guard let colorManager = self.colorManager else {
                replyHandler(["success": false, "error": "ColorManager not available"])
                return
            }

            let colorsData: [[String: Any]] = colorManager.colors.map { color in
                [
                    "id": color.id.uuidString,
                    "name": color.name ?? "",
                    "red": color.red,
                    "green": color.green,
                    "blue": color.blue,
                    "alpha": color.alpha,
                    "paletteId": color.palette?.id.uuidString ?? "",
                    "createdAt": color.createdAt.timeIntervalSince1970,
                    "updatedAt": color.updatedAt.timeIntervalSince1970
                ]
            }

            let palettesData: [[String: Any]] = colorManager.palettes.map { palette in
                [
                    "id": palette.id.uuidString,
                    "name": palette.name,
                    "createdAt": palette.createdAt.timeIntervalSince1970,
                    "updatedAt": palette.updatedAt.timeIntervalSince1970
                ]
            }

            replyHandler([
                "success": true,
                "colors": colorsData,
                "palettes": palettesData,
                "syncTimestamp": Date().timeIntervalSince1970
            ])

            // Track the sync
            self.lastSyncToWatch = Date()
            self.lastSyncColorCount = colorsData.count
            self.lastSyncPaletteCount = palettesData.count

            #if DEBUG
            print("[PhoneSessionManager] Sent \(colorsData.count) colors and \(palettesData.count) palettes in response to sync request")
            #endif
        }
    }

    private nonisolated func handleCopyHex(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let hex = message["hex"] as? String else {
            replyHandler(["success": false, "error": "No hex value provided"])
            return
        }

        Task { @MainActor in
            let colorName = message["colorName"] as? String ?? "Unknown"

            // Check if app is in foreground - pasteboard requires foreground access
            let appState = UIApplication.shared.applicationState
            if appState == .active {
                UIPasteboard.general.string = hex
                #if DEBUG
                print("[PhoneSessionManager] Copied hex '\(hex)' for color '\(colorName)' to clipboard")
                #endif
                replyHandler(["success": true])
            } else {
                // App is in background, queue the copy for when app becomes active
                self.pendingHexCopy = hex
                #if DEBUG
                print("[PhoneSessionManager] Queued hex '\(hex)' for color '\(colorName)' - app in background")
                #endif
                // Still report success - the copy will complete when user opens the app
                replyHandler(["success": true, "queued": true])
            }
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
