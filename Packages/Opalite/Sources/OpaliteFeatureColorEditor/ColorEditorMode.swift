//
//  ColorEditorMode.swift
//  OpaliteFeatureColorEditor
//
//  The public contract of the editor: how it is opened (create or edit) and what it hands
//  back. Pure types so hosts, previews, and tests can talk to the editor without UIKit.
//

import Foundation
import OpaliteCore
#if canImport(UIKit)
import UIKit

/// The platform's bitmap image (the editor's image mode and the photo sampler use it).
public typealias PlatformImage = UIImage
#endif

/// How the editor is opened.
public enum ColorEditorMode {
    /// A brand-new color, optionally destined for a palette and optionally seeded with a
    /// starting value (a sampled or copied color, for instance).
    case create(palette: OpalitePalette? = nil, initial: RGBA? = nil)
    /// Edits an existing color; Save stays disabled until something changes.
    case edit(OpaliteColor)

    /// The palette whose sibling colors appear in the editor's strip.
    public var palette: OpalitePalette? {
        switch self {
        case .create(let palette, _): palette
        case .edit(let color): color.palette
        }
    }

    public var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }
}

/// What the editor hands back on Save.
public struct ColorEditorResult: Sendable, Hashable {
    public var rgba: RGBA
    public var name: String?
    public var notes: String?

    public init(rgba: RGBA, name: String? = nil, notes: String? = nil) {
        self.rgba = rgba
        self.name = name
        self.notes = notes
    }
}
