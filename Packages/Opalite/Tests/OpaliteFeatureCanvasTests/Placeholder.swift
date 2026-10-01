import Testing
@testable import OpaliteFeatureCanvas

@Suite("OpaliteFeatureCanvas placeholder")
struct OpaliteFeatureCanvasPlaceholderTests {
    @Test func moduleLinks() { #expect(OpaliteFeatureCanvasModule.name == "OpaliteFeatureCanvas") }
}
