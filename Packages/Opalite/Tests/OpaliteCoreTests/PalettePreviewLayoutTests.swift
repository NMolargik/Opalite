//
//  PalettePreviewLayoutTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("PalettePreviewLayout")
struct PalettePreviewLayoutTests {
    @Test func emptyWhenNothingToShowOrNoRoom() {
        #expect(PalettePreviewLayout.calculate(colorCount: 0, availableWidth: 100, availableHeight: 100) == .empty)
        #expect(PalettePreviewLayout.calculate(colorCount: 3, availableWidth: 0, availableHeight: 100) == .empty)
        #expect(PalettePreviewLayout.calculate(colorCount: 3, availableWidth: 100, availableHeight: 0) == .empty)
        #expect(PalettePreviewLayout.empty.rows == 0 && PalettePreviewLayout.empty.columns == 0)
    }

    @Test func singleColorFillsTheArea() {
        let layout = PalettePreviewLayout.calculate(colorCount: 1, availableWidth: 100, availableHeight: 80)
        #expect(layout.rows == 1 && layout.columns == 1)
        #expect(layout.swatchSize == 80)
        #expect(layout.horizontalSpacing == 0 && layout.verticalSpacing == 0)
    }

    @Test func tallAreaPrefersTwoRows() {
        let layout = PalettePreviewLayout.calculate(colorCount: 2, availableWidth: 100, availableHeight: 100)
        #expect(layout.rows == 2 && layout.columns == 1)
        #expect(layout.swatchSize == 47)
        #expect(layout.verticalSpacing == 6)
        #expect(layout.horizontalSpacing == 0)
    }

    @Test func wideAreaPrefersOneRow() {
        let layout = PalettePreviewLayout.calculate(colorCount: 6, availableWidth: 600, availableHeight: 100)
        #expect(layout.rows == 1 && layout.columns == 6)
        #expect(layout.swatchSize == 90)
        #expect(layout.horizontalSpacing == 12, "spacing grows up to maxSpacing")
        #expect(layout.verticalSpacing == 0)
    }

    @Test func horizontalSpacingIsCappedAtMax() {
        let layout = PalettePreviewLayout.calculate(colorCount: 2, availableWidth: 1000, availableHeight: 50, maxSpacing: 20)
        #expect(layout.swatchSize == 50)
        #expect(layout.horizontalSpacing == 20)
    }

    @Test func maxRowsIsHonored() {
        let layout = PalettePreviewLayout.calculate(colorCount: 9, availableWidth: 100, availableHeight: 1000, maxRows: 3)
        #expect(layout.rows == 3 && layout.columns == 3)
        let capped = PalettePreviewLayout.calculate(colorCount: 9, availableWidth: 100, availableHeight: 1000, maxRows: 1)
        #expect(capped.rows == 1 && capped.columns == 9)
    }

    @Test func hexBadgeThreshold() {
        let big = PalettePreviewLayout.calculate(colorCount: 6, availableWidth: 600, availableHeight: 100, hexBadgeMinSize: 50)
        #expect(big.showHexBadges)
        let small = PalettePreviewLayout.calculate(colorCount: 6, availableWidth: 600, availableHeight: 100, hexBadgeMinSize: 100)
        #expect(!small.showHexBadges)
        let none = PalettePreviewLayout.calculate(colorCount: 6, availableWidth: 600, availableHeight: 100)
        #expect(!none.showHexBadges)
    }

    @Test func gridIndexing() {
        let layout = PalettePreviewLayout.calculate(colorCount: 5, availableWidth: 300, availableHeight: 300)
        #expect(layout.rows == 2 && layout.columns == 3)
        #expect(layout.index(row: 0, column: 0, colorCount: 5) == 0)
        #expect(layout.index(row: 1, column: 1, colorCount: 5) == 4)
        #expect(layout.index(row: 1, column: 2, colorCount: 5) == nil)
    }

    @Test func swatchesNeverOverflowTheArea() {
        for count in 1...12 {
            let layout = PalettePreviewLayout.calculate(colorCount: count, availableWidth: 320, availableHeight: 140)
            let width = CGFloat(layout.columns) * layout.swatchSize + CGFloat(layout.columns - 1) * layout.horizontalSpacing
            let height = CGFloat(layout.rows) * layout.swatchSize + CGFloat(layout.rows - 1) * layout.verticalSpacing
            #expect(width <= 320.0001 && height <= 140.0001)
            #expect(layout.rows * layout.columns >= count)
        }
    }
}
