//
//  QuickActions.swift
//  Opalite
//
//  Home Screen quick actions (long-press the app icon / Dock menu on Mac). Static items
//  are declared in Info.plist with their `type` set to an `opalite://` URL, so they route
//  through the same DeepLink path as widgets, Siri, iMessage, and the menu bar.
//
//  UIKit delivers quick actions only through app/scene delegates, so this file bridges
//  them into SwiftUI via a small observable relay. The scene delegate also configures the
//  Catalyst title bar and positions the SwatchBar window.
//

import SwiftUI
import UIKit
import OpaliteComposition
import OpaliteCore
import os

/// Bridge between the UIKit delegate world and SwiftUI. The `shared` instance exists only
/// because UIKit instantiates the delegates itself — delegate plumbing, not architecture.
@MainActor
@Observable
final class QuickActionRelay {
    static let shared = QuickActionRelay()
    var url: URL?
    init() {}
}

final class QuickActionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Cold launch from a quick action: the item arrives before any SwiftUI view exists.
        if let item = options.shortcutItem, let url = URL(string: item.type) {
            QuickActionRelay.shared.url = url
        }
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = QuickActionSceneDelegate.self
        return config
    }

    // MARK: - Menu builder (Mac Catalyst)

    func application(_ application: UIApplication, buildMenusUsing builder: UIMenuBuilder) {
        guard builder.system == .main else { return }
        #if targetEnvironment(macCatalyst)
        builder.remove(menu: .openRecent)
        #endif
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    // Warm launch: the app is already running when the quick action is tapped.
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let url = URL(string: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        QuickActionRelay.shared.url = url
        completionHandler(true)
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        #if targetEnvironment(macCatalyst)
        guard let windowScene = scene as? UIWindowScene else { return }
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .visible
            titlebar.toolbarStyle = .unified
        }
        let isSwatchBar = connectionOptions.userActivities.contains { $0.targetContentIdentifier == SwatchBarScene.windowID }
        if isSwatchBar {
            positionSwatchBar(windowScene)
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    /// Docks the SwatchBar near the right edge of the screen.
    private func positionSwatchBar(_ windowScene: UIWindowScene) {
        let screen = windowScene.screen.bounds
        let width = SwatchBarScene.defaultSize.width
        let height = min(SwatchBarScene.defaultSize.height, screen.height - 100)
        let frame = CGRect(x: screen.width - width - 20, y: 50, width: width, height: height)
        windowScene.requestGeometryUpdate(.Mac(systemFrame: frame)) { error in
            Log.app.notice("SwatchBar window placement failed: \(error.localizedDescription)")
        }
    }
    #endif
}
