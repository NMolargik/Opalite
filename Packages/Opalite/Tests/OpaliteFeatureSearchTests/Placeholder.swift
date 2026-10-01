import Testing
@testable import OpaliteFeatureSearch

@Suite("OpaliteFeatureSearch placeholder")
struct OpaliteFeatureSearchPlaceholderTests {
    @Test func moduleLinks() { #expect(OpaliteFeatureSearchModule.name == "OpaliteFeatureSearch") }
}
