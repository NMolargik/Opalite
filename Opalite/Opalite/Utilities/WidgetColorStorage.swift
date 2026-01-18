//
//  WidgetColorStorage.swift
//  Opalite
//
//  Created by Claude on 1/18/26.
//
//  Shared between the main app and widget extension.
//  Add this file to both targets in Xcode.
//

import SwiftUI

/// Lightweight color representation for widget storage
struct WidgetColor: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String?
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var displayName: String {
        name ?? hexString
    }

    var hexString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Returns black or white depending on which has better contrast
    var idealTextColor: Color {
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.5 ? .black : .white
    }
}

/// Manages color data shared between the main app and widgets via App Groups
struct WidgetColorStorage {
    static let appGroupIdentifier = "group.com.molargiksoftware.Opalite"
    static let colorsKey = "widgetColors"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Loads colors from shared storage
    static func loadColors() -> [WidgetColor] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: colorsKey),
              let colors = try? JSONDecoder().decode([WidgetColor].self, from: data) else {
            return []
        }
        return colors
    }

    /// Saves colors to shared storage (called from main app)
    static func saveColors(_ colors: [WidgetColor]) {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(colors) else {
            return
        }
        defaults.set(data, forKey: colorsKey)
    }

    /// Returns a random color, or a placeholder if none available
    static func randomColor() -> WidgetColor {
        let colors = loadColors()
        if let random = colors.randomElement() {
            return random
        }
        // Placeholder color when no colors exist
        return WidgetColor(
            id: UUID(),
            name: "No Colors Yet",
            red: 0.5,
            green: 0.5,
            blue: 0.5,
            alpha: 1.0
        )
    }
}
