import Foundation
import Testing
import OpaliteCore
import OpaliteFeatureShared
import OpaliteFeatureColorEditor
@testable import OpaliteFeaturePortfolio

/// A naming service that answers immediately.
private final class FakeNamer: ColorNaming {
    var isAvailable = true
    var names = ["Harbor", "Tide", "Slate"]
    func suggestNames(for color: RGBA, count: Int) async throws -> [String] { Array(names.prefix(count)) }
}

@Suite("Color detail view model")
struct ColorDetailViewModelTests {
    private func makeModel(namer: FakeNamer? = nil) -> (PreviewEnvironment, ColorDetailViewModel, OpaliteColor) {
        let env = PreviewEnvironment()
        let color = env.portfolio.looseColors.first { $0.name == "Moss" }!
        let model = ColorDetailViewModel(colorID: color.id, portfolio: env.portfolio, toasts: env.toastManager, namer: namer)
        return (env, model, color)
    }

    @Test func renameTrimsAndClearsOnBlank() {
        let (_, model, color) = makeModel()
        model.rename(to: "  Deep Moss ")
        #expect(color.name == "Deep Moss")
        #expect(!model.isEditingName)
        model.rename(to: "   ")
        #expect(color.name == nil)
    }

    @Test func notesAutosaveAfterPause() async throws {
        let (_, model, color) = makeModel()
        model.notesAutosaveDelay = .milliseconds(10)
        model.notesDraft = "Looks great on cream"
        model.notesDidChange()
        #expect(model.hasUnsavedNotes)
        try await Task.sleep(for: .milliseconds(80))
        #expect(color.notes == "Looks great on cream")
        #expect(!model.hasUnsavedNotes)
    }

    @Test func saveNotesNowIsIdempotentAndClearsBlank() {
        let (_, model, color) = makeModel()
        model.notesDraft = "   "
        model.saveNotesNow()
        #expect(color.notes == nil)
        model.notesDraft = "x"
        model.saveNotesNow()
        #expect(color.notes == "x")
    }

    @Test func editorResultUpdatesComponentsNameAndNotes() {
        let (_, model, color) = makeModel()
        model.isShowingEditor = true
        model.apply(ColorEditorResult(rgba: RGBA(red: 1, green: 0, blue: 0, alpha: 0.5), name: "Scarlet", notes: "Hot"))
        #expect(color.red == 1 && color.green == 0 && color.blue == 0 && color.alpha == 0.5)
        #expect(color.name == "Scarlet")
        #expect(color.notes == "Hot")
        #expect(model.notesDraft == "Hot")
        #expect(!model.isShowingEditor)
        #expect(model.contrast.source == color.rgba)
    }

    @Test func moveAndRemoveFromPalette() {
        let (env, model, color) = makeModel()
        let palette = env.portfolio.activePalettes.first!
        model.move(to: palette)
        #expect(color.palette?.id == palette.id)
        #expect(model.isInPalette)
        model.removeFromPalette()
        #expect(color.palette == nil)
    }

    @Test func derivedColorLandsInTheSamePalette() {
        let (env, model, color) = makeModel()
        let palette = env.portfolio.activePalettes.first!
        model.move(to: palette)
        let before = env.portfolio.colors(in: palette).count
        let created = model.addDerivedColor(RGBA(red: 0.1, green: 0.2, blue: 0.3), label: "Tint")
        #expect(created?.palette?.id == palette.id)
        #expect(created?.notes == "Tint of \(color.displayName)")
        #expect(env.portfolio.colors(in: palette).count == before + 1)
    }

    @Test func contrastCandidatesExcludeSelf() {
        let (env, model, color) = makeModel()
        #expect(!model.contrastCandidates.contains { $0.id == color.id })
        #expect(model.contrastCandidates.count == env.portfolio.colors.count - 1)
        model.selectContrast(.white)
        #expect(model.contrast.comparison == .white)
        model.contrastHexDraft = "000000"
        #expect(model.applyContrastHex())
        #expect(model.contrast.comparison == .black)
        #expect(model.contrastHexDraft.isEmpty)
    }

    @Test func nameSuggestionsLoadWhenRenamingBegins() async throws {
        let namer = FakeNamer()
        let (_, model, _) = makeModel(namer: namer)
        #expect(model.canSuggestNames)
        model.beginRenaming()
        #expect(model.isEditingName)
        try await Task.sleep(for: .milliseconds(50))
        #expect(model.nameSuggestions == ["Harbor", "Tide", "Slate"])
        model.endRenaming()
        #expect(model.nameSuggestions.isEmpty)
        #expect(!model.isEditingName)
    }

    @Test func commandsDriveEditorAndPaletteSheet() {
        let (_, model, _) = makeModel()
        #expect(model.handle(.editActiveColor))
        #expect(model.isShowingEditor)
        #expect(model.handle(.moveActiveColorToPalette))
        #expect(model.isShowingPaletteSheet)
        #expect(!model.handle(.renameActivePalette))
    }

