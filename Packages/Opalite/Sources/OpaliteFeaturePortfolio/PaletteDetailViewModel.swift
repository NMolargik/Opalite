//
//  PaletteDetailViewModel.swift
//  OpaliteFeaturePortfolio
//
//  State and verbs of the palette detail screen: renaming, the preview background,
//  debounced notes, tags, adding/removing members, the linked canvas, duplicate /
//  archive / delete, and the presentation flags the menu-bar command drives. Works over
//  the portfolio by id; host-tested with `PreviewEnvironment`.
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureColorEditor
import os

/// The collapsible cards of the palette detail, in display order.
nonisolated public enum PaletteDetailSection: String, CaseIterable, Identifiable, Sendable {
    case colors
    case notes
    case tags
    case canvas

    public var id: String { rawValue }

    public static let initiallyExpanded: Set<PaletteDetailSection> = [.colors, .canvas]
}

@Observable
final class PaletteDetailViewModel {
    // MARK: - Dependencies

    let paletteID: UUID
    @ObservationIgnored private let portfolio: PortfolioModel
    @ObservationIgnored private let canvases: CanvasModel?
    @ObservationIgnored private let toasts: ToastManager

    // MARK: - State

    var notesDraft: String
    var isEditingName = false
    var nameDraft = ""
    var tagDraft = ""
    var expandedSections: Set<PaletteDetailSection> = PaletteDetailSection.initiallyExpanded

    var isShowingEditor = false
    var isShowingExport = false
    var isShowingPublish = false
    var isShowingCanvasPicker = false
    var isShowingFullScreen = false
    var isConfirmingDelete = false
    var isConfirmingArchive = false
    var isConfirmingUnlink = false

    @ObservationIgnored var notesAutosaveDelay: Duration = .milliseconds(650)
    @ObservationIgnored private var notesSaveTask: Task<Void, Never>?
    @ObservationIgnored private(set) var lastSavedNotes: String

    // MARK: - Init

    init(paletteID: UUID, portfolio: PortfolioModel, canvases: CanvasModel? = nil, toasts: ToastManager) {
        self.paletteID = paletteID
        self.portfolio = portfolio
        self.canvases = canvases
        self.toasts = toasts
        let notes = portfolio.palette(withID: paletteID)?.notes ?? ""
        notesDraft = notes
        lastSavedNotes = notes
    }

    // MARK: - Derived

    var palette: OpalitePalette? { portfolio.palette(withID: paletteID) }
    var name: String { palette?.name ?? "" }
    var tags: [String] { palette?.tags ?? [] }

    /// Members newest-updated first (reads through the cache so it reacts to changes).
    var members: [OpaliteColor] {
        guard let palette else { return [] }
        _ = portfolio.changeStamp
        return portfolio.colors(in: palette)
    }

    var memberCount: Int { members.count }
    var linkedCanvas: CanvasFile? { palette?.canvasFile }
    var canOpenLinkedCanvas: Bool {
        guard let canvas = linkedCanvas, let canvases else { return false }
        return canvases.canAccess(canvas)
    }

    /// The preview background: the stored choice, else the scheme's default.
    func background(isDark: Bool) -> PreviewBackground {
        palette?.previewBackground ?? PreviewBackground.defaultFor(isDark: isDark)
    }

    func isExpanded(_ section: PaletteDetailSection) -> Bool { expandedSections.contains(section) }

    func setExpanded(_ section: PaletteDetailSection, _ expanded: Bool) {
        if expanded { expandedSections.insert(section) } else { expandedSections.remove(section) }
    }

    // MARK: - Naming

    func beginRenaming() {
        nameDraft = name
        isEditingName = true
    }

    func cancelRenaming() {
        isEditingName = false
        nameDraft = ""
    }

    /// Saves the draft name (blank keeps the old one) and leaves edit mode.
    func commitRename() {
        if let palette {
            let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != palette.name { portfolio.rename(palette, to: trimmed) }
        }
        cancelRenaming()
    }

    // MARK: - Background

