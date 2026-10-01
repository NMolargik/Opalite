//
//  PortfolioViewModel.swift
//  OpaliteFeaturePortfolio
//
//  The root screen's state: which sheet/cover is up, the color being renamed or deleted,
//  the loose-color multi-selection, and the verbs that create content (editor results,
//  quick-add hex, screen/photo samples, new palettes). Host-tested with
//  `PreviewEnvironment`.
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureColorEditor
import os

@Observable
final class PortfolioViewModel {
    // MARK: - Presentation

    /// The one modal sheet the root can show at a time.
    nonisolated enum Sheet: Identifiable, Hashable, Sendable {
        case quickAddHex
        case paletteOrder
        case archivedPalettes
        case moveColor(UUID)
        case moveSelection
        case exportColor(UUID)
        case publishColor(UUID)

        var id: Self { self }
    }

    /// What the color editor cover is creating.
    nonisolated struct EditorRequest: Identifiable, Hashable, Sendable {
        let id = UUID()
        var paletteID: UUID?
        var initial: RGBA?
    }

    var activeSheet: Sheet?
    var editorRequest: EditorRequest?
    var isShowingPhotoSampler = false
    var isShowingFileImporter = false
    var isNamingNewPalette = false
    var newPaletteName = ""

    // Alerts
    var colorPendingDeletion: UUID?
    var isConfirmingBatchDelete = false
    var renameTargetID: UUID?
    var renameDraft = ""

    // MARK: - Selection

    var selection = LooseColorSelection()

    // MARK: - Dependencies

    @ObservationIgnored private let portfolio: PortfolioModel
    @ObservationIgnored private let toasts: ToastManager

    init(portfolio: PortfolioModel, toasts: ToastManager) {
        self.portfolio = portfolio
        self.toasts = toasts
    }

    // MARK: - Derived

    var looseColors: [OpaliteColor] { portfolio.looseColors }
    var looseColorIDs: [UUID] { looseColors.map(\.id) }
    var selectedLooseColors: [OpaliteColor] { looseColors.filter { selection.selectedIDs.contains($0.id) } }
    var isEmpty: Bool { portfolio.isEmpty }

    var subtitle: String? {
        PortfolioLayout.subtitle(colorCount: portfolio.colors.count, paletteCount: portfolio.activePalettes.count)
    }

    var sections: [PortfolioSection] {
        PortfolioLayout.sections(
            looseColorIDs: looseColorIDs,
            palettes: portfolio.orderedPalettes.map { PaletteSummary(id: $0.id, name: $0.name, colorIDs: portfolio.colors(in: $0).map(\.id)) }
        )
    }

    var colorPendingDeletionName: String {
        colorPendingDeletion.flatMap { portfolio.color(withID: $0) }?.displayName ?? String(localized: "Color")
    }

    // MARK: - Creating colors

    func requestEditor(for palette: OpalitePalette? = nil, initial: RGBA? = nil) {
        editorRequest = EditorRequest(paletteID: palette?.id, initial: initial)
    }

    /// Saves an editor result into the requested palette.
    @discardableResult
    func saveEditorResult(_ result: ColorEditorResult) -> OpaliteColor? {
        let palette = editorRequest?.paletteID.flatMap { portfolio.palette(withID: $0) }
        editorRequest = nil
        let created = portfolio.createColor(result.rgba, name: result.name, notes: result.notes, in: palette)
        if created != nil { didCreateContent() }
        return created
    }

    /// Saves a sampled color (photo or screen) as a loose color.
    @discardableResult
    func saveSampledColor(_ rgba: RGBA, source: String) -> OpaliteColor? {
        let created = portfolio.createColor(rgba, name: nil, notes: nil, in: nil)
        if created != nil {
            Haptics.success()
            toasts.showSuccess(String(localized: "Sampled \(rgba.hexString) from \(source)"), systemImage: "eyedropper.halffull")
            didCreateContent()
        }
        return created
    }

    /// Saves a quick-add hex as a loose color.
    @discardableResult
    func saveQuickAdd(_ input: QuickAddHexInput) -> OpaliteColor? {
        guard let rgba = input.rgba else { return nil }
        let created = portfolio.createColor(rgba, name: nil, notes: nil, in: nil)
        if created != nil {
            toasts.showSuccess(String(localized: "Added \(input.displayHex ?? rgba.hexString)"), systemImage: "number")
            didCreateContent()
        }
        return created
    }

    // MARK: - Creating palettes

    func beginNamingNewPalette() {
        newPaletteName = String(localized: "New Palette")
        isNamingNewPalette = true
    }

    /// Creates the palette named in the alert (falls back to "New Palette").
    @discardableResult
    func createNamedPalette() -> OpalitePalette? {
        let trimmed = newPaletteName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "New Palette") : trimmed
        isNamingNewPalette = false
        newPaletteName = ""
        let created = portfolio.createPalette(name: name)
        if created != nil { didCreateContent() }
        return created
    }

    // MARK: - Renaming colors

    func beginRenaming(_ color: OpaliteColor) {
        renameDraft = color.name ?? ""
        renameTargetID = color.id
    }

    func cancelRenaming() {
        renameTargetID = nil
        renameDraft = ""
    }

    func commitRename() {
        if let id = renameTargetID, let color = portfolio.color(withID: id) {
            portfolio.rename(color, to: renameDraft)
        }
        cancelRenaming()
    }

    // MARK: - Deleting colors

    func confirmDelete(_ color: OpaliteColor) {
        colorPendingDeletion = color.id
    }

    func deletePendingColor() {
        guard let id = colorPendingDeletion, let color = portfolio.color(withID: id) else { colorPendingDeletion = nil; return }
        colorPendingDeletion = nil
        portfolio.delete(color)
    }

    func deleteSelection() {
        let colors = selectedLooseColors
        isConfirmingBatchDelete = false
        for color in colors { portfolio.delete(color) }
        selection.end()
        if !colors.isEmpty {
            let message = colors.count == 1 ? String(localized: "Deleted 1 color") : String(localized: "Deleted \(colors.count) colors")
            toasts.showSuccess(message, systemImage: "trash.fill")
        }
    }

    // MARK: - Moving colors

    func move(_ colors: [OpaliteColor], to palette: OpalitePalette) {
        for color in colors where color.palette?.id != palette.id {
            portfolio.move(color, to: palette)
        }
        Haptics.success()
        let message = colors.count == 1 ? String(localized: "Moved 1 color to \(palette.name)") : String(localized: "Moved \(colors.count) colors to \(palette.name)")
        toasts.showSuccess(message, systemImage: "swatchpalette.fill")
    }

    func removeFromPalette(_ color: OpaliteColor) {
        portfolio.move(color, to: nil)
    }

    // MARK: - Selection

    func toggleSelectionMode() {
        if selection.isActive { selection.end() } else { selection.begin() }
    }

    func handleTap(on color: OpaliteColor) -> Bool {
        guard selection.isActive else { return false }
        selection.toggle(color.id)
        return true
    }

    func pruneSelection() {
        selection.prune(keeping: looseColorIDs)
        if selection.isActive, looseColors.isEmpty { selection.end() }
    }

    // MARK: - Tips

    private func didCreateContent() {
        #if canImport(TipKit)
        PortfolioTips.advanceAfterContentCreation()
        #endif
    }
}
