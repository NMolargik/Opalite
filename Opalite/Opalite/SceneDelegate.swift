//
//  SceneDelegate.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

#if os(iOS)
/// Handles quick actions when app is already running
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // Set pending type so SwiftUI can handle it
        AppDelegate.pendingShortcutType = shortcutItem.type
        completionHandler(true)
    }
}
#endif
