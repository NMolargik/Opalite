//
//  WatchTransfer.swift
//  OpaliteCore
//
//  The phone ↔ watch wire protocol: the message keys, the request/reply actions, and the
//  `WatchColor`/`WatchPalette` snapshot types with their dictionary codec. WatchConnectivity
//  rejects NSNull, so optional strings travel as "" and come back as nil. One definition,
//  linked by the phone relay, the watch app, and the watch widget.
//

import Foundation

// MARK: - Keys & actions

nonisolated public enum WatchMessageKey {
    public static let action = "action"
    public static let colors = "colors"
    public static let palettes = "palettes"
    public static let syncTimestamp = "syncTimestamp"
    public static let hex = "hex"
    public static let colorName = "colorName"
    public static let colorData = "colorData"
    public static let success = "success"
    public static let queued = "queued"
    public static let error = "error"
}

nonisolated public enum WatchAction: String, Sendable {
    /// Watch → phone: send the full portfolio back in the reply.
    case requestSync
    /// Phone → watch: a portfolio snapshot (also the application-context payload shape).
    case syncData
    /// Watch → phone: put this hex on the phone's pasteboard.
    case copyHex
    /// Watch → phone: put this `.opalitecolor` JSON on the phone's pasteboard.
    case copyColorFile
}

/// The phone's answer to a watch request.
nonisolated public enum WatchReply: Sendable, Equatable {
    case success(queued: Bool)
    case failure(String)

    public var dictionary: [String: Any] {
        switch self {
        case .success(let queued):
            var dict: [String: Any] = [WatchMessageKey.success: true]
            if queued { dict[WatchMessageKey.queued] = true }
            return dict
        case .failure(let message):
            return [WatchMessageKey.success: false, WatchMessageKey.error: message]
        }
    }

    public init(dictionary: [String: Any]) {
        if dictionary[WatchMessageKey.success] as? Bool == true {
            self = .success(queued: dictionary[WatchMessageKey.queued] as? Bool ?? false)
        } else {
            self = .failure(dictionary[WatchMessageKey.error] as? String ?? "Unknown error")
        }
    }
}

// MARK: - Snapshot types

