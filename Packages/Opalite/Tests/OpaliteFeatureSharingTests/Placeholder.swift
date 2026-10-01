import Testing
@testable import OpaliteFeatureSharing

@Suite("OpaliteFeatureSharing placeholder")
struct OpaliteFeatureSharingPlaceholderTests {
    @Test func moduleLinks() { #expect(OpaliteFeatureSharingModule.name == "OpaliteFeatureSharing") }
}
