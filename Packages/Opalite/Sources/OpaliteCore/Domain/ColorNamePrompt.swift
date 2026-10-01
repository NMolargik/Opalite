//
//  ColorNamePrompt.swift
//  OpaliteCore
//
//  The pure half of Apple Intelligence color naming: the prompt and the response parser.
//  The FoundationModels session lives in OpaliteServices.
//

import Foundation

nonisolated public enum ColorNamePrompt {
    public static let defaultCount = 5
    public static let maxNameLength = 30

    public static func build(for color: RGBA, count: Int = defaultCount) -> String {
        let hsl = color.hsl
        return """
        Generate exactly \(count) creative, evocative names for this color:
        - RGB: (\(color.red.byte), \(color.green.byte), \(color.blue.byte))
        - Hex: \(color.hexString)
        - HSL: \(Int(hsl.hue))°, \(Int(hsl.saturation * 100))%, \(Int(hsl.lightness * 100))%
        - Color family: \(ColorClassifier.description(of: color))

        Requirements:
        - Each name should be 1-3 words
        - Names should be poetic, evocative, or reference nature/materials
        - Examples of good names: "Dusty Rose", "Ocean Mist", "Burnt Sienna", "Midnight Blue"
        - Do NOT include hex codes or technical descriptions
        - Return ONLY the names, separated by commas, nothing else
        """
    }

    /// Splits a comma/newline separated response into at most `count` clean names.
    public static func parse(_ response: String, count: Int = defaultCount) -> [String] {
        let names: [String] = response
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'•-1234567890. ")) }
            .filter { !$0.isEmpty && $0.count <= maxNameLength }
            .uniqued()
        return Array(names.prefix(count))
    }
}