nonisolated public struct WatchColor: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String?
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double
    public var paletteId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String? = nil, red: Double, green: Double, blue: Double, alpha: Double = 1.0, paletteId: UUID? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.paletteId = paletteId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var rgba: RGBA { RGBA(red: red, green: green, blue: blue, alpha: alpha) }
    public var hexString: String { rgba.hexString }
    public var displayName: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return hexString
    }
    public var prefersDarkText: Bool { rgba.prefersDarkText }

    /// "Ocean Blue, #3380CC" for VoiceOver.
    public var voiceOverDescription: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return "\(name), \(hexString)" }
        return hexString
    }

    // MARK: Dictionary codec

    public init?(dictionary dict: [String: Any]) {
        guard let idString = dict["id"] as? String, let id = UUID(uuidString: idString),
              let red = dict["red"] as? Double, let green = dict["green"] as? Double, let blue = dict["blue"] as? Double else { return nil }
        self.id = id
        self.name = (dict["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = dict["alpha"] as? Double ?? 1
        self.paletteId = (dict["paletteId"] as? String).flatMap { $0.isEmpty ? nil : UUID(uuidString: $0) }
        self.createdAt = (dict["createdAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        self.updatedAt = (dict["updatedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
    }

    public var dictionary: [String: Any] {
        [
            "id": id.uuidString,
            "name": name ?? "",
            "red": red,
            "green": green,
            "blue": blue,
            "alpha": alpha,
            "paletteId": paletteId?.uuidString ?? "",
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970,
        ]
    }

    public static let sample = WatchColor(name: "Ocean Blue", red: 0.2, green: 0.5, blue: 0.8)
    public static let samples: [WatchColor] = [
        WatchColor(name: "Ocean Blue", red: 0.2, green: 0.5, blue: 0.8),
        WatchColor(name: "Sunset Orange", red: 0.95, green: 0.45, blue: 0.3),
        WatchColor(name: "Forest Green", red: 0.2, green: 0.7, blue: 0.3),
        WatchColor(name: nil, red: 0.8, green: 0.2, blue: 0.6),
    ]
}

nonisolated public struct WatchPalette: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init?(dictionary dict: [String: Any]) {
        guard let idString = dict["id"] as? String, let id = UUID(uuidString: idString), let name = dict["name"] as? String else { return nil }
        self.id = id
        self.name = name
        self.createdAt = (dict["createdAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        self.updatedAt = (dict["updatedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
    }

    public var dictionary: [String: Any] {
        ["id": id.uuidString, "name": name, "createdAt": createdAt.timeIntervalSince1970, "updatedAt": updatedAt.timeIntervalSince1970]
    }

    public static let sample = WatchPalette(name: "My Palette")
}

/// Everything the watch mirrors, as one value.
nonisolated public struct WatchPortfolioSnapshot: Sendable, Equatable {
    public var colors: [WatchColor]
    public var palettes: [WatchPalette]
    public var timestamp: Date

    public init(colors: [WatchColor], palettes: [WatchPalette], timestamp: Date = Date()) {
        self.colors = colors
        self.palettes = palettes
        self.timestamp = timestamp
    }

    public static let empty = WatchPortfolioSnapshot(colors: [] as [WatchColor], palettes: [] as [WatchPalette], timestamp: .distantPast)

    /// The application-context / reply payload.
    public var payload: [String: Any] {
        [
            WatchMessageKey.colors: colors.map(\.dictionary),
            WatchMessageKey.palettes: palettes.map(\.dictionary),
            WatchMessageKey.syncTimestamp: timestamp.timeIntervalSince1970,
        ]
    }

    /// The direct-message payload (adds the action).
    public var messagePayload: [String: Any] {
        var dict = payload
        dict[WatchMessageKey.action] = WatchAction.syncData.rawValue
        return dict
    }

    public init?(payload: [String: Any]) {
        guard payload[WatchMessageKey.colors] != nil || payload[WatchMessageKey.palettes] != nil else { return nil }
        colors = (payload[WatchMessageKey.colors] as? [[String: Any]] ?? []).compactMap(WatchColor.init(dictionary:))
        palettes = (payload[WatchMessageKey.palettes] as? [[String: Any]] ?? []).compactMap(WatchPalette.init(dictionary:))
        timestamp = (payload[WatchMessageKey.syncTimestamp] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
    }

    /// Builds the snapshot from the portfolio models.
    @MainActor
    public init(models colors: [OpaliteColor], palettes: [OpalitePalette], timestamp: Date = Date()) {
        self.colors = colors.map { color in
            WatchColor(id: color.id, name: color.name, red: color.red, green: color.green, blue: color.blue, alpha: color.alpha, paletteId: color.palette?.id, createdAt: color.createdAt, updatedAt: color.updatedAt)
        }
        self.palettes = palettes.map { WatchPalette(id: $0.id, name: $0.name, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        self.timestamp = timestamp
    }

    /// Colors not in any palette.
    public var looseColors: [WatchColor] { colors.filter { $0.paletteId == nil } }

    public func colors(in palette: WatchPalette) -> [WatchColor] {
        colors.filter { $0.paletteId == palette.id }.sorted { $0.createdAt > $1.createdAt }
    }
}

// MARK: - Watch local cache

/// Persists the last snapshot on the watch so the app renders instantly when the phone is away.
nonisolated public struct WatchSnapshotCache: Sendable {
    public static let colorsKey = "watchColors"
    public static let palettesKey = "watchPalettes"
    public static let lastSyncKey = "lastSyncTimestamp"
    /// Widget-facing copy (watch widgets read it from the shared suite).
    public static let widgetColorsKey = "watchWidgetColors"

    private let defaults: any KeyValueStoring

    public init(defaults: any KeyValueStoring) { self.defaults = defaults }

    public func save(_ snapshot: WatchPortfolioSnapshot) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(snapshot.colors) { defaults.set(data, forKey: Self.colorsKey) }
        if let data = try? encoder.encode(snapshot.palettes) { defaults.set(data, forKey: Self.palettesKey) }
        defaults.set(snapshot.timestamp.timeIntervalSince1970, forKey: Self.lastSyncKey)
    }

    public func load() -> WatchPortfolioSnapshot? {
        let decoder = JSONDecoder()
        let colors = defaults.data(forKey: Self.colorsKey).flatMap { try? decoder.decode([WatchColor].self, from: $0) } ?? []
        let palettes = defaults.data(forKey: Self.palettesKey).flatMap { try? decoder.decode([WatchPalette].self, from: $0) } ?? []
        guard !colors.isEmpty || !palettes.isEmpty else { return nil }
        let timestamp = (defaults.object(forKey: Self.lastSyncKey) as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        return WatchPortfolioSnapshot(colors: colors, palettes: palettes, timestamp: timestamp)
    }
}

// MARK: - Watch widget store

/// The recent-colors snapshot the watch app writes for its complication/widget.
nonisolated public struct WatchWidgetStore: Sendable {
    public static let colorsKey = "watchWidgetColors"
    private let defaults: (any KeyValueStoring)?

    public init(defaults: (any KeyValueStoring)? = AppGroup.watchDefaults) { self.defaults = defaults }

    public func save(_ colors: [WatchColor]) {
        guard let data = try? JSONEncoder().encode(colors) else { return }
        defaults?.set(data, forKey: Self.colorsKey)
    }

    /// The most recently created colors, newest first.
    public func recentColors(limit: Int = 3) -> [WatchColor] {
        guard let data = defaults?.data(forKey: Self.colorsKey),
              let colors = try? JSONDecoder().decode([WatchColor].self, from: data) else { return [] }
        return Array(colors.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }
}
