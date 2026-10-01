//
//  ColorBlindnessSimulatorTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("ColorBlindnessSimulator")
struct ColorBlindnessSimulatorTests {
    let red = RGBA(red: 1, green: 0, blue: 0)
    let green = RGBA(red: 0, green: 1, blue: 0)
    let blue = RGBA(red: 0, green: 0, blue: 1)

    @Test func offIsIdentity() {
        let color = RGBA(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.7)
        #expect(ColorBlindnessSimulator.simulate(color, mode: .off) == color)
        let tuple = ColorBlindnessSimulator.simulate(red: 0.3, green: 0.6, blue: 0.9, mode: .off)
        #expect(tuple.r == 0.3 && tuple.g == 0.6 && tuple.b == 0.9)
    }

    @Test func protanopiaDarkensPureRed() {
        let simulated = ColorBlindnessSimulator.simulate(red, mode: .protanopia)
        #expect(simulated.red < 1)
        #expect(simulated.green > 0, "red leaks into green for a red-blind viewer")
        #expect(simulated.blue.isClose(to: 0, tolerance: 1e-6))
    }

    @Test func deuteranopiaChangesPureGreen() {
        let simulated = ColorBlindnessSimulator.simulate(green, mode: .deuteranopia)
        #expect(simulated.green < 1)
        #expect(simulated.red > 0)
        #expect(simulated.blue > 0)
    }

    @Test func tritanopiaChangesPureBlue() {
        let simulated = ColorBlindnessSimulator.simulate(blue, mode: .tritanopia)
        #expect(simulated.blue < 1)
        #expect(simulated.green > 0)
        #expect(simulated.red.isClose(to: 0, tolerance: 1e-6))
    }

    @Test func achromatopsiaIsGrayscaleWeightedByLuminance() {
        for color in [red, green, blue, RGBA(red: 0.2, green: 0.5, blue: 0.8)] {
            let simulated = ColorBlindnessSimulator.simulate(color, mode: .achromatopsia)
            #expect(simulated.red.isClose(to: simulated.green, tolerance: 1e-9))
            #expect(simulated.green.isClose(to: simulated.blue, tolerance: 1e-9))
        }
        let g = ColorBlindnessSimulator.simulate(green, mode: .achromatopsia).red
        let r = ColorBlindnessSimulator.simulate(red, mode: .achromatopsia).red
        let b = ColorBlindnessSimulator.simulate(blue, mode: .achromatopsia).red
        #expect(g > r && r > b, "green carries the most luminance, blue the least")
    }

    @Test("Black stays black and white stays white", arguments: ColorBlindnessMode.allCases)
    func extremesArePreserved(mode: ColorBlindnessMode) {
        let black = ColorBlindnessSimulator.simulate(.black, mode: mode)
        #expect(black.isClose(to: .black, tolerance: 1e-6))
        let white = ColorBlindnessSimulator.simulate(.white, mode: mode)
        #expect(white.isClose(to: .white, tolerance: 0.01))
    }

    @Test("Output is clamped to the unit cube", arguments: ColorBlindnessMode.allCases)
    func outputIsClamped(mode: ColorBlindnessMode) {
        let steps: [Double] = [0, 0.25, 0.5, 0.75, 1]
        for r in steps {
            for g in steps {
                for b in steps {
                    let out = ColorBlindnessSimulator.simulate(red: r, green: g, blue: b, mode: mode)
                    #expect((0...1).contains(out.r) && (0...1).contains(out.g) && (0...1).contains(out.b))
                }
            }
        }
    }

    @Test func outOfRangeInputIsClampedOnOutput() {
        let out = ColorBlindnessSimulator.simulate(red: 1.5, green: -0.2, blue: 2, mode: .protanopia)
        #expect(out.r <= 1 && out.g >= 0 && out.b <= 1)
    }

    @Test("Alpha survives simulation", arguments: ColorBlindnessMode.allCases)
    func alphaIsPreserved(mode: ColorBlindnessMode) {
        let color = RGBA(red: 0.4, green: 0.2, blue: 0.7, alpha: 0.33)
        #expect(ColorBlindnessSimulator.simulate(color, mode: mode).alpha == 0.33)
    }

    @Test func modeMetadata() {
        #expect(ColorBlindnessMode.allCases.count == 5)
        #expect(!ColorBlindnessMode.off.isActive)
        #expect(ColorBlindnessMode.allCases.filter(\.isActive).count == 4)
        #expect(Set(ColorBlindnessMode.allCases.map(\.id)).count == 5)
        #expect(ColorBlindnessMode.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}
