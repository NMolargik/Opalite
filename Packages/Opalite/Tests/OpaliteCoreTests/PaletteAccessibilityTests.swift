//
//  PaletteAccessibilityTests.swift
//  OpaliteCoreTests
//

import Testing
import Foundation
@testable import OpaliteCore

@Suite("Contrast matrix")
struct ContrastMatrixTests {
    @Test func blackOnWhiteIsTwentyOne() throws {
        let matrix = ContrastMatrix(colors: [.black, .white])
        let cell = try #require(matrix.cell(row: 0, column: 1))
        #expect(abs(cell.ratio - 21) < 0.001)
        #expect(cell.normalLevel == .aaa)
        #expect(cell.largeLevel == .aaa)
        #expect(cell.lc > 100)           // dark text on light background
        let reverse = try #require(matrix.cell(row: 1, column: 0))
        #expect(abs(reverse.ratio - cell.ratio) < 1e-9)   // WCAG is symmetric
        #expect(reverse.lc < -100)       // APCA is not
    }

    @Test func knownLevels() {
        // #767676 on white is the classic 4.54:1 (AA), #949494 is 3.03:1 (AA large only).
        let aa = ContrastMatrix(colors: [RGBA(hex: "#767676")!, .white]).cell(row: 0, column: 1)!
        #expect(aa.normalLevel == .aa)
        #expect(aa.largeLevel == .aaa)   // 4.54 >= 4.5
        let large = ContrastMatrix(colors: [RGBA(hex: "#949494")!, .white]).cell(row: 0, column: 1)!
        #expect(large.normalLevel == .fail)
        #expect(large.largeLevel == .aa)
        let fail = ContrastMatrix(colors: [RGBA(hex: "#CCCCCC")!, .white]).cell(row: 0, column: 1)!
        #expect(fail.normalLevel == .fail)
        #expect(fail.largeLevel == .fail)
    }

    @Test func thresholdBoundaries() {
        #expect(ContrastMatrix.TextLevel(normalRatio: 4.5) == .aa)
        #expect(ContrastMatrix.TextLevel(normalRatio: 4.49) == .fail)
        #expect(ContrastMatrix.TextLevel(normalRatio: 7) == .aaa)
        #expect(ContrastMatrix.TextLevel(largeRatio: 3) == .aa)
        #expect(ContrastMatrix.TextLevel(largeRatio: 4.5) == .aaa)
        #expect(ContrastMatrix.TextLevel(largeRatio: 2.99) == .fail)
    }

    @Test func shapeAndCounts() {
        let colors = [RGBA.black, .white, RGBA(red: 0.5, green: 0.5, blue: 0.5), RGBA(red: 1, green: 0, blue: 0)]
        let matrix = ContrastMatrix(colors: colors)
        #expect(matrix.cells.count == 12)
        #expect(matrix.pairs.count == 6)
        #expect(matrix.pairCount == 6)
        #expect(matrix.cell(row: 2, column: 2) == nil)
        #expect(matrix.cell(row: 0, column: 9) == nil)
        #expect(ContrastMatrix(colors: []).cells.isEmpty)
        #expect(ContrastMatrix(colors: [.black]).pairs.isEmpty)
        #expect(matrix.passingPairCount <= matrix.pairCount)
    }

    @Test func deterministic() {
        let colors = (0..<6).map { RGBA(red: Double($0) / 6, green: 0.3, blue: 1 - Double($0) / 6) }
        #expect(ContrastMatrix(colors: colors).cells == ContrastMatrix(colors: colors).cells)
    }
}

@Suite("Lightness scale")
struct LightnessScaleTests {
    private let bases: [RGBA] = [
        RGBA(hex: "#3B82F6")!, RGBA(hex: "#E11D48")!, RGBA(hex: "#16A34A")!,
        RGBA(hex: "#FACC15")!, RGBA(hex: "#808080")!, RGBA(hex: "#7C3AED")!,
        RGBA(hex: "#000000")!, RGBA(hex: "#FFFFFF")!, RGBA(hex: "#00FFFF")!,
    ]

    @Test func elevenStopsFiftyToNineFifty() {
        let steps = LightnessScale.generate(from: bases[0])
        #expect(steps.map(\.stop) == [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950])
    }

