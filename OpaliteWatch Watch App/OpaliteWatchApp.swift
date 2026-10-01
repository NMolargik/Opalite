//
//  OpaliteWatchApp.swift
//  OpaliteWatch Watch App
//

import SwiftUI

@main
struct OpaliteWatchApp: App {
    @State private var colorManager = WatchColorManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(colorManager)
                .task { colorManager.start() }
        }
    }
}
