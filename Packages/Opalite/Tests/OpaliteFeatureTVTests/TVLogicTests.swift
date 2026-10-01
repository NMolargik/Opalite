//
//  TVLogicTests.swift
//  OpaliteFeatureTVTests
//
//  Host tests for the platform-free parts of the TV feature.
//

import Foundation
import Testing
import OpaliteCore
@testable import OpaliteFeatureTV

@Suite("TVPresentationDeck")
struct TVPresentationDeckTests {
    private let colors = [
        TVPresentedColor(name: "One", rgba: .black),
        TVPresentedColor(name: nil, rgba: .white),
        TVPresentedColor(name: "  ", rgba: RGBA(red: 1, green: 0, blue: 0)),
    ]

    @Test func clampsStartIndex() {
        #expect(TVPresentationDeck(colors: colors, startIndex: 99).index == 2)
        #expect(TVPresentationDeck(colors: colors, startIndex: -4).index == 0)
        #expect(TVPresentationDeck(colors: [], startIndex: 3).index == 0)
        #expect(TVPresentationDeck(colors: []).current == nil)
    }

    @Test func stepsWrapAround() {
        var deck = TVPresentationDeck(colors: colors)
        deck.previous()
        #expect(deck.index == 2)
        deck.next()
        #expect(deck.index == 0)
        deck.next(); deck.next(); deck.next()
        #expect(deck.index == 0)
    }

    @Test func singleColorDoesNotStep() {
        var deck = TVPresentationDeck(colors: [colors[0]])
        deck.next(); deck.previous()
        #expect(deck.index == 0)
        #expect(deck.hasMultiple == false)
        #expect(deck.positionDescription == nil)
    }

    @Test func positionDescribesOneBasedIndex() {
        var deck = TVPresentationDeck(colors: colors)
        deck.next()
        #expect(deck.positionDescription == "2 of 3")
    }

    @Test func titleFallsBackToHexForBlankNames() {
        #expect(colors[0].title == "One")
        #expect(colors[1].title == RGBA.white.hexString)
        #expect(colors[2].title == RGBA(red: 1, green: 0, blue: 0).hexString)
        #expect(colors[2].hasName == false)
    }
}

@Suite("TVDrift")
struct TVDriftTests {
    @Test func highlightStaysAwayFromEdges() {
        for step in 0..<400 {
            let c = TVDrift.highlightCenter(at: Double(step) * 1.7)
            #expect(c.x > 0.2 && c.x < 0.8)
            #expect(c.y > 0.2 && c.y < 0.8)
        }
    }

    @Test func labelOffsetIsBoundedByAmplitude() {
        for step in 0..<400 {
            let o = TVDrift.labelOffset(at: Double(step) * 0.9, amplitude: 18)
            #expect(abs(o.x) <= 18.0001)
            #expect(abs(o.y) <= 18.0001)
        }
        #expect(TVDrift.labelOffset(at: 0).x == 0)
    }
}

@Suite("TVHexInput")
struct TVHexInputTests {
    @Test func normalizesTypedText() {
        #expect(TVHexInput.normalized("") == "#")
        #expect(TVHexInput.normalized("ff5733") == "#FF5733")
        #expect(TVHexInput.normalized("##f-f 57 zz33") == "#FF5733")
        #expect(TVHexInput.normalized("#123456789ABC") == "#12345678")
    }

    @Test func parsesOnlyCompleteCodes() {
        #expect(TVHexInput.parse("#") == nil)
        #expect(TVHexInput.parse("#FF573") == nil) // 5 digits is never valid; 3/4/6/8 are
        #expect(TVHexInput.parse("#FFF") == RGBA(red: 1, green: 1, blue: 1))
        #expect(TVHexInput.parse("#000000")?.hexString == "#000000")
    }

    @Test func cleansNames() {
        #expect(TVHexInput.cleanName("   ") == nil)
        #expect(TVHexInput.cleanName("  Sunset ") == "Sunset")
    }
}

@Suite("TVOLEDRefreshCycle")
struct TVOLEDRefreshCycleTests {
    @Test func standardCycleCoversPrimariesAndWraps() {
        let cycle = TVOLEDRefreshCycle.standard
        #expect(cycle.steps.count == 11)
        #expect(cycle.step(at: 0)?.rgba == RGBA(red: 1, green: 0, blue: 0))
        #expect(cycle.step(at: cycle.steps.count)?.rgba == cycle.steps[0].rgba)
        #expect(cycle.step(at: -1)?.rgba == .black)
        #expect(cycle.nextIndex(after: cycle.steps.count - 1) == 0)
        #expect(cycle.nextIndex(after: 3) == 4)
    }

    @Test func emptyCycleIsSafe() {
        let cycle = TVOLEDRefreshCycle(steps: [])
        #expect(cycle.step(at: 0) == nil)
        #expect(cycle.nextIndex(after: 5) == 0)
    }
}

@Suite("TVSearchScope")
struct TVSearchScopeTests {
    @Test func scopesIncludeTheRightKinds() {
        #expect(TVSearchScope.all.includesColors && TVSearchScope.all.includesPalettes)
        #expect(TVSearchScope.colors.includesColors && !TVSearchScope.colors.includesPalettes)
        #expect(!TVSearchScope.palettes.includesColors && TVSearchScope.palettes.includesPalettes)
    }
}
