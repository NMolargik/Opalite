//
//  ImportSummary.swift
//  OpaliteFeatureSharing
//
//  Turns an import preview from Core into what the confirmation sheets say will happen:
//  the headline, the per-item outcome lines, and the primary action's title. Mirrors the
//  behavior of `ImportModel.confirmColorImport` / `confirmPaletteImport`. Host-tested.
//

import Foundation
import OpaliteCore

/// One outcome line in an import summary ("3 new colors will be added").
nonisolated public struct ImportOutcome: Equatable, Sendable, Identifiable {
    public enum Kind: Sendable { case add, update, move, skip }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }

    public var id: String { text }

    public var systemImage: String {
        switch kind {
        case .add: "plus.circle.fill"
        case .update: "arrow.triangle.2.circlepath.circle.fill"
        case .move: "arrow.right.circle.fill"
        case .skip: "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Color

nonisolated public struct ColorImportSummary: Equatable, Sendable {
    public let title: String
    public let willSkip: Bool

    public init(preview: ColorImportPreview) {
        let name = preview.color.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        title = name.isEmpty ? preview.color.rgba.hexString : name
        willSkip = preview.willSkip
    }

    public var canImport: Bool { !willSkip }

    public var headline: String {
        willSkip ? String(localized: "Already in your Portfolio") : String(localized: "Ready to import")
    }

    public var detail: String {
        willSkip
            ? String(localized: "This exact color is already saved, so nothing will change.")
            : String(localized: "“\(title)” will be added to your Portfolio as a loose color.")
    }

    public var actionTitle: String {
        willSkip ? String(localized: "Done") : String(localized: "Add to Portfolio")
    }

    public var outcome: ImportOutcome {
        willSkip
            ? ImportOutcome(kind: .skip, text: String(localized: "Skipped — same color already saved"))
            : ImportOutcome(kind: .add, text: String(localized: "Adds 1 color"))
    }
}

// MARK: - Palette

nonisolated public struct PaletteImportSummary: Equatable, Sendable {
    public let name: String
    public let isUpdate: Bool
    public let newColorCount: Int
    public let movedColorCount: Int
    public let totalColorCount: Int

    public init(preview: PaletteImportPreview) {
        name = preview.palette.name
        isUpdate = preview.willUpdate
        newColorCount = preview.newColors.count
        movedColorCount = preview.existingColorIDs.count
        totalColorCount = preview.palette.colors.count
    }

    /// Imports always do something: a new palette is created, or an existing one has its
    /// details refreshed (even when every color is already present).
    public var canImport: Bool { true }

    /// Whether the update changes nothing but the palette's details.
    public var isDetailsOnlyUpdate: Bool { isUpdate && newColorCount == 0 && movedColorCount == 0 }

    public var headline: String {
        isUpdate ? String(localized: "Update “\(name)”") : String(localized: "Create “\(name)”")
    }

    public var detail: String {
        if isUpdate {
            return isDetailsOnlyUpdate
                ? String(localized: "This palette is already in your Portfolio. Its name, notes, and tags will be refreshed from the file.")
                : String(localized: "This palette is already in your Portfolio. Its details will be refreshed and the colors below will be added to it.")
        }
        return String(localized: "A new palette will be added to your Portfolio.")
    }

    public var actionTitle: String {
        isUpdate ? String(localized: "Update Palette") : String(localized: "Add to Portfolio")
    }

    public var outcomes: [ImportOutcome] {
        var lines: [ImportOutcome] = []
        if isUpdate {
            lines.append(ImportOutcome(kind: .update, text: String(localized: "Refreshes the palette's name, notes, and tags")))
        } else {
            lines.append(ImportOutcome(kind: .add, text: String(localized: "Creates the palette")))
        }
        if newColorCount > 0 {
            lines.append(ImportOutcome(kind: .add, text: String(localized: "^[Adds \(newColorCount) new color](inflect: true)")))
        }
        if movedColorCount > 0 {
            lines.append(ImportOutcome(kind: .move, text: String(localized: "^[Moves \(movedColorCount) color](inflect: true) you already have into this palette")))
        }
        if totalColorCount == 0 {
            lines.append(ImportOutcome(kind: .skip, text: String(localized: "The file contains no colors")))
        }
        return lines
    }
}
