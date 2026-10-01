//
//  ColorDetailViewModel.swift
//  OpaliteFeaturePortfolio
//
//  State and verbs of the color detail screen: naming (with Apple Intelligence
//  suggestions), debounced notes autosave, palette membership, derived colors from the
//  harmony/tone chips, the contrast pairing, section expansion, and the presentation
//  flags the menu-bar commands drive. Works over the portfolio by id so it survives
//  refreshes; host-tested with `PreviewEnvironment`.
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeatureColorEditor
import os

/// The collapsible cards of the color detail, in display order.
nonisolated public enum ColorDetailSection: String, CaseIterable, Identifiable, Sendable {
    case codes
    case details
    case notes
    case palette
    case harmony
    case tones
    case contrast

    public var id: String { rawValue }

    /// Expanded on first open; the rest start collapsed to keep the screen scannable.
    public static let initiallyExpanded: Set<ColorDetailSection> = [.codes, .palette, .harmony]
}

@Observable
final class ColorDetailViewModel {
    // MARK: - Dependencies

    let colorID: UUID
    @ObservationIgnored private let portfolio: PortfolioModel
    @ObservationIgnored private let toasts: ToastManager
    @ObservationIgnored private let namer: (any ColorNaming)?

    // MARK: - State

    var notesDraft: String
    var isEditingName = false
    private(set) var nameSuggestions: [String] = []
    private(set) var isLoadingSuggestions = false
    var expandedSections: Set<ColorDetailSection> = ColorDetailSection.initiallyExpanded
    var harmonyKind: HarmonyKind = .complementary
    var contrast: ContrastCheck
    var contrastHexDraft = ""

    // Presentation the view binds to (the menu-bar commands set these too).
    var isShowingEditor = false
    var isShowingPaletteSheet = false
    var isShowingExport = false
    var isShowingPublish = false
    var isShowingFullScreen = false
    var isConfirmingDelete = false

    /// How long typing pauses before notes save.
    @ObservationIgnored var notesAutosaveDelay: Duration = .milliseconds(650)
    @ObservationIgnored private var notesSaveTask: Task<Void, Never>?
    @ObservationIgnored private var suggestionTask: Task<Void, Never>?
    @ObservationIgnored private(set) var lastSavedNotes: String

    // MARK: - Init

    init(colorID: UUID, portfolio: PortfolioModel, toasts: ToastManager, namer: (any ColorNaming)? = nil) {
        self.colorID = colorID
        self.portfolio = portfolio
        self.toasts = toasts
        self.namer = namer
        let color = portfolio.color(withID: colorID)
        let notes = color?.notes ?? ""
        notesDraft = notes
        lastSavedNotes = notes
        contrast = ContrastCheck(source: color?.rgba ?? .black)
    }

    // MARK: - Derived

    /// The live model; nil once the color is deleted (the view shows "not found").
    var color: OpaliteColor? { portfolio.color(withID: colorID) }

    var rgba: RGBA { color?.rgba ?? contrast.source }
    var displayName: String { color?.displayName ?? "" }
    var palette: OpalitePalette? { color?.palette }
    var isInPalette: Bool { palette != nil }

    var harmonyColors: [RGBA] { harmonyKind.colors(for: rgba) }

    /// Other portfolio colors offered as contrast comparisons.
    var contrastCandidates: [ContrastCandidate] {
        let all = portfolio.colors.map { ContrastCandidate(id: $0.id, name: $0.name, rgba: $0.rgba) }
        return ContrastCheck.candidates(from: all, excluding: colorID)
    }

    var canSuggestNames: Bool { namer?.isAvailable ?? false }

    func isExpanded(_ section: ColorDetailSection) -> Bool { expandedSections.contains(section) }

    func setExpanded(_ section: ColorDetailSection, _ expanded: Bool) {
        if expanded { expandedSections.insert(section) } else { expandedSections.remove(section) }
    }

    // MARK: - Naming

    func beginRenaming() {
        isEditingName = true
        requestSuggestions()
    }

    func endRenaming() {
        isEditingName = false
        clearSuggestions()
    }

    /// Renames (blank clears the name) and leaves edit mode.
    func rename(to newName: String) {
        guard let color else { return }
        portfolio.rename(color, to: newName)
        endRenaming()
    }

