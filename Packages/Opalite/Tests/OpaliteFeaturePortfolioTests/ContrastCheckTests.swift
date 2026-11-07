import Foundation
import Testing
import OpaliteCore
@testable import OpaliteFeaturePortfolio

@Suite("ContrastCheck — APCA and suggested fix")
struct ContrastCheckAPCATests {
    @Test func apcaNeedsAComparison() {
        let check = ContrastCheck(source: .black)
        #expect(check.apcaSourceAsText == nil && check.suggestedFix == nil)
    }

    @Test func apcaIsPolarityAware() throws {
        let check = ContrastCheck(source: .black, comparison: .white)
        #expect(try #require(check.apcaSourceAsText) > 100)
        #expect(try #require(check.apcaTextOnSource) < -100)
    }

    @Test func suggestedFixReachesAA() throws {
        let check = ContrastCheck(source: RGBA(hex: "#9AA0F0")!, comparison: .white)
        let fix = try #require(check.suggestedFix)
        #expect(fix.contrastRatio(against: .white) >= 4.5)
        #expect(ContrastCheck(source: .black, comparison: .white).suggestedFix == nil)
    }
}
