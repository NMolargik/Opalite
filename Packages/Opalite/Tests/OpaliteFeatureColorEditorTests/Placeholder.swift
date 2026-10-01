import Testing
@testable import OpaliteFeatureColorEditor

@Suite("OpaliteFeatureColorEditor placeholder")
struct OpaliteFeatureColorEditorPlaceholderTests {
    @Test func moduleLinks() { #expect(OpaliteFeatureColorEditorModule.name == "OpaliteFeatureColorEditor") }
}