    @Test func appearanceTracksActiveColorAndDeleteClearsIt() {
        let (env, model, color) = makeModel()
        model.didAppear()
        #expect(env.portfolio.activeColorID == color.id)
        model.willDisappear()
        #expect(env.portfolio.activeColorID == nil)
        model.delete()
        #expect(model.color == nil)
        #expect(env.portfolio.color(withID: color.id) == nil)
    }

    @Test func sectionExpansionDefaults() {
        let (_, model, _) = makeModel()
        #expect(model.isExpanded(.codes))
        #expect(!model.isExpanded(.contrast))
        model.setExpanded(.contrast, true)
        #expect(model.isExpanded(.contrast))
    }
}

@Suite("Palette detail view model")
struct PaletteDetailViewModelTests {
    private func makeModel() -> (PreviewEnvironment, PaletteDetailViewModel, OpalitePalette) {
        let env = PreviewEnvironment()
        let palette = env.portfolio.activePalettes.first!
        let model = PaletteDetailViewModel(paletteID: palette.id, portfolio: env.portfolio, canvases: env.canvases, toasts: env.toastManager)
        return (env, model, palette)
    }

    @Test func renameCommitsNonBlankDraftOnly() {
        let (_, model, palette) = makeModel()
        model.beginRenaming()
        #expect(model.nameDraft == palette.name)
        model.nameDraft = "  Autumn  "
        model.commitRename()
        #expect(palette.name == "Autumn")
        model.beginRenaming()
        model.nameDraft = ""
        model.commitRename()
        #expect(palette.name == "Autumn")
        #expect(!model.isEditingName)
    }

    @Test func tagsAddDeduplicateAndRemove() {
        let (_, model, palette) = makeModel()
        let original = palette.tags
        model.tagDraft = " #Warm "
        model.addTag()
        #expect(palette.tags == original + ["Warm"])
        #expect(model.tagDraft.isEmpty)
        model.tagDraft = "warm"
        model.addTag()
        #expect(palette.tags == original + ["Warm"])
        model.removeTag("Warm")
        #expect(palette.tags == original)
    }

    @Test func backgroundPersistsAndDefaultsByScheme() {
        let (_, model, palette) = makeModel()
        #expect(model.background(isDark: true) == .black)
        #expect(model.background(isDark: false) == .white)
        model.setBackground(.navy)
        #expect(palette.previewBackground == .navy)
        #expect(model.background(isDark: false) == .navy)
    }

    @Test func addRemoveAndDeleteMembers() {
        let (env, model, palette) = makeModel()
        let before = model.memberCount
        let created = model.addColor(ColorEditorResult(rgba: RGBA(red: 0.3, green: 0.3, blue: 0.3), name: "Ash"))!
        #expect(created.palette?.id == palette.id)
        #expect(model.memberCount == before + 1)
        model.remove(created)
        #expect(created.palette == nil)
        #expect(model.memberCount == before)
        #expect(env.portfolio.looseColors.contains { $0.id == created.id })
        model.delete(created)
        #expect(env.portfolio.color(withID: created.id) == nil)
    }

    @Test func notesAutosave() async throws {
        let (_, model, palette) = makeModel()
        model.notesAutosaveDelay = .milliseconds(10)
        model.notesDraft = "Client approved"
        model.notesDidChange()
        try await Task.sleep(for: .milliseconds(80))
        #expect(palette.notes == "Client approved")
    }

    @Test func linkAndUnlinkCanvas() {
        let (env, model, palette) = makeModel()
        let canvas = env.canvases.canvases.first!
        model.link(canvas)
        #expect(palette.canvasFile?.id == canvas.id)
        #expect(model.linkedCanvas?.id == canvas.id)
        #expect(model.canOpenLinkedCanvas)
        model.unlinkCanvas()
        #expect(palette.canvasFile == nil)
    }

    @Test func duplicateCopiesMembersNotesAndTags() {
        let (env, model, palette) = makeModel()
        let copy = model.duplicate()!
        #expect(copy.name == "\(palette.name) Copy")
        #expect(copy.notes == palette.notes)
        #expect(copy.tags == palette.tags)
        #expect(env.portfolio.colors(in: copy).count == env.portfolio.colors(in: palette).count)
        #expect(Set(env.portfolio.colors(in: copy).map(\.hexString)) == Set(env.portfolio.colors(in: palette).map(\.hexString)))
    }

    @Test func archiveAndDelete() {
        let (env, model, palette) = makeModel()
        model.archive()
        #expect(palette.isArchived)
        #expect(env.portfolio.archivedPalettes.contains { $0.id == palette.id })
        let memberIDs = env.portfolio.colors(in: palette).map(\.id)
        model.delete(deleteColors: false)
        #expect(env.portfolio.palette(withID: palette.id) == nil)
        #expect(memberIDs.allSatisfy { env.portfolio.color(withID: $0) != nil })
    }

