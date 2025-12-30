//
//  SceneDelegate.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI
import UIKit

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

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        #if targetEnvironment(macCatalyst)
        // Position SwatchBar window near the right edge of the screen
        guard let windowScene = scene as? UIWindowScene,
              session.configuration.name == "SwatchBar" else { return }

        positionSwatchBarWindow(windowScene)
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func positionSwatchBarWindow(_ windowScene: UIWindowScene) {
        // Get the screen bounds
        guard let screen = windowScene.screen as? UIScreen ?? UIScreen.main as UIScreen? else { return }
        let screenBounds = screen.bounds

        // SwatchBar dimensions (matches defaultSize in OpaliteApp)
        let swatchBarWidth: CGFloat = 250
        let swatchBarHeight: CGFloat = 1000

        // Position near the right edge with some padding
        let rightPadding: CGFloat = 20
        let topPadding: CGFloat = 50

        let xPosition = screenBounds.width - swatchBarWidth - rightPadding
        let yPosition = topPadding

        let targetFrame = CGRect(
            x: xPosition,
            y: yPosition,
            width: swatchBarWidth,
            height: min(swatchBarHeight, screenBounds.height - topPadding - 50)
        )

        let geometryPreferences = UIWindowScene.GeometryPreferences.Mac(systemFrame: targetFrame)
        windowScene.requestGeometryUpdate(geometryPreferences) { error in
            print("[Opalite] SwatchBar window positioning error: \(error.localizedDescription)")
        }
    }
    #endif
}
#endif

