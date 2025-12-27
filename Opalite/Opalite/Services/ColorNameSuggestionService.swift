//
//  ColorNameSuggestionService.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Service for generating creative color name suggestions using on-device AI.
///
/// Uses Apple's Foundation Models framework when available (iOS 26+, macOS 26+).
/// Falls back gracefully on unsupported devices.
@MainActor
@Observable
final class ColorNameSuggestionService {
    private(set) var suggestions: [String] = []
    private(set) var isGenerating: Bool = false
    private(set) var isAvailable: Bool = false
    private(set) var error: String?

    init() {
        checkAvailability()
    }

    private func checkAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            // Check if the device supports Foundation Models
            isAvailable = SystemLanguageModel.default.isAvailable
        } else {
            isAvailable = false
        }
        #else
        isAvailable = false
        #endif
    }

    /// Generates name suggestions for the given color.
    /// - Parameters:
    ///   - color: The OpaliteColor to generate names for
    ///   - count: Number of suggestions to generate (default: 5)
    func generateSuggestions(for color: OpaliteColor, count: Int = 5) async {
        guard isAvailable else {
            suggestions = []
            return
        }

        isGenerating = true
        error = nil
        suggestions = []

        defer { isGenerating = false }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            await generateWithFoundationModels(for: color, count: count)
        }
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func generateWithFoundationModels(for color: OpaliteColor, count: Int) async {
        do {
            let session = LanguageModelSession()

            let prompt = buildPrompt(for: color, count: count)

            let response = try await session.respond(to: prompt)

            // Parse the response - expecting comma-separated names
            let names = parseNames(from: response.content, count: count)
            suggestions = names
        } catch {
            self.error = error.localizedDescription
            suggestions = []
        }
    }
    #endif

    private func buildPrompt(for color: OpaliteColor, count: Int) -> String {
        let r = Int(color.red * 255)
        let g = Int(color.green * 255)
        let b = Int(color.blue * 255)

        // Calculate HSL for better color description
        let (h, s, l) = OpaliteColor.rgbToHSL(r: color.red, g: color.green, b: color.blue)
        let hueDegrees = Int(h * 360)
        let satPercent = Int(s * 100)
        let lightPercent = Int(l * 100)

        // Determine base color family
        let colorFamily = describeColorFamily(hue: hueDegrees, saturation: satPercent, lightness: lightPercent)

        return """
        Generate exactly \(count) creative, evocative names for this color:
        - RGB: (\(r), \(g), \(b))
        - Hex: \(color.hexString)
        - HSL: \(hueDegrees)°, \(satPercent)%, \(lightPercent)%
        - Color family: \(colorFamily)

        Requirements:
        - Each name should be 1-3 words
        - Names should be poetic, evocative, or reference nature/materials
        - Examples of good names: "Dusty Rose", "Ocean Mist", "Burnt Sienna", "Midnight Blue"
        - Do NOT include hex codes or technical descriptions
        - Return ONLY the names, separated by commas, nothing else
        """
    }

    private func describeColorFamily(hue: Int, saturation: Int, lightness: Int) -> String {
        // Handle achromatic colors
        if saturation < 10 {
            if lightness < 20 { return "black/very dark gray" }
            if lightness > 80 { return "white/very light gray" }
            return "gray"
        }

        // Determine hue family
        let hueFamily: String
        switch hue {
        case 0..<15, 345..<360: hueFamily = "red"
        case 15..<45: hueFamily = "orange"
        case 45..<75: hueFamily = "yellow"
        case 75..<150: hueFamily = "green"
        case 150..<195: hueFamily = "cyan"
        case 195..<255: hueFamily = "blue"
        case 255..<285: hueFamily = "purple"
        case 285..<345: hueFamily = "magenta/pink"
        default: hueFamily = "unknown"
        }

        // Add modifiers
        var modifiers: [String] = []
        if lightness < 30 { modifiers.append("dark") }
        else if lightness > 70 { modifiers.append("light") }

        if saturation < 40 { modifiers.append("muted") }
        else if saturation > 80 { modifiers.append("vibrant") }

        if modifiers.isEmpty {
            return hueFamily
        }
        return "\(modifiers.joined(separator: " ")) \(hueFamily)"
    }

    private func parseNames(from response: String, count: Int) -> [String] {
        // Split by comma and clean up
        let rawNames = response
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count <= 30 }
            .prefix(count)

        return Array(rawNames)
    }

    /// Clears the current suggestions.
    func clearSuggestions() {
        suggestions = []
        error = nil
    }
}