    @Test func targetLightnessIsEven() {
        let steps = LightnessScale.generate(from: bases[0])
        #expect(abs(steps.first!.lightness - 0.97) < 1e-12)
        #expect(abs(steps.last!.lightness - 0.17) < 1e-12)
        let gaps = zip(steps, steps.dropFirst()).map { $0.lightness - $1.lightness }
        for gap in gaps { #expect(abs(gap - 0.08) < 1e-9) }
    }

    @Test func lightnessFallsMonotonicallyAfterGamutMapping() {
        for base in bases {
            let measured = LightnessScale.generate(from: base).map { $0.srgb.oklab.lightness }
            for (a, b) in zip(measured, measured.dropFirst()) { #expect(a > b) }
            // Mapped lightness stays within a hair of the target (chroma reduction keeps L).
            for (step, l) in zip(LightnessScale.generate(from: base), measured) {
                #expect(abs(step.lightness - l) < 0.01)
            }
        }
    }

    @Test func everyStepIsInsideSRGB() {
        for base in bases {
            for step in LightnessScale.generate(from: base) {
                #expect(step.srgb.isInSRGBGamut)
                #expect((0...1).contains(step.srgb.red) && (0...1).contains(step.srgb.green) && (0...1).contains(step.srgb.blue))
            }
        }
    }

    @Test func keepsHueOfBase() {
        let base = RGBA(hex: "#3B82F6")!
        let hue = base.oklch.hue
        for step in LightnessScale.generate(from: base).dropFirst().dropLast() {
            let h = step.srgb.oklch.hue
            let diff = min(abs(h - hue), 360 - abs(h - hue))
            #expect(diff < 3)
        }
    }

    @Test func neutralBaseGivesNeutralScale() {
        for step in LightnessScale.generate(from: RGBA(hex: "#808080")!) {
            #expect(abs(step.srgb.red - step.srgb.green) < 0.002)
            #expect(abs(step.srgb.green - step.srgb.blue) < 0.002)
            #expect(step.displayP3 == nil)
        }
    }

    @Test func vividColorGetsP3ValuesAndInGamutOnesDoNot() {
        // Pure sRGB-green-ish chroma at mid lightness exceeds sRGB but fits P3 partly.
        let vivid = RGBA(hex: "#00FF40")!
        let steps = LightnessScale.generate(from: vivid)
        #expect(steps.contains { $0.displayP3 != nil })
        for step in steps {
            if let p3 = step.displayP3 { #expect(p3.isInGamut) }
        }
        // The extremes of a muted color are comfortably inside sRGB: no P3 variant.
        let muted = LightnessScale.generate(from: RGBA(hex: "#8A7F72")!)
        #expect(muted.allSatisfy { $0.displayP3 == nil })
    }

    @Test func deterministic() {
        #expect(LightnessScale.generate(from: bases[1]) == LightnessScale.generate(from: bases[1]))
    }

    @Test func closestIndexMatchesLightness() {
        #expect(LightnessScale.closestIndex(to: .white) == 0)
        #expect(LightnessScale.closestIndex(to: .black) == 10)
        let mid = RGBA(hex: "#808080")!   // OKLab L about 0.60
        let index = LightnessScale.closestIndex(to: mid)
        #expect(abs(LightnessScale.lightness(at: index) - mid.oklab.lightness) <= 0.04 + 1e-9)
    }

    @Test func p3MappingKeepsLightnessAndFits() {
        let lch = OKLCH(lightness: 0.7, chroma: 0.4, hue: 145)
        let p3 = ColorSpaces.gamutMappedP3(lch)
        #expect(p3.isInGamut)
        let l = ColorSpaces.srgb(from: p3).oklab.lightness
        #expect(abs(l - 0.7) < 0.01)
    }
}

@Suite("Color vision analysis")
struct ColorVisionAnalysisTests {
    private let red = RGBA(hex: "#E02020")!
    private let green = RGBA(hex: "#20A020")!
    private let blue = RGBA(hex: "#2040E0")!

    @Test func knownConfusablePairsCollapseForTheirDeficiency() throws {
        // Pairs found by search: far apart in normal vision (ΔEOK > 0.2), nearly identical after simulation.
        let cases: [(ColorBlindnessMode, String, String)] = [
            (.protanopia, "#C82563", "#A68E3D"),
            (.deuteranopia, "#C82563", "#B98138"),
            (.tritanopia, "#1681D4", "#2A13E9"),
        ]
        for (mode, first, second) in cases {
            let analysis = ColorVisionAnalysis(colors: [RGBA(hex: first)!, RGBA(hex: second)!])
            let report = try #require(analysis.report(for: mode))
            #expect(report.scoredPairCount == 1)
            #expect(report.score == 0)
            let pair = try #require(report.problemPairs.first)
            #expect(pair.normalDistance > 0.2)
            #expect(pair.simulatedDistance < 0.01)
        }
    }

    @Test func confusablePairIsFineForOtherDeficiencies() throws {
        let analysis = ColorVisionAnalysis(colors: [RGBA(hex: "#C82563")!, RGBA(hex: "#A68E3D")!])
        #expect(analysis.report(for: .tritanopia)?.score == 100)
    }

    @Test func blackAndWhiteNeverCollapse() {
        let analysis = ColorVisionAnalysis(colors: [.black, .white])
        for report in analysis.reports {
            #expect(report.score == 100)
            #expect(report.problemPairs.isEmpty)
            #expect(report.scoredPairCount == 1)
        }
        #expect(analysis.similarForEveryonePairCount == 0)
    }

    @Test func identicalAndTinyPalettes() {
        let single = ColorVisionAnalysis(colors: [red])
        #expect(single.reports.allSatisfy { $0.score == nil && $0.problemPairs.isEmpty })
        #expect(ColorVisionAnalysis(colors: []).reports.count == 3)
        let twins = ColorVisionAnalysis(colors: [red, red])
        #expect(twins.similarForEveryonePairCount == 1)
        #expect(twins.reports.allSatisfy { $0.score == nil })
    }

    @Test func reportsCoverTheThreeDichromacies() {
        let analysis = ColorVisionAnalysis(colors: [red, green, blue])
        #expect(analysis.reports.map(\.mode) == [.protanopia, .deuteranopia, .tritanopia])
    }

    @Test func problemPairsAreUnderThresholdAndSorted() {
        let colors = [red, green, blue, RGBA(hex: "#B07030")!, RGBA(hex: "#808020")!, RGBA(hex: "#E0A0A0")!]
        let analysis = ColorVisionAnalysis(colors: colors)
        for report in analysis.reports {
            for pair in report.problemPairs {
                #expect(pair.simulatedDistance < ColorVisionAnalysis.confusionThreshold)
                #expect(pair.normalDistance >= ColorVisionAnalysis.confusionThreshold)
                #expect(pair.first < pair.second)
            }
            let distances = report.problemPairs.map(\.simulatedDistance)
            #expect(distances == distances.sorted())
            if let score = report.score {
                let expected = Int((Double(report.scoredPairCount - report.problemPairs.count) / Double(report.scoredPairCount) * 100).rounded())
                #expect(score == expected)
                #expect((0...100).contains(score))
            }
        }
    }

    @Test func simulatedPreviewMatchesSimulator() throws {
        let analysis = ColorVisionAnalysis(colors: [RGBA(hex: "#C8641E")!, RGBA(hex: "#7F9B1F")!])
        for report in analysis.reports {
            for pair in report.problemPairs {
                #expect(pair.simulatedFirst == ColorBlindnessSimulator.simulate(analysis.colors[pair.first], mode: report.mode))
                #expect(pair.simulatedSecond == ColorBlindnessSimulator.simulate(analysis.colors[pair.second], mode: report.mode))
            }
        }
    }

    @Test func severityBands() {
        #expect(ColorVisionAnalysis.Severity(simulatedDistance: 0.0) == .nearlyIdentical)
        #expect(ColorVisionAnalysis.Severity(simulatedDistance: 0.0099) == .nearlyIdentical)
        #expect(ColorVisionAnalysis.Severity(simulatedDistance: 0.01) == .veryHard)
        #expect(ColorVisionAnalysis.Severity(simulatedDistance: 0.0199) == .veryHard)
        #expect(ColorVisionAnalysis.Severity(simulatedDistance: 0.02) == .hard)
        #expect(ColorVisionAnalysis.Severity(simulatedDistance: 0.039) == .hard)
        let analysis = ColorVisionAnalysis(colors: [RGBA(hex: "#C82563")!, RGBA(hex: "#A68E3D")!])
        #expect(analysis.report(for: .protanopia)?.problemPairs.first?.severity == .nearlyIdentical)
    }

    @Test func deterministic() {
        let colors = [red, green, blue, RGBA(hex: "#B07030")!]
        #expect(ColorVisionAnalysis(colors: colors) == ColorVisionAnalysis(colors: colors))
    }

    @Test func distanceKnownValues() {
        let d = ColorVisionAnalysis.distance(RGBA.black.oklab, RGBA.white.oklab)
        #expect(abs(d - 1.0) < 0.001)   // OKLab L spans 0...1
    }
}