    func setBackground(_ background: PreviewBackground) {
        guard let palette else { return }
        portfolio.update(palette) { $0.previewBackground = background }
    }

    // MARK: - Notes

    var hasUnsavedNotes: Bool {
        notesDraft.trimmingCharacters(in: .whitespacesAndNewlines) != lastSavedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func notesDidChange() {
        notesSaveTask?.cancel()
        guard hasUnsavedNotes else { return }
        let delay = notesAutosaveDelay
        notesSaveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.saveNotesNow()
        }
    }

    func saveNotesNow() {
        notesSaveTask?.cancel()
        guard hasUnsavedNotes, let palette else { return }
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        portfolio.update(palette) { $0.notes = trimmed.isEmpty ? nil : trimmed }
        lastSavedNotes = trimmed
    }

    // MARK: - Tags

    /// Adds the draft tag (deduplicated case-insensitively) and clears the field.
    func addTag() {
        guard let palette else { return }
        let updated = DetailFormatting.addingTag(tagDraft, to: palette.tags)
        if updated != palette.tags {
            portfolio.update(palette) { $0.tags = updated }
        }
        tagDraft = ""
    }

    func removeTag(_ tag: String) {
        guard let palette else { return }
        portfolio.update(palette) { $0.tags.removeAll { $0 == tag } }
    }

    // MARK: - Members

    /// Creates a color from the editor straight into this palette.
    @discardableResult
    func addColor(_ result: ColorEditorResult) -> OpaliteColor? {
        guard let palette else { return nil }
        isShowingEditor = false
        return portfolio.createColor(result.rgba, name: result.name, notes: result.notes, in: palette)
    }

    func remove(_ color: OpaliteColor) {
        guard color.palette?.id == paletteID else { return }
        portfolio.move(color, to: nil)
    }

    func delete(_ color: OpaliteColor) {
        portfolio.delete(color)
    }

    // MARK: - Canvas

    func link(_ canvas: CanvasFile) {
        guard let palette else { return }
        portfolio.link(canvas, to: palette)
        toasts.showSuccess(String(localized: "Linked \(canvas.title)"), systemImage: "link")
    }

    func unlinkCanvas() {
        guard let palette, palette.canvasFile != nil else { return }
        portfolio.link(nil, to: palette)
    }

    // MARK: - Palette verbs

    /// Copies the palette and its colors; returns the copy.
    @discardableResult
    func duplicate() -> OpalitePalette? {
        guard let palette else { return nil }
        let copyName = String(localized: "\(palette.name) Copy")
        guard let copy = portfolio.createPalette(name: copyName, notes: palette.notes, tags: palette.tags) else { return nil }
        if let background = palette.previewBackground {
            portfolio.update(copy) { $0.previewBackground = background }
        }
        for color in members.reversed() {
            _ = portfolio.createColor(color.rgba, name: color.name, notes: color.notes, in: copy)
        }
        toasts.showSuccess(String(localized: "Duplicated \(palette.name)"), systemImage: "plus.square.on.square")
        return copy
    }

    func archive() {
        guard let palette else { return }
        portfolio.setArchived(palette, true)
        toasts.show(message: String(localized: "Archived \(palette.name)"), style: .info, systemImage: "archivebox.fill")
    }

    /// Deletes the palette (optionally its colors); the view pops afterwards.
    func delete(deleteColors: Bool) {
        guard let palette else { return }
        notesSaveTask?.cancel()
        portfolio.delete(palette, deleteColors: deleteColors)
    }

    // MARK: - Menu-bar commands

    @discardableResult
    func handle(_ command: PortfolioCommand) -> Bool {
        switch command {
        case .renameActivePalette:
            beginRenaming()
            return true
        case .editActiveColor, .moveActiveColorToPalette, .removeActiveColorFromPalette:
            return false
        }
    }

    // MARK: - Lifecycle

    func didAppear() {
        portfolio.activePaletteID = paletteID
    }

    func willDisappear() {
        if portfolio.activePaletteID == paletteID { portfolio.activePaletteID = nil }
        saveNotesNow()
    }
}
