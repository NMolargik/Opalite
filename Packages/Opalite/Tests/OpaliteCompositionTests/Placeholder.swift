import Testing
@testable import OpaliteComposition

@Suite("OpaliteComposition placeholder")
struct OpaliteCompositionPlaceholderTests {
    @Test func moduleLinks() { #expect(SwatchBarScene.windowID == "swatchBar") }
}
