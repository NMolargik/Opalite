//
//  ReviewMilestone.swift
//  OpaliteCore
//
//  When to ask for an App Store review, each once per app version: when the user has built
//  a real portfolio (two palettes, or more than eight colors), and after the first export to
//  a pro tool (Procreate swatches or Adobe ASE) — a moment where Onyx has just paid off.
//

import Foundation

nonisolated public enum ReviewMilestone {
    public static func shouldPrompt(colorCount: Int, paletteCount: Int, currentVersion: String, lastPromptedVersion: String) -> Bool {
        guard !currentVersion.isEmpty, lastPromptedVersion != currentVersion else { return false }
        return paletteCount == 2 || colorCount > 8
    }

    /// The export file extensions that count as a pro export (`.swatches` is Procreate).
    public static let proExportExtensions: Set<String> = ["swatches", "ase"]

    /// Whether finishing an export of `fileExtension` should ask for a review this version.
    public static func shouldPromptAfterExport(fileExtension: String, currentVersion: String, lastPromptedVersion: String) -> Bool {
        guard !currentVersion.isEmpty, lastPromptedVersion != currentVersion else { return false }
        return proExportExtensions.contains(fileExtension.lowercased())
    }
}
