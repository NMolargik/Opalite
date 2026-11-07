//
//  EyedropperPreferences.swift
//  OpaliteCore
//
//  The Mac eyedropper's settings as pure values: the global hotkey presets (Carbon key codes
//  and modifier masks, so Services can register them without a third-party package), the
//  format a pick is auto-copied in, and the stored-preference readers.
//

import Foundation

/// A global shortcut that starts a screen pick from any app.
nonisolated public enum EyedropperHotkey: String, CaseIterable, Identifiable, Sendable {
    case controlOptionC
    case controlOptionP
    case controlOptionE
    case controlOptionCommandC
    case controlShiftC
    case off

    public static let `default`: EyedropperHotkey = .controlOptionC

    public var id: String { rawValue }

    /// Carbon virtual key code (ANSI layout); nil when off.
    public var keyCode: UInt32? {
        switch self {
        case .controlOptionC, .controlOptionCommandC, .controlShiftC: 8
        case .controlOptionP: 35
        case .controlOptionE: 14
        case .off: nil
        }
    }

    /// Carbon modifier mask (cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096).
    public var carbonModifiers: UInt32 {
        switch self {
        case .controlOptionC, .controlOptionP, .controlOptionE: 4096 | 2048
        case .controlOptionCommandC: 4096 | 2048 | 256
        case .controlShiftC: 4096 | 512
        case .off: 0
        }
    }

    /// "⌃⌥C"-style glyphs.
    public var symbols: String {
        switch self {
        case .controlOptionC: "⌃⌥C"
        case .controlOptionP: "⌃⌥P"
        case .controlOptionE: "⌃⌥E"
        case .controlOptionCommandC: "⌃⌥⌘C"
        case .controlShiftC: "⌃⇧C"
        case .off: ""
        }
    }

    public static func stored(in defaults: any KeyValueStoring) -> EyedropperHotkey {
        defaults.string(forKey: AppStorageKeys.eyedropperHotkey).flatMap(EyedropperHotkey.init(rawValue:)) ?? .default
    }
}

/// The text a pick is auto-copied as.
nonisolated public enum EyedropperCopyFormat: String, CaseIterable, Identifiable, Sendable {
    case hex
    case rgb
    case hsl
    case oklch
    case displayP3

    public var id: String { rawValue }

    /// Renders `color`; hex honors the user's "#" preference through `hexFormat`.
    public func string(for color: RGBA, hexFormat: HexFormat) -> String {
        switch self {
        case .hex: hexFormat.format(color.hexString)
        case .rgb: color.rgbString
        case .hsl: color.hslString
        case .oklch: color.oklchString
        case .displayP3: color.displayP3String
        }
    }

    public static func stored(in defaults: any KeyValueStoring) -> EyedropperCopyFormat {
        defaults.string(forKey: AppStorageKeys.eyedropperCopyFormat).flatMap(EyedropperCopyFormat.init(rawValue:)) ?? .hex
    }
}

nonisolated public enum EyedropperPreferences {
    /// Whether a pick is copied to the pasteboard automatically (default on).
    public static func autoCopies(in defaults: any KeyValueStoring) -> Bool {
        defaults.object(forKey: AppStorageKeys.eyedropperAutoCopy) == nil ? true : defaults.bool(forKey: AppStorageKeys.eyedropperAutoCopy)
    }

    /// Whether a hotkey pick leaves the SwatchBar closed instead of opening it (default off).
    public static func keepsSwatchBarHidden(in defaults: any KeyValueStoring) -> Bool {
        defaults.bool(forKey: AppStorageKeys.eyedropperKeepSwatchBarHidden)
    }
}
