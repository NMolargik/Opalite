import Testing
@testable import OpaliteCore

@Suite("OpaliteCore placeholder")
struct OpaliteCorePlaceholderTests {
    @Test func moduleLinks() {
        #expect(AppGroup.id == "group.com.molargiksoftware.Opalite")
    }
}
