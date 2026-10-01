//
//  Log.swift
//  OpaliteCore
//
//  One os.Logger per subsystem category. Never `print` — files calling `Log`
//  need their own `import os` (MemberImportVisibility).
//

import Foundation
import os

nonisolated public enum Log {
    private static let subsystem = "com.molargiksoftware.Opalite"

    public static let app = Logger(subsystem: subsystem, category: "App")
    public static let portfolio = Logger(subsystem: subsystem, category: "Portfolio")
    public static let canvas = Logger(subsystem: subsystem, category: "Canvas")
    public static let community = Logger(subsystem: subsystem, category: "Community")
    public static let sync = Logger(subsystem: subsystem, category: "CloudSync")
    public static let subscription = Logger(subsystem: subsystem, category: "Subscription")
    public static let watch = Logger(subsystem: subsystem, category: "Watch")
    public static let widgets = Logger(subsystem: subsystem, category: "Widgets")
    public static let spotlight = Logger(subsystem: subsystem, category: "Spotlight")
    public static let sharing = Logger(subsystem: subsystem, category: "Sharing")
    public static let intents = Logger(subsystem: subsystem, category: "Intents")
    public static let intelligence = Logger(subsystem: subsystem, category: "Intelligence")
}
