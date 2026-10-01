import Foundation
import Testing
import OpaliteCore
@testable import OpaliteFeaturePortfolio

@Suite("Portfolio layout")
struct PortfolioLayoutTests {
    @Test func looseSectionComesFirstThenPalettesInOrder() {
        let a = UUID(), b = UUID()
        let loose = [UUID(), UUID()]
        let sections = PortfolioLayout.sections(
            looseColorIDs: loose,
            palettes: [PaletteSummary(id: a, name: "Alpha", colorIDs: [UUID()]), PaletteSummary(id: b, name: "Beta", colorIDs: [])]
        )
        #expect(sections.count == 3)
        #expect(sections[0].isLoose)
        #expect(sections[0].count == 2)
        #expect(sections[1].paletteID == a)
        #expect(sections[1].title == "Alpha")
        #expect(sections[2].paletteID == b)
        #expect(sections[2].count == 0)
    }

    @Test func looseSectionIsAlwaysPresentAsDropTarget() {
        let sections = PortfolioLayout.sections(looseColorIDs: [], palettes: [])
        #expect(sections.count == 1)
        #expect(sections.first?.isLoose == true)
    }

    @Test func subtitleAgreesInNumber() {
        #expect(PortfolioLayout.subtitle(colorCount: 12, paletteCount: 3) == "12 colors · 3 palettes")
        #expect(PortfolioLayout.subtitle(colorCount: 1, paletteCount: 1) == "1 color · 1 palette")
        #expect(PortfolioLayout.subtitle(colorCount: 0, paletteCount: 0) == nil)
    }

    @Test func swatchSizeCyclesSkipLargeOnCompact() {
        #expect(PortfolioLayout.nextSwatchSize(after: .medium, isCompactWidth: true) == .extraSmall)
        #expect(PortfolioLayout.nextSwatchSize(after: .medium, isCompactWidth: false) == .large)
        #expect(PortfolioLayout.nextSwatchSize(after: .large, isCompactWidth: false) == .extraSmall)
        #expect(PortfolioLayout.nextSwatchSizeGrows(after: .small, isCompactWidth: true))
        #expect(!PortfolioLayout.nextSwatchSizeGrows(after: .medium, isCompactWidth: true))
    }

    @Test func paletteColumnsNeedRegularWidthWideWindowAndSeveralPalettes() {
        #expect(PortfolioLayout.paletteColumns(width: 1200, isRegularWidth: true, paletteCount: 3) == 2)
        #expect(PortfolioLayout.paletteColumns(width: 1200, isRegularWidth: true, paletteCount: 1) == 1)
        #expect(PortfolioLayout.paletteColumns(width: 700, isRegularWidth: true, paletteCount: 3) == 1)
        #expect(PortfolioLayout.paletteColumns(width: 1200, isRegularWidth: false, paletteCount: 3) == 1)
    }

    @Test func batchDeleteTitleInflects() {
        #expect(PortfolioLayout.batchDeleteTitle(count: 1) == "Delete 1 Color?")
        #expect(PortfolioLayout.batchDeleteTitle(count: 4) == "Delete 4 Colors?")
    }
}

@Suite("Loose color selection")
struct LooseColorSelectionTests {
    @Test func togglingOnlyWorksWhileActive() {
        var selection = LooseColorSelection()
        let id = UUID()
        selection.toggle(id)
        #expect(selection.isEmpty)
        selection.begin()
        selection.toggle(id)
        #expect(selection.selectedIDs == [id])
        selection.toggle(id)
        #expect(selection.isEmpty)
    }

    @Test func toggleAllSelectsThenClears() {
        var selection = LooseColorSelection()
        let ids = [UUID(), UUID(), UUID()]
        selection.begin()
        selection.toggleAll(of: ids)
        #expect(selection.isAllSelected(of: ids))
        #expect(selection.count == 3)
        selection.toggleAll(of: ids)
        #expect(selection.isEmpty)
    }

    @Test func endClearsAndPruneDropsMissingIDs() {
        var selection = LooseColorSelection()
        let keep = UUID(), gone = UUID()
        selection.begin()
        selection.toggle(keep)
        selection.toggle(gone)
        selection.prune(keeping: [keep])
        #expect(selection.selectedIDs == [keep])
        selection.end()
        #expect(!selection.isActive)
        #expect(selection.isEmpty)
    }
}
