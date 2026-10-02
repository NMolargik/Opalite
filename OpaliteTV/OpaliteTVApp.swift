//
//  OpaliteTVApp.swift
//  OpaliteTV
//
//  Thin tvOS shell over the composition root. The TV UI lives in OpaliteFeatureTV.
//

import SwiftData
import SwiftUI
import OpaliteComposition

@main
struct OpaliteTVApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let session = SessionController()

    var body: some Scene {
        WindowGroup {
            TVRootHost(session: session)
                .modelContainer(session.container)
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await session.becameActive() }
                }
        }
    }
}
