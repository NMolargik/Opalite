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
}