    func requestSuggestions() {
        guard let namer, namer.isAvailable else { return }
        suggestionTask?.cancel()
        let rgba = rgba
        isLoadingSuggestions = true
        suggestionTask = Task { [weak self] in
            defer { self?.isLoadingSuggestions = false }
            do {
                let names = try await namer.suggestNames(for: rgba, count: ColorNamePrompt.defaultCount)
                guard !Task.isCancelled else { return }
                self?.nameSuggestions = names
            } catch {
                guard !Task.isCancelled else { return }
                Log.intelligence.error("Name suggestions failed: \(error.localizedDescription)")
                self?.nameSuggestions = []
            }
        }
    }

    func clearSuggestions() {
        suggestionTask?.cancel()
        suggestionTask = nil
        nameSuggestions = []
        isLoadingSuggestions = false
    }

    // MARK: - Notes

    var hasUnsavedNotes: Bool {
        notesDraft.trimmingCharacters(in: .whitespacesAndNewlines) != lastSavedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Called on every keystroke; saves after the typing pause.
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
        guard hasUnsavedNotes, let color else { return }
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        portfolio.update(color) { $0.notes = trimmed.isEmpty ? nil : trimmed }
        lastSavedNotes = trimmed
    }

    // MARK: - Editing

    /// Applies the editor's result to this color.
    func apply(_ result: ColorEditorResult) {
        guard let color else { return }
        portfolio.update(color) { model in
            model.red = result.rgba.red
            model.green = result.rgba.green
            model.blue = result.rgba.blue
            model.alpha = result.rgba.alpha
            if let name = result.name?.trimmingCharacters(in: .whitespacesAndNewlines) {
                model.name = name.isEmpty ? nil : name
            }
            if let notes = result.notes {
                let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                model.notes = trimmed.isEmpty ? nil : trimmed
                notesDraft = trimmed
                lastSavedNotes = trimmed
            }
        }
        contrast.source = result.rgba
        isShowingEditor = false
    }

    // MARK: - Membership

    func move(to palette: OpalitePalette?) {
        guard let color else { return }
        portfolio.move(color, to: palette)
        if let palette {
            toasts.showSuccess(String(localized: "Moved to \(palette.name)"), systemImage: "swatchpalette.fill")
        }
    }

    func removeFromPalette() {
        guard let color, color.palette != nil else { return }
        portfolio.move(color, to: nil)
    }

    // MARK: - Derived colors

    /// Saves a harmony/tint/shade/tone as a new color beside this one (same palette).
    @discardableResult
    func addDerivedColor(_ rgba: RGBA, label: String) -> OpaliteColor? {
        guard let color else { return nil }
        let notes = String(localized: "\(label) of \(color.displayName)")
        let created = portfolio.createColor(rgba, name: nil, notes: notes, in: color.palette)
        if created != nil {
            Haptics.success()
            toasts.showSuccess(String(localized: "Added \(rgba.hexString)"), systemImage: "plus.circle.fill")
        }
        return created
    }

    // MARK: - Contrast

    func selectContrast(_ preset: ContrastCheck.Preset) {
        contrast.select(preset)
    }

    func selectContrast(_ candidate: ContrastCandidate) {
        contrast.select(candidate)
    }

    /// Applies the typed hex; returns whether it parsed.
    @discardableResult
    func applyContrastHex() -> Bool {
        let applied = contrast.select(hex: contrastHexDraft)
        if applied { contrastHexDraft = "" }
        return applied
    }

    // MARK: - Delete

    /// Deletes the color; the view pops afterwards.
    func delete() {
        guard let color else { return }
        notesSaveTask?.cancel()
        portfolio.delete(color)
    }

    // MARK: - Menu-bar commands

    /// Performs a command aimed at the active color. Returns whether it applied here.
    @discardableResult
    func handle(_ command: PortfolioCommand) -> Bool {
        switch command {
        case .editActiveColor:
            isShowingEditor = true
        case .moveActiveColorToPalette:
            isShowingPaletteSheet = true
        case .removeActiveColorFromPalette:
            removeFromPalette()
        case .renameActivePalette:
            return false
        }
        return true
    }

    // MARK: - Lifecycle

    func didAppear() {
        portfolio.activeColorID = colorID
        contrast.source = rgba
    }

    func willDisappear() {
        if portfolio.activeColorID == colorID { portfolio.activeColorID = nil }
        saveNotesNow()
        clearSuggestions()
    }
}
