//
//  WatchModels.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI

// MARK: - Watch Color

/// Lightweight color model for Apple Watch (no SwiftData dependency)
struct WatchColor: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String?
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    var paletteId: UUID?
    var createdAt: Date
    var updatedAt: Date

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - Color Space Conversions

    var hsl: (hue: Double, saturation: Double, lightness: Double) {
        let maxVal = max(red, max(green, blue))
        let minVal = min(red, min(green, blue))
        let delta = maxVal - minVal
        let lightness = (maxVal + minVal) / 2.0

        guard delta != 0 else {
            return (0, 0, lightness)
        }

        let saturation = lightness > 0.5
            ? delta / (2.0 - maxVal - minVal)
            : delta / (maxVal + minVal)

        var hue: Double
        if maxVal == red {
            hue = (green - blue) / delta + (green < blue ? 6 : 0)
        } else if maxVal == green {
            hue = (blue - red) / delta + 2
        } else {
            hue = (red - green) / delta + 4
        }
        hue *= 60

        return (hue, saturation, lightness)
    }

    var cmyk: (cyan: Double, magenta: Double, yellow: Double, key: Double) {
        let k = 1.0 - max(red, max(green, blue))
        guard k < 1.0 else {
            return (0, 0, 0, 1)
        }
        let c = (1.0 - red - k) / (1.0 - k)
        let m = (1.0 - green - k) / (1.0 - k)
        let y = (1.0 - blue - k) / (1.0 - k)
        return (c, m, y, k)
    }

    /// WCAG relative luminance
    var relativeLuminance: Double {
        func channel(_ c: Double) -> Double {
            return c <= 0.03928 ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// Returns black or white depending on which has better contrast
    func idealTextColor() -> Color {
        relativeLuminance > 0.179 ? .black : .white
    }

    // MARK: - Accessibility

    /// A spoken description for VoiceOver combining name and hex
    var voiceOverDescription: String {
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "\(name), \(hexString)"
        }
        return hexString
    }

    // MARK: - Init from Dictionary

    init?(from dict: [String: Any]) {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let red = dict["red"] as? Double,
              let green = dict["green"] as? Double,
              let blue = dict["blue"] as? Double else {
            return nil
        }

        self.id = id
        // Treat empty string as nil (WatchConnectivity doesn't support NSNull)
        if let nameStr = dict["name"] as? String, !nameStr.isEmpty {
            self.name = nameStr
        } else {
            self.name = nil
        }
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = dict["alpha"] as? Double ?? 1.0

        // Treat empty string as nil for paletteId
        if let paletteIdString = dict["paletteId"] as? String, !paletteIdString.isEmpty {
            self.paletteId = UUID(uuidString: paletteIdString)
        } else {
            self.paletteId = nil
        }

        if let createdTimestamp = dict["createdAt"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: createdTimestamp)
        } else {
            self.createdAt = Date()
        }

        if let updatedTimestamp = dict["updatedAt"] as? TimeInterval {
            self.updatedAt = Date(timeIntervalSince1970: updatedTimestamp)
        } else {
            self.updatedAt = Date()
        }
    }

    init(id: UUID = UUID(), name: String? = nil, red: Double, green: Double, blue: Double, alpha: Double = 1.0, paletteId: UUID? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
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
}

// MARK: - Watch Palette

/// Lightweight palette model for Apple Watch (no SwiftData dependency)
struct WatchPalette: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Init from Dictionary

    init?(from dict: [String: Any]) {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = dict["name"] as? String else {
            return nil
        }

        self.id = id
        self.name = name

        if let createdTimestamp = dict["createdAt"] as? TimeInterval {
            self.createdAt = Date(timeIntervalSince1970: createdTimestamp)
        } else {
            self.createdAt = Date()
        }

        if let updatedTimestamp = dict["updatedAt"] as? TimeInterval {
            self.updatedAt = Date(timeIntervalSince1970: updatedTimestamp)
        } else {
            self.updatedAt = Date()
        }
    }

    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Sample Data

extension WatchColor {
    static let sample = WatchColor(
        name: "Ocean Blue",
        red: 0.2,
        green: 0.5,
        blue: 0.8
    )

    static let samples: [WatchColor] = [
        WatchColor(name: "Ocean Blue", red: 0.2, green: 0.5, blue: 0.8),
        WatchColor(name: "Sunset Orange", red: 0.95, green: 0.45, blue: 0.3),
        WatchColor(name: "Forest Green", red: 0.2, green: 0.7, blue: 0.3),
        WatchColor(name: nil, red: 0.8, green: 0.2, blue: 0.6)
    ]
}

extension WatchPalette {
    static let sample = WatchPalette(name: "My Palette")
}
