import Testing
@testable import OpaliteFeatureSwatchBar

@Suite("OpaliteFeatureSwatchBar placeholder")
struct OpaliteFeatureSwatchBarPlaceholderTests {
    @Test func moduleLinks() { #expect(OpaliteFeatureSwatchBarModule.name == "OpaliteFeatureSwatchBar") }
}
