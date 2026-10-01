//
//  ImmersiveColorModelTests.swift
//  OpaliteFeatureImmersiveTests
//
//  Host tests for the RealityKit-free parts of the immersive feature: the model that the
//  shell prepares before opening the space, and the scene geometry the view assembles from.
//

import Foundation
import Testing
import OpaliteCore
@testable import OpaliteFeatureImmersive

@Suite("ImmersiveColorModel")
struct ImmersiveColorModelTests {

    private let hero = RGBA(red: 0.2, green: 0.5, blue: 0.8)

    @Test func startsEmptyAndNotImmersed() {
        let model = ImmersiveColorModel()
        #expect(model.colors.isEmpty)
        #expect(model.mode == .singleColor)
        #expect(model.isImmersed == false)
        #expect(model.hasContent == false)
        #expect(model.heroColor == nil)
    }

    @Test func singleColorPreparesHeroPlusSixHarmonies() {
        let model = ImmersiveColorModel()
        model.prepareForSingleColor(hero)

        #expect(model.mode == .singleColor)
        #expect(model.colors.count == 7)
        #expect(model.heroColor == hero)
        #expect(model.harmonyColors.count == 6)

        let expected: [RGBA] = [hero, ColorHarmony.complementary(of: hero)]
            + ColorHarmony.analogous(of: hero)
            + ColorHarmony.splitComplementary(of: hero)
            + [ColorHarmony.triadic(of: hero)[0]]
        #expect(model.colors == expected)
    }

    @Test func singleColorOrderIsHeroComplementaryAnalogousSplitTriadic() {
        let set = ImmersiveColorModel.singleColorSet(for: hero)
        #expect(set[0] == hero)
        #expect(set[1] == ColorHarmony.rotated(hero, by: 180))
        #expect(set[2] == ColorHarmony.rotated(hero, by: -30))
        #expect(set[3] == ColorHarmony.rotated(hero, by: 30))
        #expect(set[4] == ColorHarmony.rotated(hero, by: 150))
        #expect(set[5] == ColorHarmony.rotated(hero, by: 210))
        #expect(set[6] == ColorHarmony.rotated(hero, by: 120))
    }

    @Test func palettePreparesEqualColorsAndNoHarmonies() {
        let model = ImmersiveColorModel()
        let palette: [RGBA] = [.black, .white, hero]
        model.prepareForPalette(palette)

        #expect(model.mode == .palette)
        #expect(model.colors == palette)
        #expect(model.heroColor == .black)
        #expect(model.harmonyColors.isEmpty)
        #expect(model.hasContent)
    }

    @Test func switchingModesReplacesColors() {
        let model = ImmersiveColorModel()
        model.prepareForPalette([.white, .black])
        model.prepareForSingleColor(hero)
        #expect(model.mode == .singleColor)
        #expect(model.colors.count == 7)

        model.prepareForPalette([])
        #expect(model.mode == .palette)
        #expect(model.colors.isEmpty)
        #expect(model.hasContent == false)
    }
}

@Suite("ImmersiveSceneLayout")
struct ImmersiveSceneLayoutTests {

    @Test func panelWidthClosesTheRing() {
        // The chord of each slice, plus the seam allowance.
        let count = 8
        let chord = 2 * ImmersiveSceneLayout.ringRadius * sin(Float.pi / Float(count))
        #expect(abs(ImmersiveSceneLayout.panelWidth(count: count) - (chord + 0.02)) < 0.0001)
        #expect(ImmersiveSceneLayout.panelWidth(count: 0) == 0)
        #expect(ImmersiveSceneLayout.panelWidth(count: 1) > ImmersiveSceneLayout.ringRadius * 6)
    }

    @Test func panelsSitOnTheRingAtEyeHeight() {
        let count = 6
        for index in 0..<count {
            let p = ImmersiveSceneLayout.panelPosition(index: index, count: count)
            let distance = (p.x * p.x + p.z * p.z).squareRoot()
            #expect(abs(distance - ImmersiveSceneLayout.ringRadius) < 0.0001)
            #expect(p.y == ImmersiveSceneLayout.eyeHeight)
        }
        // Index 0 is straight ahead (−Z).
        let first = ImmersiveSceneLayout.panelPosition(index: 0, count: count)
        #expect(abs(first.x) < 0.0001)
        #expect(first.z < 0)
    }

    @Test func orbsSpreadAcrossTheArcInFront() {
        let count = 6
        let positions = (0..<count).map { ImmersiveSceneLayout.orbPosition(index: $0, count: count) }
        for p in positions {
            #expect(p.z < 0) // always ahead of the viewer
            let distance = (p.x * p.x + p.z * p.z).squareRoot()
            #expect(abs(distance - ImmersiveSceneLayout.orbRingRadius) < 0.0001)
        }
        #expect(positions.first!.x < 0)
        #expect(positions.last!.x > 0)
        #expect(abs(positions.first!.x + positions.last!.x) < 0.0001) // symmetric
        #expect(Set(positions).count == count) // no two orbs share a spot
    }

    @Test func singleOrbSitsStraightAhead() {
        let p = ImmersiveSceneLayout.orbPosition(index: 0, count: 1)
        #expect(abs(p.x) < 0.0001)
        #expect(abs(p.z + ImmersiveSceneLayout.orbRingRadius) < 0.0001)
    }

    @Test func rotationCompletesOneRevolutionPerPeriod() {
        #expect(ImmersiveSceneLayout.rotationAngle(at: 0) == 0)
        let quarter = ImmersiveSceneLayout.rotationAngle(at: ImmersiveSceneLayout.rotationPeriod / 4)
        #expect(abs(quarter - .pi / 2) < 0.0001)
        let wrapped = ImmersiveSceneLayout.rotationAngle(at: ImmersiveSceneLayout.rotationPeriod)
        #expect(abs(wrapped) < 0.0001)
    }

    @Test func bobStaysWithinAmplitudeAndIsPhaseShifted() {
        for index in 0..<6 {
            for step in 0..<20 {
                let t = Double(step) * 0.37
                #expect(abs(ImmersiveSceneLayout.bobOffset(at: t, index: index)) <= ImmersiveSceneLayout.bobAmplitude + 0.0001)
            }
        }
        #expect(ImmersiveSceneLayout.bobOffset(at: 0, index: 0) != ImmersiveSceneLayout.bobOffset(at: 0, index: 1))
    }

    @Test func averageIsTheMeanAndBlackWhenEmpty() {
        let mean = ImmersiveSceneLayout.average([.black, .white])
        #expect(abs(mean.red - 0.5) < 0.0001)
        #expect(abs(mean.green - 0.5) < 0.0001)
        #expect(abs(mean.blue - 0.5) < 0.0001)
        #expect(ImmersiveSceneLayout.average([]) == .black)
    }

    @Test func capsBracketThePanels() {
        #expect(ImmersiveSceneLayout.floorHeight < ImmersiveSceneLayout.eyeHeight)
        #expect(ImmersiveSceneLayout.ceilingHeight > ImmersiveSceneLayout.eyeHeight)
        #expect(ImmersiveSceneLayout.ceilingHeight - ImmersiveSceneLayout.floorHeight == ImmersiveSceneLayout.panelHeight)
        #expect(ImmersiveSceneLayout.capSide() > ImmersiveSceneLayout.ringRadius * 2)
    }
}
