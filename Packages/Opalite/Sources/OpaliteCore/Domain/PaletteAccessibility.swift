//
//  PaletteAccessibility.swift
//  OpaliteCore
//
//  Whole-palette accessibility math, all pure and deterministic:
//   - `ContrastMatrix`: WCAG ratio, WCAG pass levels and APCA Lc for every ordered pair.
//   - `LightnessScale`: an 11-step (50...950) scale with even OKLCH lightness steps.
//   - `ColorVisionAnalysis`: which pairs collapse under protanopia, deuteranopia and
//     tritanopia, measured as OKLab distance after simulation.
//

import Foundation

// MARK: - Contrast matrix

/// Every ordered color pair of a palette. The row color is the text, the column color the
/// background; WCAG is symmetric, APCA is not.
nonisolated public struct ContrastMatrix: Equatable, Sendable {
    /// How a ratio fares for one text size.
    public enum TextLevel: Int, Comparable, Sendable {
        case fail = 0
        case aa
        case aaa

        public static func < (lhs: TextLevel, rhs: TextLevel) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Normal text: AA at 4.5:1, AAA at 7:1.
        public init(normalRatio ratio: Double) {
            self = ratio >= 7.0 ? .aaa : (ratio >= 4.5 ? .aa : .fail)
        }

        /// Large text: AA at 3:1, AAA at 4.5:1.
        public init(largeRatio ratio: Double) {
            self = ratio >= 4.5 ? .aaa : (ratio >= 3.0 ? .aa : .fail)
        }
    }

    public struct Cell: Equatable, Sendable {
        /// Index of the text color.
        public let row: Int
        /// Index of the background color.
        public let column: Int
        public let ratio: Double
        /// APCA Lc of the row color as text on the column color (signed).
        public let lc: Double

        public var normalLevel: TextLevel { TextLevel(normalRatio: ratio) }
        public var largeLevel: TextLevel { TextLevel(largeRatio: ratio) }
        public var apcaBand: APCA.Band { APCA.Band(lc: lc) }
        public var ratioText: String { WCAGConformance(ratio: ratio).ratioText }
    }

    public let colors: [RGBA]

    public init(colors: [RGBA]) {
        self.colors = colors
    }

    public var count: Int { colors.count }

    /// The cell with `row` as text on `column`; nil on the diagonal or out of range.
    public func cell(row: Int, column: Int) -> Cell? {
        guard row != column, colors.indices.contains(row), colors.indices.contains(column) else { return nil }
        let text = colors[row], background = colors[column]
        return Cell(
            row: row,
            column: column,
            ratio: text.contrastRatio(against: background),
            lc: APCA.contrast(text: text, background: background)
        )
    }

    /// Every off-diagonal cell, row by row.
    public var cells: [Cell] {
        colors.indices.flatMap { row in colors.indices.compactMap { cell(row: row, column: $0) } }
    }

    /// Unordered pairs (row < column) that pass AA for normal text (WCAG is symmetric).
    public var passingPairCount: Int {
        pairs.filter { $0.normalLevel >= .aa }.count
    }

    public var pairCount: Int { count * (count - 1) / 2 }

    /// One cell per unordered pair, with the lower index as the row.
    public var pairs: [Cell] {
        colors.indices.flatMap { row in
            ((row + 1)..<max(row + 1, colors.count)).compactMap { cell(row: row, column: $0) }
        }
    }
}

// MARK: - Lightness scale

/// An 11-step scale (50, 100, 200 ... 900, 950) that keeps the base color's OKLCH hue and
/// chroma and walks lightness in even steps, gamut-mapped to sRGB by reducing chroma.
nonisolated public enum LightnessScale {
    public static let stops: [Int] = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]
    /// OKLCH lightness of the 50 stop and of the 950 stop; the nine between are spaced evenly.
    public static let lightestLightness = 0.97
    public static let darkestLightness = 0.17

    public struct Step: Equatable, Sendable, Identifiable {
        public let stop: Int
        /// The OKLCH lightness this step targets.
        public let lightness: Double
        /// The base chroma and hue at that lightness, before gamut mapping.
        public let target: OKLCH
        /// The step as an sRGB color (chroma reduced to fit; lightness and hue kept).
        public let srgb: RGBA
        /// Set only where the display-p3 color differs from the sRGB one, i.e. the target
        /// chroma is outside sRGB but (at least partly) inside Display P3.
        public let displayP3: DisplayP3?

        public var id: Int { stop }
        /// True when sRGB had to reduce the target chroma.
        public var isChromaReduced: Bool { !target.isInSRGBGamut }
    }

    /// Target lightness for step `index` (0 = 50 ... 10 = 950).
    public static func lightness(at index: Int) -> Double {
        let span = Double(stops.count - 1)
        return lightestLightness + (darkestLightness - lightestLightness) * Double(index) / span
    }

    public static func generate(from base: RGBA) -> [Step] {
        let lch = base.oklch
        // Near-neutral colors keep a neutral scale; their hue is meaningless.
        let chroma = lch.chroma < 0.004 ? 0 : lch.chroma
        return stops.enumerated().map { index, stop in
            let level = lightness(at: index)
            let target = OKLCH(lightness: level, chroma: chroma, hue: chroma == 0 ? 0 : lch.hue)
            let srgb = target.gamutMappedRGBA
            let p3 = ColorSpaces.gamutMappedP3(target)
            let srgbP3 = srgb.displayP3
            let differs = abs(p3.red - srgbP3.red) > 0.004 || abs(p3.green - srgbP3.green) > 0.004 || abs(p3.blue - srgbP3.blue) > 0.004
            return Step(stop: stop, lightness: level, target: target, srgb: srgb, displayP3: differs ? p3 : nil)
        }
    }

    /// The index of the step whose lightness is closest to `base`'s.
    public static func closestIndex(to base: RGBA) -> Int {
        let l = base.oklch.lightness
        return stops.indices.min { abs(lightness(at: $0) - l) < abs(lightness(at: $1) - l) } ?? 0
    }
}

