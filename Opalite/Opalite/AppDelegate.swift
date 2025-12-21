//
//  AppDelegate.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

#if os(iOS)
/// Handles home screen quick actions
class AppDelegate: NSObject, UIApplicationDelegate {
    /// Pending quick action type to handle after launch
    static var pendingShortcutType: String?

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

