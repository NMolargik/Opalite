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

        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
#endif

