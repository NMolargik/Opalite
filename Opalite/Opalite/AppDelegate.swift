//
//  AppDelegate.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI
import UIKit

#if os(iOS)
/// Handles home screen quick actions
class AppDelegate: NSObject, UIApplicationDelegate {
    /// Pending quick action type to handle after launch
    static var pendingShortcutType: String?

    /// Reference to the SwatchBar scene session for single-instance management
    static weak var swatchBarSceneSession: UISceneSession?

    /// Reference to the Main scene session for single-instance management
    static weak var mainSceneSession: UISceneSession?

    #if targetEnvironment(macCatalyst)
    /// Reference to the status menu controller from the AppKit bundle
    private var statusMenuController: NSObject?
    #endif

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if targetEnvironment(macCatalyst)
        setupStatusMenu()
        #endif
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let shortcutType = shortcutItem.type

        // Handle the action immediately - this is called when app is in background
        // and user triggers a shortcut (e.g., from macOS dock menu)
        Task { @MainActor in
            if shortcutType == "OpenSwatchBarAction" {
                AppDelegate.openSwatchBarWindow()
            } else if shortcutType == "CreateNewColorAction" {
                IntentNavigationManager.shared.showColorEditor()
            }
        }

        // Also set pending type as fallback for cold launch scenarios
        AppDelegate.pendingShortcutType = shortcutType
        completionHandler(true)
    }


    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check if launched via quick action (from options)
        if let shortcutItem = options.shortcutItem {
            AppDelegate.pendingShortcutType = shortcutItem.type
        }

        // Check if we should open SwatchBar (either from options or pending type set earlier)
        let shouldOpenSwatchBar = options.shortcutItem?.type == "OpenSwatchBarAction" ||
                                   AppDelegate.pendingShortcutType == "OpenSwatchBarAction"

        if shouldOpenSwatchBar {
            // Clear the pending type since we're handling it now
            AppDelegate.pendingShortcutType = nil
            let config = UISceneConfiguration(name: "SwatchBar", sessionRole: connectingSceneSession.role)
            config.delegateClass = SceneDelegate.self
            return config
        }

        // Check for SwatchBar scene request via user activity
        if let targetContentIdentifier = options.userActivities.first?.targetContentIdentifier,
           targetContentIdentifier == "swatchBar" {
            let config = UISceneConfiguration(name: "SwatchBar", sessionRole: connectingSceneSession.role)
            config.delegateClass = SceneDelegate.self
            return config
        }

        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    /// Opens the main Opalite window or brings an existing one to the foreground.
    ///
    /// This checks for an existing main scene and activates it.
    /// If no main window exists, it opens a new one.
    @MainActor
    static func openMainWindow() {
        // Check if we have a stored main scene session
        if let session = mainSceneSession {
            UIApplication.shared.requestSceneSessionActivation(
                session,
                userActivity: nil,
                options: nil,
                errorHandler: nil
            )
            return
        }

        // No existing main window, request a new scene
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: nil,
            options: nil,
            errorHandler: nil
        )
    }

    /// Opens the SwatchBar window or brings an existing one to the foreground.
    ///
    /// This checks for an existing SwatchBar scene and activates it.
    /// If no SwatchBar window exists, it opens a new one via user activity.
    @MainActor
    static func openSwatchBarWindow() {
        // If we have an existing SwatchBar session, activate it
        if let session = swatchBarSceneSession {
            UIApplication.shared.requestSceneSessionActivation(
                session,
                userActivity: nil,
                options: nil,
                errorHandler: nil
            )
            return
        }

        // Create a user activity that will trigger SwatchBar scene configuration
        let activity = NSUserActivity(activityType: "com.molargiksoftware.Opalite.openSwatchBar")
        activity.targetContentIdentifier = "swatchBar"

        // Request a new scene with this activity - configurationForConnecting will see it
        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: nil,
            errorHandler: { error in
                print("[Opalite] Failed to open SwatchBar: \(error.localizedDescription)")
            }
        )
    }

    /// Registers a scene session as the main window session.
    @MainActor
    static func registerMainSceneSession() {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { scene in
                // Find a scene that isn't the SwatchBar
                scene.session !== swatchBarSceneSession
            }) {
            mainSceneSession = windowScene.session
        }
    }

    /// Registers a scene session as the SwatchBar session.
    @MainActor
    static func registerSwatchBarSceneSession() {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { scene in
                // Find a scene that isn't the main window
                scene.session !== mainSceneSession
            }) {
            swatchBarSceneSession = windowScene.session
        }
    }

    // MARK: - Menu Builder (Mac Catalyst)
    func application(_ application: UIApplication, buildMenusUsing builder: UIMenuBuilder) {

        // Only modify the main menu bar
        guard builder.system == .main else { return }

        #if targetEnvironment(macCatalyst)
        // Remove "Open Recent" submenu from File menu
        builder.remove(menu: .openRecent)

        // Remove "New Window" from File menu to prevent opening duplicate main windows
        builder.remove(menu: .newScene)
        #endif
    }

    // MARK: - Status Menu (Mac Catalyst)

    #if targetEnvironment(macCatalyst)
    /// Sets up the macOS menu bar status item by loading the AppKit bundle
    private func setupStatusMenu() {
        // Find the bundle in the app's Resources directory
        guard let resourcesURL = Bundle.main.resourceURL else {
            return
        }

        let bundleURL = resourcesURL.appendingPathComponent("StatusMenuBundle.bundle")

        guard let bundle = Bundle(url: bundleURL), bundle.load() else {
            return
        }

        // Get the StatusMenuController class (try with and without module prefix)
        let controllerClass: NSObject.Type? =
            bundle.classNamed("StatusMenuBundle.StatusMenuController") as? NSObject.Type ??
            bundle.classNamed("StatusMenuController") as? NSObject.Type

        guard let controllerClass else {
            return
        }

        // Get the shared instance
        let sharedSelector = NSSelectorFromString("shared")
        guard controllerClass.responds(to: sharedSelector),
              let controller = controllerClass.perform(sharedSelector)?.takeUnretainedValue() as? NSObject else {
            return
        }

        // Setup with callback
        let setupSelector = NSSelectorFromString("setupWithOpenSwatchBarHandler:")
        if controller.responds(to: setupSelector) {
            let handler: @convention(block) () -> Void = {
                Task { @MainActor in
                    AppDelegate.openSwatchBarWindow()
                }
            }
            controller.perform(setupSelector, with: handler)
        }

        statusMenuController = controller
    }
    #endif
}
#endif
