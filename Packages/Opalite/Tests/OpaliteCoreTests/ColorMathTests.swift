//
//  ColorMathTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("ColorMath — hex")
struct ColorMathHexTests {
    @Test("Parses six-digit hex with and without the hash", arguments: ["#FF5733", "FF5733", "#ff5733", "0xFF5733", "  #FF5733\n"])
    func parsesSixDigit(text: String) throws {
        let rgba = try #require(ColorMath.parseHex(text))
        #expect(rgba.red.isClose(to: 1))
        #expect(rgba.green.isClose(to: 0x57 / 255))
        #expect(rgba.blue.isClose(to: 0x33 / 255))
        #expect(rgba.alpha == 1)
    }

    @Test func parsesShorthandRGB() throws {
        let rgba = try #require(RGBA(hex: "#F53"))
        #expect(rgba.hexString == "#FF5533")
        #expect(rgba.alpha == 1)
    }

    @Test func parsesShorthandRGBA() throws {
        let rgba = try #require(RGBA(hex: "#F53A"))
        #expect(rgba.hexString == "#FF5533")
        #expect(rgba.alpha.isClose(to: 0xAA / 255))
    }

    @Test func parsesEightDigitWithAlpha() throws {
        let rgba = try #require(RGBA(hex: "#FF573380"))
        #expect(rgba.hexString == "#FF5733")
        #expect(rgba.alpha.isClose(to: 0x80 / 255))
        #expect(rgba.hexWithAlphaString == "#FF573380")
    }

    @Test("Rejects malformed hex", arguments: ["", "#", "#GGGGGG", "#12345", "12", "#1234567", "#FF57331", "hello", "#FF 57 33"])
    func rejectsInvalid(text: String) {
        #expect(ColorMath.parseHex(text) == nil)
        #expect(!ColorMath.isValidHex(text))
        #expect(RGBA(hex: text) == nil)
    }

    @Test("Canonical formatting", arguments: [
        (RGBA.black, "#000000"),
        (RGBA.white, "#FFFFFF"),
        (RGBA(red: 1, green: 0, blue: 0), "#FF0000"),
        (RGBA(red: 0, green: 1, blue: 0), "#00FF00"),
        (RGBA(red: 0, green: 0, blue: 1), "#0000FF"),
        (RGBA(red: 0.5, green: 0.25, blue: 0.75), "#8040BF"),
    ])
    func formatsHex(color: RGBA, expected: String) {
        #expect(color.hexString == expected)
    }

    @Test func hexWithAlphaFormatsOpaqueAndTranslucent() {
        #expect(RGBA(red: 1, green: 0, blue: 0).hexWithAlphaString == "#FF0000FF")
        #expect(RGBA(red: 0, green: 0, blue: 0, alpha: 0.5).hexWithAlphaString == "#00000080")
        #expect(RGBA(red: 0, green: 0, blue: 0, alpha: 0).hexWithAlphaString == "#00000000")
    }

    @Test func hexRoundTripsForEveryByteBoundary() {
        for value in stride(from: 0, through: 255, by: 17) {
            let channel = Double(value) / 255
            let rgba = RGBA(red: channel, green: channel, blue: channel)
            let parsed = RGBA(hex: rgba.hexString)
            #expect(parsed?.red.byte == value)
        }
    }

    @Test func byteClampsAndRounds() {
        #expect(0.5.byte == 128)
        #expect(1.2.byte == 255)
        #expect((-0.1).byte == 0)
        #expect(0.0.byte == 0)
        #expect(1.0.byte == 255)
        #expect((0.5 / 255).byte == 1)
    }

    @Test func clampStaysWithinUnitRange() {
        #expect(ColorMath.clamp(-3) == 0)
        #expect(ColorMath.clamp(0.4) == 0.4)
        #expect(ColorMath.clamp(7) == 1)
    }
}

@Suite("ColorMath — CSS strings")
struct ColorMathStringTests {
    @Test func rgbStrings() {
        #expect(RGBA.black.rgbString == "rgb(0, 0, 0)")
        #expect(RGBA.white.rgbString == "rgb(255, 255, 255)")
        #expect(RGBA(red: 0.5, green: 0.5, blue: 0.5).rgbString == "rgb(128, 128, 128)")
    }

    @Test func rgbaStringsTrimAlpha() {
        #expect(RGBA(red: 0, green: 0, blue: 0, alpha: 0.5).rgbaString == "rgba(0, 0, 0, 0.5)")
        #expect(RGBA(red: 0, green: 0, blue: 0, alpha: 1).rgbaString == "rgba(0, 0, 0, 1)")
        #expect(RGBA(red: 0, green: 0, blue: 0, alpha: 0.25).rgbaString == "rgba(0, 0, 0, 0.25)")
    }

