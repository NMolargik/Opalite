//
//  ColorHarmonyTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("ColorHarmony")
struct ColorHarmonyTests {
    let red = RGBA(red: 1, green: 0, blue: 0)
    let teal = RGBA(red: 0.2, green: 0.6, blue: 0.7, alpha: 0.5)

    @Test func rotatingAFullTurnIsIdentity() {
        #expect(ColorHarmony.rotated(teal, by: 360).isClose(to: teal))
        #expect(ColorHarmony.rotated(teal, by: -360).isClose(to: teal))
        #expect(ColorHarmony.rotated(teal, by: 720).isClose(to: teal))
    }

    @Test func rotationWrapsNegativeDegrees() {
        let minus = ColorHarmony.rotated(teal, by: -90)
        let plus = ColorHarmony.rotated(teal, by: 270)
        #expect(minus.isClose(to: plus))
        #expect(minus.hsl.hue >= 0 && minus.hsl.hue < 360)
    }

    @Test func rotationPreservesAlphaAndLightness() {
        let rotated = ColorHarmony.rotated(teal, by: 45)
        #expect(rotated.alpha == 0.5)
        #expect(rotated.hsl.lightness.isClose(to: teal.hsl.lightness))
        #expect(rotated.hsl.saturation.isClose(to: teal.hsl.saturation))
        #expect(rotated.hsl.hue.isClose(to: teal.hsl.hue + 45))
    }

    @Test func complementaryOfRedIsCyan() {
        #expect(ColorHarmony.complementary(of: red).isClose(to: RGBA(red: 0, green: 1, blue: 1)))
        #expect(ColorHarmony.complementary(of: ColorHarmony.complementary(of: teal)).isClose(to: teal))
    }

    @Test func analogousStraddlesTheBase() {
        let pair = ColorHarmony.analogous(of: red)
        #expect(pair.count == 2)
        #expect(pair[0].hsl.hue.isClose(to: 330))
        #expect(pair[1].hsl.hue.isClose(to: 30))
    }

    @Test func triadicIsOneHundredTwentyApart() {
        let pair = ColorHarmony.triadic(of: red)
        #expect(pair.count == 2)
        #expect(pair[0].isClose(to: RGBA(red: 0, green: 1, blue: 0)))
        #expect(pair[1].isClose(to: RGBA(red: 0, green: 0, blue: 1)))
    }

    @Test func tetradicIsNinetyApart() {
        let hues = ColorHarmony.tetradic(of: red).map(\.hsl.hue)
        #expect(hues.count == 3)
        #expect(hues[0].isClose(to: 90) && hues[1].isClose(to: 180) && hues[2].isClose(to: 270))
    }

    @Test func splitComplementaryFlanksTheComplement() {
        let hues = ColorHarmony.splitComplementary(of: red).map(\.hsl.hue)
        #expect(hues.count == 2)
        #expect(hues[0].isClose(to: 150) && hues[1].isClose(to: 210))
    }

    @Test("Tints get monotonically lighter", arguments: [1, 3, 5, 8])
    func tints(count: Int) {
        let tints = ColorHarmony.tints(of: red, count: count)
        #expect(tints.count == count)
        var previous = red.hsl.lightness
        for tint in tints {
            #expect(tint.hsl.lightness > previous)
            previous = tint.hsl.lightness
        }
        #expect(tints.allSatisfy { $0.hsl.lightness < 1 })
    }

    @Test("Shades get monotonically darker", arguments: [1, 3, 5])
    func shades(count: Int) {
        let shades = ColorHarmony.shades(of: red, count: count)
        #expect(shades.count == count)
        var previous = red.hsl.lightness
        for shade in shades {
            #expect(shade.hsl.lightness < previous)
            previous = shade.hsl.lightness
        }
        #expect(shades.allSatisfy { $0.hsl.lightness > 0 })
    }

    @Test func tonesDesaturateTowardGray() {
        let tones = ColorHarmony.tones(of: red, count: 5)
        #expect(tones.count == 5)
        var previous = red.hsl.saturation
        for tone in tones {
            #expect(tone.hsl.saturation < previous)
            previous = tone.hsl.saturation
        }
    }

    @Test func zeroOrNegativeCountsProduceNothing() {
        #expect(ColorHarmony.tints(of: red, count: 0).isEmpty)
        #expect(ColorHarmony.shades(of: red, count: -1).isEmpty)
        #expect(ColorHarmony.tones(of: red, count: 0).isEmpty)
    }

    @Test func laddersExcludeTheBaseAndTheExtreme() {
        let tints = ColorHarmony.tints(of: red, count: 2)
        #expect(!tints.contains(where: { $0.isClose(to: red) }))
        #expect(!tints.contains(where: { $0.isClose(to: .white) }))
    }

    @Test func mixEndpointsAndMidpoint() {
        let a = RGBA(red: 0, green: 0, blue: 0, alpha: 0.3)
        let b = RGBA(red: 1, green: 1, blue: 1, alpha: 1)
        #expect(ColorHarmony.mix(a, b, 0) == a)
        let full = ColorHarmony.mix(a, b, 1)
        #expect(full.red == 1 && full.green == 1 && full.blue == 1)
        #expect(full.alpha == 0.3, "mix keeps the first color's alpha")
        let mid = ColorHarmony.mix(a, b, 0.5)
        #expect(mid.isClose(to: RGBA(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3)))
    }

    @Test func mixClampsTheParameter() {
        let a = RGBA.black, b = RGBA.white
        #expect(ColorHarmony.mix(a, b, 5) == ColorHarmony.mix(a, b, 1))
        #expect(ColorHarmony.mix(a, b, -2) == a)
    }
}
