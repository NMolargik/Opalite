import Testing
@testable import OpaliteFeatureSettings

@Suite("OpaliteFeatureSettings placeholder")
struct OpaliteFeatureSettingsPlaceholderTests {
    @Test func moduleLinks() { #expect(OpaliteFeatureSettingsModule.name == "OpaliteFeatureSettings") }
}
