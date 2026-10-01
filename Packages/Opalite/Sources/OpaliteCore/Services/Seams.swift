//
//  Seams.swift
//  OpaliteCore
//
//  Protocol seams over system frameworks so everything above them is testable with
//  in-memory fakes. Production conformances live in OpaliteServices (or the app target
//  when the framework type can't live in a package).
//

import Foundation

// MARK: - Key-value storage

/// The slice of `UserDefaults` the app uses (standard defaults and the App Group suite).
nonisolated public protocol KeyValueStoring: AnyObject, Sendable {
    func bool(forKey defaultName: String) -> Bool
    func double(forKey defaultName: String) -> Double
    func integer(forKey defaultName: String) -> Int
    func string(forKey defaultName: String) -> String?
    func data(forKey defaultName: String) -> Data?
    /// The raw stored value, used to tell "never set" apart from `false`/`0`.
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: KeyValueStoring {}

// MARK: - Entitlements

/// Whether the user has Onyx. StoreKit impl in OpaliteServices; a constant in tests.
@MainActor
public protocol EntitlementProviding: AnyObject {
    var hasOnyx: Bool { get }
}

/// A fixed entitlement for previews and tests.
@MainActor
public final class FixedEntitlement: EntitlementProviding {
    public var hasOnyx: Bool
    public init(hasOnyx: Bool) { self.hasOnyx = hasOnyx }
}

// MARK: - Device

/// Describes the current device for authorship stamps ("iPhone 17 Pro").
nonisolated public protocol DeviceDescribing: Sendable {
    var deviceName: String { get }
}

nonisolated public struct GenericDevice: DeviceDescribing {
    public let deviceName: String
    public init(deviceName: String = "This Device") { self.deviceName = deviceName }
}

// MARK: - Widgets

@MainActor
public protocol WidgetTimelineReloading {
    func reloadTimelines(ofKind kind: String)
    func reloadAllTimelines()
}

// MARK: - Watch

/// Pushes the portfolio snapshot to the paired watch.
@MainActor
public protocol WatchPortfolioPushing: AnyObject {
    func push(_ snapshot: WatchPortfolioSnapshot)
}

// MARK: - Pasteboard

/// The system pasteboard (UIKit/AppKit impl in OpaliteServices, a fake in tests).
@MainActor
public protocol Pasteboarding: AnyObject {
    func copy(string: String)
    func copy(data: Data, type: String, fallbackString: String?)
}

// MARK: - Spotlight

/// Abstraction over Spotlight's semantic index. The concrete indexer lives in the app
/// target (it maps models to `AppEntity` types, which can't live in the package).
@MainActor
public protocol PortfolioIndexing {
    func reindex(colors: [OpaliteColor], palettes: [OpalitePalette])
}

// MARK: - Siri on-screen awareness

/// Tags a detail screen's `NSUserActivity` with the App Intents entity identifier so Siri
/// can resolve "this color" / "this palette" from what's on screen.
@MainActor
public protocol EntityActivityAnnotating {
    func annotateColor(_ activity: NSUserActivity, colorID: UUID)
    func annotatePalette(_ activity: NSUserActivity, paletteID: UUID)
}

// MARK: - App Intents donation

nonisolated public enum DonatableAction: Sendable, Equatable {
    case createColor
    case createPalette
    case copyHex
}

@MainActor
public protocol IntentDonating {
    func donate(_ action: DonatableAction)
}

// MARK: - Siri vocabulary

/// Asks App Shortcuts to re-read the entity queries after names change.
@MainActor
public protocol ShortcutVocabularyUpdating {
    func updateAppShortcutParameters()
}

// MARK: - App Store review

@MainActor
public protocol ReviewRequesting {
    func requestReview()
}

// MARK: - Apple Intelligence

/// The on-device naming surface (Foundation Models impl in OpaliteServices).
@MainActor
public protocol ColorNaming: AnyObject {
    var isAvailable: Bool { get }
    func suggestNames(for color: RGBA, count: Int) async throws -> [String]
}
