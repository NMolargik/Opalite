import Testing
@testable import OpaliteFeaturePortfolio

@Suite("OpaliteFeaturePortfolio placeholder")
struct OpaliteFeaturePortfolioPlaceholderTests {
    @Test func moduleLinks() { #expect(OpaliteFeaturePortfolioModule.name == "OpaliteFeaturePortfolio") }
}
