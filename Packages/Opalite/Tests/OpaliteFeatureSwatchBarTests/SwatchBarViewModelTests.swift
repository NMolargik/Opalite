//
//  SwatchBarViewModelTests.swift
//  OpaliteFeatureSwatchBarTests
//
//  Host tests for the SwatchBar's state: section building and filtering, collapsing,
//  quick-add hex validation and creation, and swatch-size cycling/persistence.
//

import Foundation
import Testing
import OpaliteCore
import OpaliteFeatureShared
@testable import OpaliteFeatureSwatchBar

@MainActor
@Suite("SwatchBar view model")
struct SwatchBarViewModelTests {

    private func makeModel(_ env: PreviewEnvironment) -> SwatchBarViewModel {
        SwatchBarViewModel(defaults: env.defaults)
    }

    // MARK: - Sections

    @Test("Seeded portfolio yields the sample palette then the loose colors")
    func sectionsFromSeededPortfolio() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        let sections = model.sections(from: env.portfolio)

        #expect(sections.count == 2)
        #expect(sections.first?.title == OpalitePalette.sample.name)
        #expect(sections.first?.count == OpalitePalette.sample.colorCount)
        #expect(sections.last?.kind == .loose)
        #expect(sections.last?.count == env.portfolio.looseColors.count)
        #expect(model.visibleColorCount(in: env.portfolio) == env.portfolio.colors.count)
    }

    @Test("Empty portfolio yields no sections")
    func sectionsFromEmptyPortfolio() {
        let env = PreviewEnvironment(seeded: false)
        let model = makeModel(env)

        #expect(model.sections(from: env.portfolio).isEmpty)
        #expect(model.visibleColorCount(in: env.portfolio) == 0)
    }

    @Test("Palettes without colors are skipped")
    func emptyPalettesAreSkipped() {
        let env = PreviewEnvironment(seeded: false)
        env.portfolio.createPalette(name: "Empty")
        env.portfolio.createColor(RGBA(red: 0.1, green: 0.2, blue: 0.3), name: "Loose")
        let model = makeModel(env)

        let sections = model.sections(from: env.portfolio)

        #expect(sections.count == 1)
        #expect(sections.first?.kind == .loose)
    }

    // MARK: - Filtering

    @Test("Searching by name keeps only matching loose colors")
    func searchFiltersLooseColors() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.query = "moss"

        let sections = model.sections(from: env.portfolio)
        #expect(sections.count == 1)
        #expect(sections.first?.kind == .loose)
        #expect(sections.first?.colors.map(\.name) == ["Moss"])
    }

    @Test("Searching by hex finds a color with or without the prefix")
    func searchFiltersByHex() {
        let env = PreviewEnvironment(seeded: false)
        env.portfolio.createColor(RGBA(red: 1, green: 0, blue: 0), name: "Red")
        env.portfolio.createColor(RGBA(red: 0, green: 0, blue: 1), name: "Blue")
        let model = makeModel(env)

        model.query = "#FF0000"
        #expect(model.sections(from: env.portfolio).first?.colors.map(\.name) == ["Red"])

        model.query = "0000ff"
        #expect(model.sections(from: env.portfolio).first?.colors.map(\.name) == ["Blue"])
    }

    @Test("A palette whose name matches keeps all of its colors")
    func paletteNameMatchKeepsEveryColor() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.query = OpalitePalette.sample.name

        let sections = model.sections(from: env.portfolio)
        #expect(sections.count == 1)
        #expect(sections.first?.count == OpalitePalette.sample.colorCount)
    }

    @Test("A query with no matches yields no sections")
    func searchWithNoMatches() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.query = "zzzz-not-a-color"

        #expect(model.isSearching)
        #expect(model.sections(from: env.portfolio).isEmpty)
    }

    @Test("Whitespace-only queries are not searches")
    func whitespaceQueryIsNotSearching() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.query = "   "

        #expect(!model.isSearching)
        #expect(model.sections(from: env.portfolio).count == 2)
    }

    // MARK: - Collapsing

    @Test("Sections start expanded and toggle individually")
    func toggleSection() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        let paletteKind = SwatchBarSection.Kind.palette(env.paletteRepository.storage[0].id)

        #expect(model.isExpanded(.loose))
        model.toggle(.loose)
        #expect(!model.isExpanded(.loose))
        #expect(model.isExpanded(paletteKind), "Other sections are untouched")
        model.toggle(.loose)
        #expect(model.isExpanded(.loose))
    }

    @Test("Toggle all collapses everything, then expands everything")
    func toggleAll() {
        let env = PreviewEnvironment()
        let model = makeModel(env)
        let kinds = model.sections(from: env.portfolio).map(\.kind)

        #expect(model.allExpanded(in: env.portfolio))
        model.toggleAll(in: env.portfolio)
        #expect(!model.allExpanded(in: env.portfolio))
        #expect(kinds.allSatisfy { !model.isExpanded($0) })

        model.toggleAll(in: env.portfolio)
        #expect(model.allExpanded(in: env.portfolio))
    }

    @Test("Toggle all with a mix open expands the rest")
    func toggleAllFromMixedState() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.toggle(.loose)
        model.toggleAll(in: env.portfolio)

        #expect(model.allExpanded(in: env.portfolio))
    }

    @Test("Searching forces collapsed sections open without forgetting the collapse")
    func searchingOverridesCollapse() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.toggle(.loose)
        model.query = "moss"
        #expect(model.isExpanded(.loose))

        model.query = ""
        #expect(!model.isExpanded(.loose))
    }

    // MARK: - Swatch size

    @Test("Swatch size cycles through every case and wraps")
    func swatchSizeCycles() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        #expect(model.swatchSize == .regular)
        model.cycleSwatchSize()
        #expect(model.swatchSize == .large)
        model.cycleSwatchSize()
        #expect(model.swatchSize == .compact)
        model.cycleSwatchSize()
        #expect(model.swatchSize == .regular)
    }

    @Test("Swatch size persists through the key-value store")
    func swatchSizePersists() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.cycleSwatchSize()
        let restored = SwatchBarViewModel(defaults: env.defaults)

        #expect(restored.swatchSize == model.swatchSize)
        #expect(env.defaults.string(forKey: SwatchBarViewModel.Keys.swatchSize) == model.swatchSize.rawValue)
    }

    @Test("Unknown stored sizes fall back to regular")
    func unknownStoredSizeFallsBack() {
        let env = PreviewEnvironment()
        env.defaults.set("gigantic", forKey: SwatchBarViewModel.Keys.swatchSize)

        #expect(SwatchBarViewModel(defaults: env.defaults).swatchSize == .regular)
    }

    @Test("Only compact hides overlays; only large shows hex in the badge")
    func swatchSizeTraits() {
        #expect(!SwatchBarSwatchSize.compact.showsOverlays)
        #expect(SwatchBarSwatchSize.regular.showsOverlays)
        #expect(SwatchBarSwatchSize.large.showsOverlays)
        #expect(SwatchBarSwatchSize.large.showsHexInBadge)
        #expect(!SwatchBarSwatchSize.regular.showsHexInBadge)
        #expect(SwatchBarSwatchSize.compact.height == nil)
        #expect(SwatchBarSwatchSize.allCases.map(\.minimumSide) == SwatchBarSwatchSize.allCases.map(\.minimumSide).sorted())
    }

    // MARK: - Quick add validation

    @Test("Quick-add validation", arguments: [
        ("", SwatchBarQuickAddState.empty),
        ("   ", .empty),
        ("#", .incomplete),
        ("4A9", .valid(RGBA(red: 0x44 / 255, green: 0xAA / 255, blue: 0x99 / 255), hex: "#44AA99", duplicateOf: nil)),
        ("4A90E", .incomplete),
        ("#4A90E2", .valid(RGBA(red: 0x4A / 255, green: 0x90 / 255, blue: 0xE2 / 255), hex: "#4A90E2", duplicateOf: nil)),
        ("4a90e2", .valid(RGBA(red: 0x4A / 255, green: 0x90 / 255, blue: 0xE2 / 255), hex: "#4A90E2", duplicateOf: nil)),
        ("4A90E280", .valid(RGBA(red: 0x4A / 255, green: 0x90 / 255, blue: 0xE2 / 255, alpha: 0x80 / 255), hex: "#4A90E280", duplicateOf: nil)),
        ("GG0000", .invalid),
        ("#12 34", .invalid),
        ("hello", .invalid),
    ])
    func quickAddValidation(input: String, expected: SwatchBarQuickAddState) {
        #expect(SwatchBarViewModel.quickAddState(for: input) == expected)
    }

    @Test("Quick-add flags an existing color with the same hex")
    func quickAddDetectsDuplicates() {
        let env = PreviewEnvironment(seeded: false)
        env.portfolio.createColor(RGBA(red: 1, green: 0, blue: 0), name: "Signal Red")
        let model = makeModel(env)

        model.quickAddText = "ff0000"
        #expect(model.quickAddState(in: env.portfolio) == .valid(RGBA(red: 1, green: 0, blue: 0), hex: "#FF0000", duplicateOf: "Signal Red"))

        model.quickAddText = "00ff00"
        #expect(model.quickAddState(in: env.portfolio) == .valid(RGBA(red: 0, green: 1, blue: 0), hex: "#00FF00", duplicateOf: nil))
    }

    @Test("Quick-add text is capped at a prefix plus eight digits")
    func quickAddTextIsCapped() {
        let env = PreviewEnvironment()
        let model = makeModel(env)

        model.quickAddText = "#4A90E280FFFF"

        #expect(model.quickAddText == "#4A90E280")
        #expect(model.quickAddText.count == SwatchBarViewModel.maximumHexLength)
    }

    // MARK: - Quick add submission

    @Test("Submitting a valid hex creates a loose color and clears the field")
    func submitQuickAddCreatesColor() {
        let env = PreviewEnvironment(seeded: false)
        let model = makeModel(env)
        model.quickAddText = "#4A90E2"

        let created = model.submitQuickAdd(into: env.portfolio)

        #expect(created != nil)
        #expect(created?.hexString == "#4A90E2")
        #expect(created?.palette == nil)
        #expect(model.quickAddText.isEmpty)
        #expect(env.portfolio.looseColors.count == 1)
        #expect(model.sections(from: env.portfolio).first?.kind == .loose)
    }

    @Test("Submitting an incomplete or invalid hex does nothing")
    func submitQuickAddRejectsBadInput() {
        let env = PreviewEnvironment(seeded: false)
        let model = makeModel(env)

        model.quickAddText = "4A90E"
        #expect(model.submitQuickAdd(into: env.portfolio) == nil)
        #expect(model.quickAddText == "4A90E")

        model.quickAddText = "nope"
        #expect(model.submitQuickAdd(into: env.portfolio) == nil)
        #expect(env.portfolio.colors.isEmpty)
    }

    @Test("Submitting an eight-digit hex keeps the alpha")
    func submitQuickAddKeepsAlpha() {
        let env = PreviewEnvironment(seeded: false)
        let model = makeModel(env)
        model.quickAddText = "FF000080"

        let created = model.submitQuickAdd(into: env.portfolio)

        #expect(created?.hexWithAlphaString == "#FF000080")
        #expect(abs((created?.alpha ?? 0) - 0x80 / 255) < 0.001)
    }
}