    @Test("HSL strings", arguments: [
        (RGBA(red: 1, green: 0, blue: 0), "hsl(0, 100%, 50%)"),
        (RGBA(red: 0, green: 1, blue: 0), "hsl(120, 100%, 50%)"),
        (RGBA(red: 0, green: 0, blue: 1), "hsl(240, 100%, 50%)"),
        (RGBA(red: 1, green: 1, blue: 0), "hsl(60, 100%, 50%)"),
        (RGBA(red: 0, green: 1, blue: 1), "hsl(180, 100%, 50%)"),
        (RGBA(red: 1, green: 0, blue: 1), "hsl(300, 100%, 50%)"),
        (RGBA(red: 0.5, green: 0.5, blue: 0.5), "hsl(0, 0%, 50%)"),
    ])
    func hslStrings(color: RGBA, expected: String) {
        #expect(color.hslString == expected)
    }

    @Test("trimmed drops trailing zeros", arguments: [
        (1.0, "1"), (0.5, "0.5"), (0.25, "0.25"), (0.0, "0"), (0.999, "1"), (0.1, "0.1"), (0.123, "0.12"),
    ])
    func trimmed(value: Double, expected: String) {
        #expect(ColorMath.trimmed(value) == expected)
    }
}

@Suite("ColorMath — color spaces")
struct ColorMathSpaceTests {
    nonisolated static let primaries: [RGBA] = [
        RGBA(red: 1, green: 0, blue: 0),
        RGBA(red: 0, green: 1, blue: 0),
        RGBA(red: 0, green: 0, blue: 1),
        RGBA(red: 1, green: 1, blue: 0),
        RGBA(red: 0, green: 1, blue: 1),
        RGBA(red: 1, green: 0, blue: 1),
        RGBA(red: 0.2, green: 0.5, blue: 0.8),
        RGBA(red: 0.95, green: 0.45, blue: 0.3),
        RGBA(red: 0.1, green: 0.1, blue: 0.1),
        RGBA(red: 0.9, green: 0.85, blue: 0.7),
        .black, .white,
    ]

    @Test func hslOfPrimaries() {
        let red = RGBA(red: 1, green: 0, blue: 0).hsl
        #expect(red.hue.isClose(to: 0) && red.saturation.isClose(to: 1) && red.lightness.isClose(to: 0.5))
        let green = RGBA(red: 0, green: 1, blue: 0).hsl
        #expect(green.hue.isClose(to: 120))
        let blue = RGBA(red: 0, green: 0, blue: 1).hsl
        #expect(blue.hue.isClose(to: 240))
        let white = RGBA.white.hsl
        #expect(white.saturation == 0 && white.lightness == 1)
        let black = RGBA.black.hsl
        #expect(black.saturation == 0 && black.lightness == 0)
    }

    @Test func hslToRGB() {
        #expect(HSL(hue: 0, saturation: 1, lightness: 0.5).rgba.isClose(to: RGBA(red: 1, green: 0, blue: 0)))
        #expect(HSL(hue: 120, saturation: 1, lightness: 0.5).rgba.isClose(to: RGBA(red: 0, green: 1, blue: 0)))
        #expect(HSL(hue: 200, saturation: 0, lightness: 0.4).rgba.isClose(to: RGBA(red: 0.4, green: 0.4, blue: 0.4)))
    }

    @Test func hslHueWrapsAroundTheWheel() {
        let base = HSL(hue: 30, saturation: 0.8, lightness: 0.5).rgba
        #expect(HSL(hue: 390, saturation: 0.8, lightness: 0.5).rgba.isClose(to: base))
        #expect(HSL(hue: -330, saturation: 0.8, lightness: 0.5).rgba.isClose(to: base))
    }

    @Test("HSL round trips", arguments: primaries)
    func hslRoundTrip(color: RGBA) {
        #expect(color.hsl.rgba.isClose(to: color))
    }

    @Test func hsvOfPrimaries() {
        let red = RGBA(red: 1, green: 0, blue: 0).hsv
        #expect(red.hue.isClose(to: 0) && red.saturation.isClose(to: 1) && red.value.isClose(to: 1))
        let green = RGBA(red: 0, green: 1, blue: 0).hsv
        #expect(green.hue.isClose(to: 120))
        let blue = RGBA(red: 0, green: 0, blue: 1).hsv
        #expect(blue.hue.isClose(to: 240))
        #expect(RGBA.black.hsv.value == 0)
        let white = RGBA.white.hsv
        #expect(white.saturation == 0 && white.value == 1)
    }

    @Test("HSV round trips", arguments: primaries)
    func hsvRoundTrip(color: RGBA) {
        #expect(color.hsv.rgba.isClose(to: color))
    }

    @Test func hsvHueWraps() {
        let base = HSV(hue: 45, saturation: 0.6, value: 0.9).rgba
        #expect(HSV(hue: 405, saturation: 0.6, value: 0.9).rgba.isClose(to: base))
        #expect(HSV(hue: -315, saturation: 0.6, value: 0.9).rgba.isClose(to: base))
    }

