//
//  ReviewMilestone.swift
//  OpaliteCore
//
//  When to ask for an App Store review: once per app version, when the user has built a
//  real portfolio (two palettes, or more than eight colors).
//

import Foundation

nonisolated public enum ReviewMilestone {
    public static func shouldPrompt(colorCount: Int, paletteCount: Int, currentVersion: String, lastPromptedVersion: String) -> Bool {
        guard !currentVersion.isEmpty, lastPromptedVersion != currentVersion else { return false }
        return paletteCount == 2 || colorCount > 8
    }
}
