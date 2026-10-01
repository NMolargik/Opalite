//
//  HarmonyKind.swift
//  OpaliteFeaturePortfolio
//
//  The harmony families the color detail offers (over Core's `ColorHarmony`), the wheel
//  geometry for each, and the tint/shade/tone ladders with their chip labels. Pure values
//  so the counts and angles are host-tested.
//

import Foundation
import OpaliteCore

// MARK: - Harmonies

nonisolated public enum HarmonyKind: String, CaseIterable, Identifiable, Sendable {
    case complementary
    case analogous
    case triadic
    case splitComplementary
    case tetradic

    public var id: String { rawValue }

    /// Hue offsets (degrees) of the harmony colors from the base.
    public var hueOffsets: [Double] {
        switch self {
        case .complementary: [180]
        case .analogous: [-30, 30]
        case .triadic: [120, 240]
        case .splitComplementary: [150, 210]
        case .tetradic: [90, 180, 270]
        }
    }

    public var systemImage: String {
        switch self {
        case .complementary: "circle.lefthalf.filled"
        case .analogous: "circle.and.line.horizontal"
        case .triadic: "triangle"
        case .splitComplementary: "arrow.triangle.branch"
        case .tetradic: "square"
        }
    }

    public var title: String {
        switch self {
        case .complementary: String(localized: "Complementary")
        case .analogous: String(localized: "Analogous")
        case .triadic: String(localized: "Triadic")
        case .splitComplementary: String(localized: "Split")
        case .tetradic: String(localized: "Tetradic")
        }
    }

    public var summary: String {
        switch self {
        case .complementary: String(localized: "Opposite on the wheel. High contrast, lots of energy.")
        case .analogous: String(localized: "Neighbors on the wheel. Calm and cohesive.")
        case .triadic: String(localized: "Three evenly spaced hues. Vivid but balanced.")
        case .splitComplementary: String(localized: "The two neighbors of the complement. Contrast with less tension.")
        case .tetradic: String(localized: "Four evenly spaced hues. Rich; let one color lead.")
        }
    }

    /// The harmony colors for a base, alpha preserved.
    public func colors(for base: RGBA) -> [RGBA] {
        switch self {
        case .complementary: [ColorHarmony.complementary(of: base)]
        case .analogous: ColorHarmony.analogous(of: base)
        case .triadic: ColorHarmony.triadic(of: base)
        case .splitComplementary: ColorHarmony.splitComplementary(of: base)
        case .tetradic: ColorHarmony.tetradic(of: base)
        }
    }

    /// Wheel positions in degrees clockwise from 12 o'clock: the base first, then each
    /// harmony color.
    public func wheelAngles(baseHue: Double) -> [Double] {
        ([0] + hueOffsets).map { Self.normalized(baseHue + $0) }
    }

    /// The angles padded to four entries so the overlay shape stays animatable.
    public func paddedWheelAngles(baseHue: Double) -> [Double] {
        var angles = wheelAngles(baseHue: baseHue)
        while angles.count < 4 { angles.append(angles.last ?? 0) }
        return Array(angles.prefix(4))
    }

    /// Points on the wheel including the base.
    public var pointCount: Int { hueOffsets.count + 1 }

    static func normalized(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}

// MARK: - Tints, shades, tones

/// One chip in a ladder.
nonisolated public struct ToneStep: Identifiable, Hashable, Sendable {
    public let id: String
    public let rgba: RGBA
    public let label: String

    public init(id: String, rgba: RGBA, label: String) {
        self.id = id
        self.rgba = rgba
        self.label = label
    }
}

nonisolated public enum ToneLadder: String, CaseIterable, Identifiable, Sendable {
    case tints
    case shades
    case tones

    public static let defaultStepCount = 4

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tints: String(localized: "Tints")
        case .shades: String(localized: "Shades")
        case .tones: String(localized: "Tones")
        }
    }

    public var summary: String {
        switch self {
        case .tints: String(localized: "Mixed toward white")
        case .shades: String(localized: "Mixed toward black")
        case .tones: String(localized: "Mixed toward gray")
        }
    }

    public var systemImage: String {
        switch self {
        case .tints: "sun.max"
        case .shades: "moon.fill"
        case .tones: "circle.lefthalf.filled"
        }
    }

    /// Evenly spaced steps away from the base (never including it).
    public func steps(for base: RGBA, count: Int = ToneLadder.defaultStepCount) -> [ToneStep] {
        let values: [RGBA]
        switch self {
        case .tints: values = ColorHarmony.tints(of: base, count: count)
        case .shades: values = ColorHarmony.shades(of: base, count: count)
        case .tones: values = ColorHarmony.tones(of: base, count: count)
        }
        return values.enumerated().map { index, rgba in
            let percent = Int((Double(index + 1) / Double(count + 1) * 100).rounded())
            return ToneStep(id: "\(rawValue)-\(index)", rgba: rgba, label: label(percent: percent))
        }
    }

    private func label(percent: Int) -> String {
        switch self {
        case .tints: "+\(percent)%"
        case .shades: "−\(percent)%"
        case .tones: "\(percent)%"
        }
    }
}