    @Test func cmykOfKnownColors() {
        let black = RGBA.black.cmyk
        #expect(black.key == 1 && black.cyan == 0 && black.magenta == 0 && black.yellow == 0)
        let white = RGBA.white.cmyk
        #expect(white.key == 0 && white.cyan == 0 && white.magenta == 0 && white.yellow == 0)
        let red = RGBA(red: 1, green: 0, blue: 0).cmyk
        #expect(red.cyan.isClose(to: 0) && red.magenta.isClose(to: 1) && red.yellow.isClose(to: 1) && red.key.isClose(to: 0))
        let half = RGBA(red: 0.5, green: 0.5, blue: 0.5).cmyk
        #expect(half.key.isClose(to: 0.5) && half.cyan.isClose(to: 0))
    }

    @Test("CMYK inverts back to RGB", arguments: primaries)
    func cmykRoundTrip(color: RGBA) {
        let c = color.cmyk
        let red = (1 - c.cyan) * (1 - c.key)
        let green = (1 - c.magenta) * (1 - c.key)
        let blue = (1 - c.yellow) * (1 - c.key)
        #expect(RGBA(red: red, green: green, blue: blue).isClose(to: RGBA(red: color.red, green: color.green, blue: color.blue)))
    }

    @Test("sRGB ↔ linear round trips", arguments: [0.0, 0.001, 0.04, 0.05, 0.2, 0.5, 0.9, 1.0])
    func linearRoundTrip(value: Double) {
        #expect(ColorMath.linearToSRGB(ColorMath.sRGBToLinear(value)).isClose(to: value, tolerance: 1e-9))
        #expect(ColorMath.sRGBToLinear(0) == 0)
        #expect(ColorMath.sRGBToLinear(1).isClose(to: 1, tolerance: 1e-9))
    }
}

@Suite("ColorMath — WCAG")
struct ColorMathWCAGTests {
    @Test func luminanceExtremes() {
        #expect(RGBA.black.relativeLuminance == 0)
        #expect(RGBA.white.relativeLuminance.isClose(to: 1, tolerance: 1e-9))
        let gray = RGBA(red: 0.5, green: 0.5, blue: 0.5).relativeLuminance
        #expect(gray > 0.2 && gray < 0.22)
    }

    @Test func contrastRatioBlackWhiteIsTwentyOne() {
        #expect(RGBA.black.contrastRatio(against: .white).isClose(to: 21, tolerance: 1e-6))
        #expect(RGBA.white.contrastRatio(against: .black).isClose(to: 21, tolerance: 1e-6))
    }

    @Test func contrastRatioIsSymmetricAndIdentityIsOne() {
        let a = RGBA(red: 0.2, green: 0.5, blue: 0.8)
        let b = RGBA(red: 0.9, green: 0.1, blue: 0.4)
        #expect(a.contrastRatio(against: b).isClose(to: b.contrastRatio(against: a), tolerance: 1e-9))
        #expect(a.contrastRatio(against: a) == 1)
    }

    @Test func darkTextPreference() {
        #expect(RGBA.white.prefersDarkText)
        #expect(!RGBA.black.prefersDarkText)
        #expect(RGBA(red: 1, green: 1, blue: 0).prefersDarkText)
        #expect(!RGBA(red: 0, green: 0, blue: 0.6).prefersDarkText)
        #expect(ColorMath.darkTextLuminanceThreshold == 0.179)
    }

    @Test("Conformance levels", arguments: [
        (21.0, WCAGConformance.Level.aaa),
        (7.0, .aaa),
        (6.99, .aa),
        (4.5, .aa),
        (4.49, .aaLarge),
        (3.0, .aaLarge),
        (2.99, .fail),
        (1.0, .fail),
    ])
    func levels(ratio: Double, expected: WCAGConformance.Level) {
        #expect(WCAGConformance(ratio: ratio).level == expected)
    }

    @Test func passFlagsAtBoundaries() {
        let aa = WCAGConformance(ratio: 4.5)
        #expect(aa.passesAANormalText && aa.passesAALargeText && aa.passesAAALargeText && aa.passesUIComponents && !aa.passesAAANormalText)
        let large = WCAGConformance(ratio: 3)
        #expect(!large.passesAANormalText && large.passesAALargeText && large.passesUIComponents)
        let fail = WCAGConformance(ratio: 2)
        #expect(!fail.passesAALargeText && !fail.passesUIComponents)
    }

    @Test func ratioText() {
        #expect(WCAGConformance(ratio: 4.5).ratioText == "4.50:1")
        #expect(WCAGConformance(ratio: 21).ratioText == "21.00:1")
        #expect(WCAGConformance.Level.aaLarge.rawValue == "AA Large")
    }
}

@Suite("RGBA value type")
struct RGBAValueTests {
    @Test func codableRoundTrip() throws {
        let color = RGBA(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        let data = try JSONEncoder().encode(color)
        #expect(try JSONDecoder().decode(RGBA.self, from: data) == color)
    }

    @Test func defaultAlphaIsOpaque() {
        #expect(RGBA(red: 0, green: 0, blue: 0).alpha == 1)
        #expect(RGBA.black == RGBA(red: 0, green: 0, blue: 0, alpha: 1))
    }
}