nonisolated extension ColorSpaces {
    /// Reduces chroma by bisection until the color fits Display P3; lightness and hue are kept.
    public static func gamutMappedP3(_ lch: OKLCH) -> DisplayP3 {
        func p3(_ c: OKLCH) -> DisplayP3 { c.extendedSRGB.displayP3 }
        func clamped(_ v: DisplayP3) -> DisplayP3 {
            DisplayP3(red: ColorMath.clamp(v.red), green: ColorMath.clamp(v.green), blue: ColorMath.clamp(v.blue))
        }
        let level = ColorMath.clamp(lch.lightness)
        if level <= 0 { return DisplayP3(red: 0, green: 0, blue: 0) }
        if level >= 1 { return DisplayP3(red: 1, green: 1, blue: 1) }
        var candidate = OKLCH(lightness: level, chroma: max(0, lch.chroma), hue: lch.hue)
        if p3(candidate).isInGamut { return clamped(p3(candidate)) }
        var low = 0.0, high = candidate.chroma
        for _ in 0..<24 {
            let mid = (low + high) / 2
            candidate.chroma = mid
            if p3(candidate).isInGamut { low = mid } else { high = mid }
        }
        candidate.chroma = low
        return clamped(p3(candidate))
    }
}

// MARK: - Color-vision distinguishability

/// Which palette pairs become hard to tell apart under each dichromacy.
///
/// Distance is Euclidean in OKLab (ΔEOK, where 0.02 is about one just-noticeable
/// difference under ideal viewing). A pair counts as hard to tell apart when its simulated
/// distance is under `confusionThreshold` = 0.04, twice the JND: swatches that are not side
/// by side, small, or seen in imperfect light need that margin. Only pairs that are apart
/// by at least the threshold in normal vision are scored, so the score reflects what
/// color-vision deficiency takes away, not palettes that were already close.
nonisolated public struct ColorVisionAnalysis: Equatable, Sendable {
    public static let confusionThreshold = 0.04
    public static let modes: [ColorBlindnessMode] = [.protanopia, .deuteranopia, .tritanopia]

    public struct Pair: Equatable, Sendable, Identifiable {
        public let first: Int
        public let second: Int
        /// OKLab distance in normal vision.
        public let normalDistance: Double
        /// OKLab distance after simulation.
        public let simulatedDistance: Double
        public let simulatedFirst: RGBA
        public let simulatedSecond: RGBA

        public var id: String { "\(first)-\(second)" }

        /// How badly the pair collapses: under 0.01 is nearly identical, under 0.02 very hard
        /// to tell apart (about one just-noticeable difference), the rest up to 0.04 hard.
        public var severity: Severity { Severity(simulatedDistance: simulatedDistance) }
    }

    public enum Severity: Int, Comparable, Sendable {
        case nearlyIdentical
        case veryHard
        case hard

        public init(simulatedDistance distance: Double) {
            self = distance < 0.01 ? .nearlyIdentical : (distance < 0.02 ? .veryHard : .hard)
        }

        public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public struct Report: Equatable, Sendable, Identifiable {
        public let mode: ColorBlindnessMode
        /// 0...100: the share of normally distinguishable pairs that stay distinguishable.
        /// Nil when no pair is normally distinguishable (fewer than two colors, or all alike).
        public let score: Int?
        /// Scored pairs that collapse, hardest to tell apart first.
        public let problemPairs: [Pair]
        /// Pairs that are apart in normal vision (the score's denominator).
        public let scoredPairCount: Int

        public var id: String { mode.rawValue }
    }

    public let colors: [RGBA]
    public let reports: [Report]
    /// Pairs already closer than the threshold in normal vision; not counted in any score.
    public let similarForEveryonePairCount: Int

    public init(colors: [RGBA]) {
        self.colors = colors
        let labs = colors.map { $0.oklab }
        var normal: [(Int, Int, Double)] = []
        var similar = 0
        for i in colors.indices {
            for j in colors.indices where j > i {
                let d = Self.distance(labs[i], labs[j])
                if d >= Self.confusionThreshold { normal.append((i, j, d)) } else { similar += 1 }
            }
        }
        similarForEveryonePairCount = similar
        reports = Self.modes.map { mode in
            let simulated = colors.map { ColorBlindnessSimulator.simulate($0, mode: mode) }
            let simLabs = simulated.map { $0.oklab }
            var problems: [Pair] = []
            for (i, j, d) in normal {
                let sd = Self.distance(simLabs[i], simLabs[j])
                if sd < Self.confusionThreshold {
                    problems.append(Pair(first: i, second: j, normalDistance: d, simulatedDistance: sd, simulatedFirst: simulated[i], simulatedSecond: simulated[j]))
                }
            }
            problems.sort { ($0.simulatedDistance, $0.first, $0.second) < ($1.simulatedDistance, $1.first, $1.second) }
            let score: Int? = normal.isEmpty ? nil : Int((Double(normal.count - problems.count) / Double(normal.count) * 100).rounded())
            return Report(mode: mode, score: score, problemPairs: problems, scoredPairCount: normal.count)
        }
    }

    public func report(for mode: ColorBlindnessMode) -> Report? {
        reports.first { $0.mode == mode }
    }

    static func distance(_ a: OKLab, _ b: OKLab) -> Double {
        let dl = a.lightness - b.lightness, da = a.a - b.a, db = a.b - b.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}
