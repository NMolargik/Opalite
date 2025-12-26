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

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        // Forward to SceneDelegate via static storage; this is called when app is running on older setups
        AppDelegate.pendingShortcutType = shortcutItem.type
        completionHandler(true)
    }

    func applicationDidFinishLaunching(_ application: UIApplication) {
        // Define dynamic quick actions at launch
        let createColorIcon = UIApplicationShortcutIcon(systemImageName: "paintpalette.fill")
        let createColor = UIApplicationShortcutItem(
            type: "CreateNewColorAction",
            localizedTitle: "Create New Color",
            localizedSubtitle: nil,
            icon: createColorIcon,
            userInfo: nil
        )

        let openSwatchIcon = UIApplicationShortcutIcon(systemImageName: "square.stack")
        let openSwatch = UIApplicationShortcutItem(
            type: "OpenSwatchBarAction",
            localizedTitle: "Open SwatchBar",
            localizedSubtitle: nil,
            icon: openSwatchIcon,
            userInfo: nil
        )

        application.shortcutItems = [createColor, openSwatch]
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check if launched via quick action
        if let shortcutItem = options.shortcutItem {
            AppDelegate.pendingShortcutType = shortcutItem.type
        }

        // Check for SwatchBar scene request
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

    /// Opens the SwatchBar window or brings an existing one to the foreground.
    ///
    /// This checks for an existing SwatchBar scene and activates it.
    /// If no SwatchBar window exists, it opens a new one via URL scheme.
    @MainActor
    static func openSwatchBarWindow() {
        // Check if SwatchBar scene already exists and bring it to front
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               scene.session.configuration.name == "SwatchBar" ||
               windowScene.windows.first?.rootViewController?.title == "SwatchBar" {
                // Activate the existing SwatchBar window
                UIApplication.shared.requestSceneSessionActivation(
                    scene.session,
                    userActivity: nil,
                    options: nil,
                    errorHandler: nil
                )
                return
            }
        }

        // Also check by activity identifier
        for scene in UIApplication.shared.connectedScenes {
            if let activity = scene.session.stateRestorationActivity,
               activity.targetContentIdentifier == "swatchBar" {
                UIApplication.shared.requestSceneSessionActivation(
                    scene.session,
                    userActivity: nil,
                    options: nil,
                    errorHandler: nil
                )
                return
            }
        }

        // No existing SwatchBar window, open a new one
        if let url = URL(string: "opalite://swatchBar") {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("Failed to open SwatchBar window via URL")
                }
            }
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
}
#endif

