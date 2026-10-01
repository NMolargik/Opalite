//
//  DeepLink.swift
//  OpaliteCore
//
//  Every way into the app funnels through one value: `opalite://` URLs (widgets, iMessage,
//  Handoff), Home Screen quick actions, App Intents, menu-bar commands, and the watch.
//  Parsing is pure so it's host-tested.
//

import Foundation

nonisolated public enum DeepLink: Equatable, Sendable, Hashable {
    case portfolio
    case community
    case search
    case canvases
    case settings
    case color(UUID)
    case palette(UUID)
    case canvas(UUID)
    case createColor
    case createPalette
    case samplePhoto
    case swatchBar
    case sharedImage
    case onyx

    public static let scheme = "opalite"

    /// Parses an `opalite://` URL. Supported forms:
    /// - `opalite://portfolio`, `community`, `search`, `canvases`, `settings`, `onyx`
    /// - `opalite://color/<uuid>`, `palette/<uuid>`, `canvas/<uuid>`
    /// - `opalite://createColor`, `createPalette`, `samplePhoto`, `swatchBar`, `sharedImage`
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, let host = url.host()?.lowercased() else { return nil }
        let idComponent = url.pathComponents.dropFirst().first
        switch host {
        case "portfolio": self = .portfolio
        case "community": self = .community
        case "search": self = .search
        case "canvases", "canvas" where idComponent == nil: self = .canvases
        case "settings": self = .settings
        case "onyx": self = .onyx
        case "createcolor", "create-color": self = .createColor
        case "createpalette", "create-palette": self = .createPalette
        case "samplephoto", "sample-photo": self = .samplePhoto
        case "swatchbar", "swatch-bar": self = .swatchBar
        case "sharedimage", "shared-image": self = .sharedImage
        case "color":
            guard let idComponent, let id = UUID(uuidString: idComponent) else { return nil }
            self = .color(id)
        case "palette":
            guard let idComponent, let id = UUID(uuidString: idComponent) else { return nil }
            self = .palette(id)
        case "canvas":
            guard let idComponent, let id = UUID(uuidString: idComponent) else { return nil }
            self = .canvas(id)
        default:
            return nil
        }
    }

    /// The canonical URL for this destination.
    public var url: URL {
        let path: String
        switch self {
        case .portfolio: path = "portfolio"
        case .community: path = "community"
        case .search: path = "search"
        case .canvases: path = "canvases"
        case .settings: path = "settings"
        case .onyx: path = "onyx"
        case .createColor: path = "createColor"
        case .createPalette: path = "createPalette"
        case .samplePhoto: path = "samplePhoto"
        case .swatchBar: path = "swatchBar"
        case .sharedImage: path = "sharedImage"
        case .color(let id): path = "color/\(id.uuidString)"
        case .palette(let id): path = "palette/\(id.uuidString)"
        case .canvas(let id): path = "canvas/\(id.uuidString)"
        }
        return URL(string: "\(Self.scheme)://\(path)")!
    }

    /// The tab this link lands on, or nil for links that don't change tabs.
    public var destinationTab: AppTab? {
        switch self {
        case .portfolio, .color, .palette, .createColor, .createPalette, .samplePhoto, .sharedImage: .portfolio
        case .community: .community
        case .search: .search
        case .canvases, .canvas: .canvas
        case .settings, .onyx: .settings
        case .swatchBar: nil
        }
    }
}

// MARK: - App Intent hand-off

extension DeepLink {
    /// App Group key used to hand a link from an `openAppWhenRun` intent to the app.
    public static let pendingDefaultsKey = "pendingDeepLinkURL"

    public func storePending(in defaults: (any KeyValueStoring)?) {
        defaults?.set(url.absoluteString, forKey: Self.pendingDefaultsKey)
    }

    public static func takePending(from defaults: (any KeyValueStoring)?) -> DeepLink? {
        guard let raw = defaults?.string(forKey: Self.pendingDefaultsKey), let url = URL(string: raw) else { return nil }
        defaults?.removeObject(forKey: Self.pendingDefaultsKey)
        return DeepLink(url: url)
    }
}

// MARK: - User activities

/// `NSUserActivity` types the app publishes for Handoff / Siri on-screen awareness.
nonisolated public enum UserActivityType {
    public static let viewingColor = "com.molargiksoftware.Opalite.viewingColor"
    public static let viewingPalette = "com.molargiksoftware.Opalite.viewingPalette"
    public static let swatchBar = "com.molargiksoftware.Opalite.swatchBar"
}
