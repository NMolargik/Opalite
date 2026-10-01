//
//  PublishSnapshot.swift
//  OpaliteFeatureSharing
//
//  Detached copies of a color/palette carrying the notes and tags typed into a publish
//  sheet. `CommunityModel.publish` reads the model object it's handed, and the user's
//  Portfolio copy must not change just because they published — so the sheet publishes a
//  copy that is never inserted into a model context. Host-tested.
//

import Foundation
import OpaliteCore

enum PublishSnapshot {
    /// A copy of `color` with `notes` swapped in (same id, same authorship, no palette).
    static func color(_ color: OpaliteColor, notes: String?) -> OpaliteColor {
        OpaliteColor(
            id: color.id,
            name: color.name,
            notes: notes,
            createdByDisplayName: color.createdByDisplayName,
            createdOnDeviceName: color.createdOnDeviceName,
            updatedOnDeviceName: color.updatedOnDeviceName,
            createdAt: color.createdAt,
            updatedAt: color.updatedAt,
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha,
            palette: nil
        )
    }

    /// A copy of `palette` with `notes`/`tags` swapped in and detached copies of its
    /// colors in display order (so `sortedColors` on the copy matches the original).
    static func palette(_ palette: OpalitePalette, notes: String?, tags: [String]) -> OpalitePalette {
        let colors = palette.sortedColors.map { Self.color($0, notes: $0.notes) }
        let copy = OpalitePalette(
            id: palette.id,
            name: palette.name,
            createdAt: palette.createdAt,
            updatedAt: palette.updatedAt,
            createdByDisplayName: palette.createdByDisplayName,
            notes: notes,
            tags: tags,
            isArchived: palette.isArchived,
            colors: colors
        )
        copy.previewBackgroundRaw = palette.previewBackgroundRaw
        return copy
    }
}
