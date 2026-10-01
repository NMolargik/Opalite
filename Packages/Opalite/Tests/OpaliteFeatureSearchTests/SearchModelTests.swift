import Foundation
import Testing
import OpaliteCore
@testable import OpaliteFeatureSearch

@Suite("Search engine")
struct SearchEngineTests {
    private let navy = SearchableColor(id: UUID(), name: "Navy", notes: "Header background", rgba: RGBA(red: 0.1, green: 0.15, blue: 0.4), updatedAt: Date(timeIntervalSince1970: 100))
    private let coral = SearchableColor(id: UUID(), name: "Coral", notes: nil, rgba: RGBA(red: 1, green: 0.5, blue: 0.4), updatedAt: Date(timeIntervalSince1970: 300))
    private let unnamed = SearchableColor(id: UUID(), name: nil, notes: nil, rgba: RGBA(red: 0.2, green: 0.5, blue: 0.8), updatedAt: Date(timeIntervalSince1970: 200))
    private let brand = SearchablePalette(id: UUID(), name: "Brand", notes: "Primary set", tags: ["web", "2026"], colorValues: [])
    private let moody = SearchablePalette(id: UUID(), name: "Moody", notes: nil, tags: [], colorValues: [])

    private var colors: [SearchableColor] { [navy, coral, unnamed] }
    private var palettes: [SearchablePalette] { [brand, moody] }

    @Test func blankQueryHasNoResults() {
        #expect(SearchEngine.isBlank("   "))
        #expect(SearchEngine.results(query: " ", colors: colors, palettes: palettes).isEmpty)
    }

    @Test func matchesNamesNotesHexTagsAndFamilies() {
        let byName = SearchEngine.results(query: "cor", colors: colors, palettes: palettes)
        #expect(byName.colors.map(\.id) == [coral.id])
        let byNotes = SearchEngine.results(query: "header", colors: colors, palettes: palettes)
        #expect(byNotes.colors.map(\.id) == [navy.id])
        let byHex = SearchEngine.results(query: unnamed.hex.lowercased(), colors: colors, palettes: palettes)
        #expect(byHex.colors.map(\.id) == [unnamed.id])
        let byTag = SearchEngine.results(query: "web", colors: colors, palettes: palettes)
        #expect(byTag.palettes.map(\.id) == [brand.id])
        let byFamily = SearchEngine.results(query: "dark blue", colors: colors, palettes: palettes)
        #expect(byFamily.colors.contains { $0.id == navy.id })
        #expect(!byFamily.colors.contains { $0.id == coral.id })
    }

    @Test func groupsColorsAndPalettesTogether() {
        let results = SearchEngine.results(query: "o", colors: colors, palettes: palettes)
        #expect(results.colors.contains { $0.id == coral.id })
        #expect(results.palettes.contains { $0.id == moody.id })
        #expect(results.count == results.colors.count + results.palettes.count)
    }

    @Test func recentColorsAreNewestFirstAndCapped() {
        let recent = SearchEngine.recentColors(colors, limit: 2)
        #expect(recent.map(\.id) == [coral.id, unnamed.id])
    }

    @Test func familySuggestionsReflectThePortfolio() {
        let families = SearchEngine.familySuggestions(for: colors)
        #expect(families.contains("dark blue"))
        #expect(families.contains { $0.hasSuffix("blue") || $0.hasSuffix("orange") || $0.hasSuffix("red") || $0.hasSuffix("pink") })
        #expect(SearchEngine.familySuggestions(for: []).isEmpty)
        let completions = SearchEngine.completions(for: "da", families: families)
        #expect(completions.allSatisfy { $0.hasPrefix("da") })
        #expect(SearchEngine.completions(for: "", families: families).isEmpty)
    }

    @Test func suggestionChipsOrderRecentThenFamilies() {
        let chips = SearchEngine.suggestions(recentQueries: ["coral"], families: ["blue"])
        #expect(chips.map(\.kind) == [.recent, .family])
        #expect(chips.map(\.text) == ["coral", "blue"])
        #expect(Set(chips.map(\.id)).count == 2)
    }
}

@Suite("Recent searches")
struct RecentSearchesTests {
    @Test func recordsNewestFirstDeduplicatedAndCapped() {
        var recent = RecentSearches()
        recent.record("  ")
        #expect(recent.queries.isEmpty)
        recent.record("blue")
        recent.record("coral")
        recent.record("Blue")
        #expect(recent.queries == ["Blue", "coral"])
        for i in 0..<10 { recent.record("q\(i)", limit: 3) }
        #expect(recent.queries.count == 3)
        #expect(recent.queries.first == "q9")
    }

    @Test func roundTripsThroughData() {
        var recent = RecentSearches()
        recent.record("navy")
        let decoded = RecentSearches.decode(recent.encoded())
        #expect(decoded == recent)
        #expect(RecentSearches.decode(nil).queries.isEmpty)
        #expect(RecentSearches.decode(Data("garbage".utf8)).queries.isEmpty)
    }

    @Test func removeAndClear() {
        var recent = RecentSearches(queries: ["a", "b"])
        recent.remove("a")
        #expect(recent.queries == ["b"])
        recent.clear()
        #expect(recent.queries.isEmpty)
    }
}