    @Test func renameCommandBeginsEditing() {
        let (env, model, palette) = makeModel()
        model.didAppear()
        #expect(env.portfolio.activePaletteID == palette.id)
        #expect(model.handle(.renameActivePalette))
        #expect(model.isEditingName)
        #expect(!model.handle(.editActiveColor))
        model.willDisappear()
        #expect(env.portfolio.activePaletteID == nil)
    }
}

@Suite("Portfolio root view model")
struct PortfolioViewModelTests {
    private func makeModel(seeded: Bool = true) -> (PreviewEnvironment, PortfolioViewModel) {
        let env = PreviewEnvironment(seeded: seeded)
        return (env, PortfolioViewModel(portfolio: env.portfolio, toasts: env.toastManager))
    }

    @Test func sectionsFollowThePortfolio() {
        let (env, model) = makeModel()
        #expect(model.sections.count == env.portfolio.activePalettes.count + 1)
        #expect(model.sections[0].count == env.portfolio.looseColors.count)
        #expect(model.subtitle == "\(env.portfolio.colors.count) colors · 1 palette")
        let (_, empty) = makeModel(seeded: false)
        #expect(empty.isEmpty)
        #expect(empty.subtitle == nil)
    }

    @Test func editorResultCreatesInRequestedPalette() {
        let (env, model) = makeModel()
        let palette = env.portfolio.activePalettes.first!
        model.requestEditor(for: palette, initial: RGBA(red: 1, green: 1, blue: 0))
        #expect(model.editorRequest?.paletteID == palette.id)
        let created = model.saveEditorResult(ColorEditorResult(rgba: RGBA(red: 1, green: 1, blue: 0), name: "Lemon"))
        #expect(created?.palette?.id == palette.id)
        #expect(created?.name == "Lemon")
        #expect(model.editorRequest == nil)
    }

    @Test func quickAddAndSamplesBecomeLooseColors() {
        let (env, model) = makeModel(seeded: false)
        #expect(model.saveQuickAdd(QuickAddHexInput("12345")) == nil)
        let added = model.saveQuickAdd(QuickAddHexInput("123456"))
        #expect(added?.hexString == "#123456")
        #expect(added?.palette == nil)
        let sampled = model.saveSampledColor(RGBA(red: 0, green: 1, blue: 0), source: "screen")
        #expect(sampled != nil)
        #expect(env.portfolio.looseColors.count == 2)
    }

    @Test func namedPaletteCreationFallsBackToDefaultName() {
        let (env, model) = makeModel(seeded: false)
        model.beginNamingNewPalette()
        #expect(model.isNamingNewPalette)
        model.newPaletteName = "   "
        let palette = model.createNamedPalette()
        #expect(palette?.name == "New Palette")
        #expect(!model.isNamingNewPalette)
        model.newPaletteName = "Brand"
        #expect(model.createNamedPalette()?.name == "Brand")
        #expect(env.portfolio.activePalettes.count == 2)
    }

    @Test func renameAndDeleteFlows() {
        let (env, model) = makeModel()
        let color = env.portfolio.looseColors.first!
        model.beginRenaming(color)
        #expect(model.renameTargetID == color.id)
        model.renameDraft = "Renamed"
        model.commitRename()
        #expect(color.name == "Renamed")
        #expect(model.renameTargetID == nil)
        model.confirmDelete(color)
        #expect(model.colorPendingDeletionName == "Renamed")
        model.deletePendingColor()
        #expect(env.portfolio.color(withID: color.id) == nil)
        #expect(model.colorPendingDeletion == nil)
    }

    @Test func selectionModeMovesAndDeletesInBatch() {
        let (env, model) = makeModel()
        let loose = env.portfolio.looseColors
        #expect(loose.count >= 2)
        #expect(!model.handleTap(on: loose[0]))
        model.toggleSelectionMode()
        #expect(model.handleTap(on: loose[0]))
        #expect(model.handleTap(on: loose[1]))
        #expect(model.selection.count == 2)
        let palette = env.portfolio.activePalettes.first!
        model.move(model.selectedLooseColors, to: palette)
        #expect(loose[0].palette?.id == palette.id && loose[1].palette?.id == palette.id)
        model.pruneSelection()
        #expect(model.selection.isEmpty)
        model.toggleSelectionMode()
        #expect(!model.selection.isActive)
    }

    @Test func batchDeleteRemovesSelectionAndExitsMode() {
        let (env, model) = makeModel()
        let loose = env.portfolio.looseColors
        model.toggleSelectionMode()
        for color in loose { _ = model.handleTap(on: color) }
        model.deleteSelection()
        #expect(env.portfolio.looseColors.isEmpty)
        #expect(!model.selection.isActive)
    }
}
