import Testing
import Foundation
@testable import OpaliteCore

@Suite("Grid columns")
struct GridColumnsTests {
    @Test func countsColumnsThatFitWithSpacing() {
        // Three 100-point columns and two 10-point gaps need 320 points.
        #expect(GridColumns.count(fitting: 320, minimum: 100, spacing: 10) == 3)
        #expect(GridColumns.count(fitting: 319, minimum: 100, spacing: 10) == 2)
        #expect(GridColumns.count(fitting: 50, minimum: 100, spacing: 10) == 1)
    }

    @Test func zeroOrUnmeasuredWidthIsOneColumn() {
        #expect(GridColumns.count(fitting: 0, minimum: 100, spacing: 10) == 1)
        #expect(GridColumns.count(fitting: 500, minimum: 0, spacing: 10) == 1)
    }

    @Test func preferEvenDropsOddCountsAboveOne() {
        #expect(GridColumns.count(fitting: 320, minimum: 100, spacing: 10, preferEven: true) == 2)
        #expect(GridColumns.count(fitting: 430, minimum: 100, spacing: 10, preferEven: true) == 4)
        #expect(GridColumns.count(fitting: 100, minimum: 100, spacing: 10, preferEven: true) == 1, "one column stays one")
    }

    @Test func avoidsALoneTileOnTheLastRow() {
        // 5 fit at 100pt; 6 items would leave one alone, and 6 fit at the relaxed 80pt.
        #expect(GridColumns.count(fitting: 540, minimum: 100, spacing: 10, items: 6) == 6)
        // Too narrow to relax: four items in 3 columns become 2 x 2.
        #expect(GridColumns.count(fitting: 320, minimum: 100, spacing: 10, items: 4) == 2)
        // Already fine.
        #expect(GridColumns.count(fitting: 540, minimum: 100, spacing: 10, items: 13) == 5)
    }
}
