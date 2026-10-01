//
//  ImportSummaryTests.swift
//  OpaliteFeatureSharingTests
//

import Foundation
import Testing
import OpaliteCore
import OpaliteFeatureShared
@testable import OpaliteFeatureSharing

private func decodedColor(name: String? = nil, id: UUID = UUID()) -> DecodedColor {
    DecodedColor(id: id, name: name, notes: nil, rgba: RGBA(red: 0.2, green: 0.5, blue: 0.8))
}

@Suite("Color import summary")
struct ColorImportSummaryTests {
    @Test func newColorIsReadyToAdd() {
        let summary = ColorImportSummary(preview: ColorImportPreview(color: decodedColor(name: "Harbor"), existingColorID: nil))
        #expect(summary.canImport)
        #expect(summary.title == "Harbor")
        #expect(summary.headline == "Ready to import")
        #expect(summary.detail.contains("Harbor"))
        #expect(summary.actionTitle == "Add to Portfolio")
        #expect(summary.outcome.kind == .add)
    }

    @Test func duplicateIsSkippedWithADoneAction() {
        let color = decodedColor()
        let summary = ColorImportSummary(preview: ColorImportPreview(color: color, existingColorID: color.id))
        #expect(!summary.canImport)
        #expect(summary.willSkip)
        #expect(summary.actionTitle == "Done")
        #expect(summary.outcome.kind == .skip)
    }

    @Test func unnamedColorsAreTitledByHex() {
        let summary = ColorImportSummary(preview: ColorImportPreview(color: decodedColor(name: "  "), existingColorID: nil))
        #expect(summary.title == "#3380CC")
    }
}

@Suite("Palette import summary")
struct PaletteImportSummaryTests {
    private func palette(_ colors: [DecodedColor], name: String = "Harbor") -> DecodedPalette {
        DecodedPalette(id: UUID(), name: name, notes: nil, tags: [], createdByDisplayName: nil, previewBackgroundRaw: nil, createdAt: .now, updatedAt: .now, colors: colors)
    }

    @Test func newPaletteCreatesAndAddsEveryColor() {
        let colors = [decodedColor(), decodedColor(), decodedColor()]
        let summary = PaletteImportSummary(preview: PaletteImportPreview(palette: palette(colors), existingPaletteID: nil, newColors: colors, existingColorIDs: []))
        #expect(!summary.isUpdate)
        #expect(summary.canImport)
        #expect(summary.headline == "Create “Harbor”")
        #expect(summary.actionTitle == "Add to Portfolio")
        #expect(summary.outcomes.map(\.kind) == [.add, .add])
        #expect(summary.outcomes[1].text.contains("3"))
    }

    @Test func existingPaletteUpdatesAddsAndMoves() {
        let colors = [decodedColor(), decodedColor(), decodedColor()]
        let decoded = palette(colors)
        let summary = PaletteImportSummary(preview: PaletteImportPreview(palette: decoded, existingPaletteID: decoded.id, newColors: [colors[0]], existingColorIDs: [colors[1].id, colors[2].id]))
        #expect(summary.isUpdate)
        #expect(!summary.isDetailsOnlyUpdate)
        #expect(summary.headline == "Update “Harbor”")
        #expect(summary.actionTitle == "Update Palette")
        #expect(summary.outcomes.map(\.kind) == [.update, .add, .move])
        #expect(summary.outcomes[2].text.contains("2"))
    }

    @Test func fullyPresentPaletteIsADetailsOnlyUpdate() {
        let colors = [decodedColor()]
        let decoded = palette(colors)
        let summary = PaletteImportSummary(preview: PaletteImportPreview(palette: decoded, existingPaletteID: decoded.id, newColors: [], existingColorIDs: [colors[0].id]))
        #expect(summary.isUpdate)
        #expect(summary.canImport)
        // The existing color is moved into the palette, so it's not purely a details refresh.
        #expect(!summary.isDetailsOnlyUpdate)
        #expect(summary.outcomes.map(\.kind) == [.update, .move])

        let bare = PaletteImportSummary(preview: PaletteImportPreview(palette: decoded, existingPaletteID: decoded.id, newColors: [], existingColorIDs: []))
        #expect(bare.isDetailsOnlyUpdate)
        #expect(bare.outcomes.map(\.kind) == [.update])
    }

    @Test func emptyPaletteSaysSo() {
        let summary = PaletteImportSummary(preview: PaletteImportPreview(palette: palette([]), existingPaletteID: nil, newColors: [], existingColorIDs: []))
        #expect(summary.canImport)
        #expect(summary.outcomes.map(\.kind) == [.add, .skip])
    }

    @Test @MainActor func summaryMatchesWhatTheImportModelDoes() throws {
        let environment = PreviewEnvironment()
        let existing = try #require(environment.portfolio.palettes.first)
        let loose = try #require(environment.portfolio.looseColors.first)
        let fresh = decodedColor(name: "Brand new")
        let decoded = DecodedPalette(id: existing.id, name: "Renamed", notes: "n", tags: ["t"], createdByDisplayName: nil, previewBackgroundRaw: nil, createdAt: .now, updatedAt: .now, colors: [fresh, decodedColor(id: loose.id)])
        let preview = PaletteImportPreview(palette: decoded, existingPaletteID: existing.id, newColors: [fresh], existingColorIDs: [loose.id])
        let summary = PaletteImportSummary(preview: preview)
        let before = existing.colorCount

        environment.importer.pendingPaletteImport = preview
        environment.importer.confirmPaletteImport(into: environment.portfolio)

        #expect(existing.name == "Renamed")
        #expect(existing.colorCount == before + summary.newColorCount + summary.movedColorCount)
        #expect(loose.palette?.id == existing.id)
    }
}
