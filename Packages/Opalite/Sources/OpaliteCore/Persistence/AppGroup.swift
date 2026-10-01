//
//  AppGroup.swift
//  OpaliteCore
//
//  App Group and CloudKit constants shared by the app, widgets, watch, and extensions.
//  These are shipping identifiers — don't change them.
//

import Foundation

nonisolated public enum AppGroup {
    public static let id = "group.com.molargiksoftware.Opalite"
    public static let cloudKitContainerID = "iCloud.com.molargiksoftware.Opalite"
    public static let bundleID = "com.molargiksoftware.Opalite"

    /// The shared defaults suite, or nil when the entitlement is missing (e.g. host tests).
    public static var defaults: UserDefaults? { UserDefaults(suiteName: id) }

    /// The shared container directory, or nil without the entitlement.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}
