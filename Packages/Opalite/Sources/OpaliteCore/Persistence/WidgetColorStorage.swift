//
//  WidgetColorStorage.swift
//  OpaliteCore
//
//  The lightweight color snapshot the app writes into the App Group for the home-screen
//  widgets and the iMessage extension, and the kinds those widgets register under.
//

import Foundation

/// A color as the widgets see it: no SwiftData, no relationships.
nonisolated public struct WidgetColor: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String?
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(id: UUID, name: String?, red: Double, green: Double, blue: Double, alpha: Double) {
        self.id = id
        self.name = name
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var displayName: String { name ?? hexString }

    public var hexString: String { ColorMath.hexString(red: red, green: green, blue: blue) }

    /// Whether dark text reads better on this color than light text.
    public var prefersDarkText: Bool {
        ColorMath.relativeLuminance(red: red, green: green, blue: blue) > ColorMath.darkTextLuminanceThreshold
    }

    /// The placeholder shown when the user hasn't created any colors yet.
    public static let placeholder = WidgetColor(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "No Colors Yet", red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
}

/// Widget kinds shared between the app (which reloads them) and the extensions.
nonisolated public enum WidgetKind {
    public static let randomColor = "RandomColorWidget"
    public static let recentColorsWatch = "RecentColorsWidget"
}

/// Reads and writes the widget color snapshot in a key-value store (the App Group suite
/// in production, a fake in tests).
nonisolated public struct WidgetColorStorage: Sendable {
    public static let colorsKey = "widgetColors"

    private let defaults: (any KeyValueStoring)?

    public init(defaults: (any KeyValueStoring)? = AppGroup.defaults) {
        self.defaults = defaults
    }

    public func loadColors() -> [WidgetColor] {
        guard let data = defaults?.data(forKey: Self.colorsKey),
              let colors = try? JSONDecoder().decode([WidgetColor].self, from: data) else { return [] }
        return colors
    }

    public func saveColors(_ colors: [WidgetColor]) {
        guard let data = try? JSONEncoder().encode(colors) else { return }
        defaults?.set(data, forKey: Self.colorsKey)
    }

    /// A random stored color, or the placeholder when none exist.
    public func randomColor() -> WidgetColor {
        loadColors().randomElement() ?? .placeholder
    }
}
