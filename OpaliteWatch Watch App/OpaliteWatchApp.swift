//
//  OpaliteWatchApp.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI

@main
struct OpaliteWatchApp: App {
    let colorManager = WatchColorManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .environment(colorManager)
    }
}
