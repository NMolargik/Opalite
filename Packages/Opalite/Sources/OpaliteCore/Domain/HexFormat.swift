//
//  HexFormat.swift
//  OpaliteCore
//
//  The user's hex-copy preference ("#RRGGBB" vs "RRGGBB") as a pure policy over a
//  key-value store, shared by the app, the SwatchBar, the TV app, and the watch.
//

import Foundation

nonisolated public struct HexFormat: Sendable {
    public let includesPrefix: Bool

    public init(includesPrefix: Bool) { self.includesPrefix = includesPrefix }

    /// Reads the stored preference, defaulting to including the prefix.
    public static func stored(in defaults: any KeyValueStoring) -> HexFormat {
        if defaults.object(forKey: AppStorageKeys.includeHexPrefix) == nil {
            return HexFormat(includesPrefix: true)
        }
        return HexFormat(includesPrefix: defaults.bool(forKey: AppStorageKeys.includeHexPrefix))
    }

    public func save(to defaults: any KeyValueStoring) {
        defaults.set(includesPrefix, forKey: AppStorageKeys.includeHexPrefix)
        defaults.set(true, forKey: AppStorageKeys.hasSetHexPrefixDefault)
    }

    /// Formats a canonical "#RRGGBB" per the preference.
    public func format(_ hex: String) -> String {
        if includesPrefix {
            return hex.hasPrefix("#") ? hex : "#\(hex)"
        }
        return hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    }
}
