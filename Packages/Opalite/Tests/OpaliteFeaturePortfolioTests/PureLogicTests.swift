import Foundation
import Testing
import OpaliteCore
@testable import OpaliteFeaturePortfolio

@Suite("Quick-add hex validation")
struct QuickAddHexInputTests {
    @Test func sanitizesToUppercaseHexDigitsCappedAtEight() {
        #expect(QuickAddHexInput("#ff00aa").text == "FF00AA")
        #expect(QuickAddHexInput("zz 12 34 !!").text == "1234")
        #expect(QuickAddHexInput("0123456789AB").text == "01234567")
    }

    @Test func validAtSixOrEightDigitsOnly() {
        #expect(!QuickAddHexInput("FF00A").isValid)
        #expect(QuickAddHexInput("FF00AA").isValid)
        #expect(!QuickAddHexInput("FF00AA8").isValid)
        #expect(QuickAddHexInput("FF00AA80").isValid)
        #expect(QuickAddHexInput("FF00AA80").includesAlpha)
    }

    @Test func parsesComponents() throws {
        let rgba = try #require(QuickAddHexInput("3380CC").rgba)
        #expect(abs(rgba.red - 0x33 / 255.0) < 0.001)
        #expect(abs(rgba.green - 0x80 / 255.0) < 0.001)
        #expect(abs(rgba.blue - 0xCC / 255.0) < 0.001)
        #expect(rgba.alpha == 1)
        let alpha = try #require(QuickAddHexInput("3380CC80").rgba)
        #expect(abs(alpha.alpha - 0x80 / 255.0) < 0.001)
    }

    @Test func validationMessageOnlyWhileIncomplete() {
        #expect(QuickAddHexInput("").validationMessage == nil)
        #expect(QuickAddHexInput("FF0").validationMessage != nil)
        #expect(QuickAddHexInput("FF00AA").validationMessage == nil)
        #expect(QuickAddHexInput("FF00AA").displayHex == "#FF00AA")
        #expect(QuickAddHexInput("FF00AA80").displayHex == "#FF00AA80")
    }
}

@Suite("Contrast pairing")
struct ContrastCheckTests {
    @Test func noComparisonMeansNoRatio() {
        let check = ContrastCheck(source: .black)
        #expect(check.ratio == nil)
        #expect(check.ratioText == "—:1")
        #expect(check.passingCriteria.isEmpty)
    }

    @Test func blackOnWhiteIsMaximumContrast() {
        var check = ContrastCheck(source: .black)
        check.select(.white)
        #expect(abs((check.ratio ?? 0) - 21) < 0.01)
        #expect(check.passingCriteria.count == ContrastCheck.Criterion.allCases.count)
        #expect(check.conformance?.level == .aaa)
    }

    @Test func midGrayOnWhitePassesLargeOnly() {
        var check = ContrastCheck(source: .white)
        check.select(.gray)
        #expect(check.passes(.aaLarge))
        #expect(!check.passes(.aaNormal))
        #expect(!check.passes(.aaaNormal))
    }

    @Test func hexSelectionRejectsIncompleteCodes() {
        var check = ContrastCheck(source: .black)
        let rejected = check.select(hex: "FF")
        #expect(!rejected)
        #expect(check.comparison == nil)
        let accepted = check.select(hex: "#FFFFFF")
        #expect(accepted)
        #expect(check.comparison == .white)
    }

    @Test func candidatesExcludeTheSourceAndCap() {
        let source = UUID()
        let colors = (0..<30).map { ContrastCandidate(id: $0 == 3 ? source : UUID(), name: nil, rgba: .black) }
        let candidates = ContrastCheck.candidates(from: colors, excluding: source, limit: 10)
        #expect(candidates.count == 10)
        #expect(!candidates.contains { $0.id == source })
    }
}

@Suite("Harmony kinds and tone ladders")
struct HarmonyKindTests {
    @Test func colorCountsMatchOffsets() {
        let base = RGBA(red: 0.2, green: 0.5, blue: 0.8)
        for kind in HarmonyKind.allCases {
            #expect(kind.colors(for: base).count == kind.hueOffsets.count)
            #expect(kind.pointCount == kind.hueOffsets.count + 1)
            #expect(kind.paddedWheelAngles(baseHue: 210).count == 4)
        }
    }

    @Test func wheelAnglesWrapAround() {
        let angles = HarmonyKind.analogous.wheelAngles(baseHue: 10)
        #expect(angles[0] == 10)
        #expect(angles[1] == 340)
        #expect(angles[2] == 40)
    }

    @Test func complementaryRotatesHueBy180() {
        let base = RGBA(red: 1, green: 0, blue: 0)
        let complement = HarmonyKind.complementary.colors(for: base)[0]
        #expect(abs(complement.hsl.hue - 180) < 0.5)
    }

    @Test func ladderStepsExcludeBaseAndLabelPercentages() {
        let base = RGBA(red: 0.2, green: 0.4, blue: 0.8)
        let tints = ToneLadder.tints.steps(for: base)
        #expect(tints.count == ToneLadder.defaultStepCount)
        #expect(tints.map(\.label) == ["+20%", "+40%", "+60%", "+80%"])
        #expect(tints.last!.rgba.red > tints.first!.rgba.red)
        let shades = ToneLadder.shades.steps(for: base)
        #expect(shades.first!.label == "−20%")
        #expect(shades.last!.rgba.blue < shades.first!.rgba.blue)
        #expect(ToneLadder.tones.steps(for: base).map(\.label) == ["20%", "40%", "60%", "80%"])
    }
}

@Suite("Detail formatting")
struct DetailFormattingTests {
    @Test func shortDeviceNames() {
        #expect(DetailFormatting.shortDeviceName("iPhone 17 Pro") == "iPhone")
        #expect(DetailFormatting.shortDeviceName("MacBook Pro") == "Mac")
        #expect(DetailFormatting.shortDeviceName("Nick's Toaster") == "Nick's Toaster")
        #expect(DetailFormatting.shortDeviceName(nil) == "—")
        #expect(DetailFormatting.shortDeviceName("  ") == "—")
    }

    @Test func tagsNormalizeAndDeduplicate() {
        #expect(DetailFormatting.normalizedTag("  #Warm   tones ") == "Warm tones")
        #expect(DetailFormatting.normalizedTag("##") == nil)
        #expect(DetailFormatting.addingTag("warm", to: ["Warm"]) == ["Warm"])
        #expect(DetailFormatting.addingTag("cool", to: ["Warm"]) == ["Warm", "cool"])
    }

    @Test func cmykFormatting() {
        let cmyk = CMYK(cyan: 0.1, magenta: 0.2, yellow: 0.3, key: 0.4)
        #expect(DetailFormatting.cmykString(cmyk) == "cmyk(10%, 20%, 30%, 40%)")
    }
}
