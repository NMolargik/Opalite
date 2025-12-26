//
//  OpaliteTips.swift
//  Opalite
//
//  Created by Nick Molargik on 12/25/25.
//

import TipKit

// MARK: - Tip Helpers

/// Helper to advance tips after user creates content.
/// Call this after successfully creating a color or palette to unlock subsequent tips.
enum OpaliteTipActions {
    /// Advances all tips after user creates their first content (color or palette).
    static func advanceTipsAfterContentCreation() {
        ColorDetailsTip.hasSeenCreateTip = true
        DragAndDropTip.hasCreatedPalette = true
        PaletteMenuTip.hasCreatedPalette = true
    }
}

// MARK: - Create Content Tip

/// Tip shown to new users explaining the plus button for creating colors and palettes.
struct CreateContentTip: Tip {

    var title: Text {
        Text("Create Your First Color")
    }

    var message: Text? {
        Text("Use the + button in the top right corner to create a new color, start a palette, or import from a file. Importing from a file requires an active subscription to Onyx.")
    }

    var image: Image? {
        Image(systemName: "sparkles")
    }

    var options: [TipOption] {
        // High priority so this shows first
        Tips.MaxDisplayCount(1)
    }
}

// MARK: - Color Details Tip

/// Tip explaining that tapping a color swatch opens its details.
///
/// Only shown after the create content tip has been dismissed.
struct ColorDetailsTip: Tip {

    /// Rule: Only show after create content tip is invalidated.
    @Parameter
    static var hasSeenCreateTip: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasSeenCreateTip) { $0 == true }
    }

    var title: Text {
        Text("Explore Color Details")
    }

    var message: Text? {
        Text("Tap any color swatch to view its details, copy values, and find harmonious colors.")
    }

    var image: Image? {
        Image(systemName: "info.circle.fill")
    }

    var options: [TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

// MARK: - Drag and Drop Tip

/// Tip shown after creating the first palette, explaining drag and drop.
struct DragAndDropTip: Tip {

    /// Rule: Only show after the user has created at least one palette.
    @Parameter
    static var hasCreatedPalette: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasCreatedPalette) { $0 == true }
    }

    var title: Text {
        Text("Organize with Drag & Drop")
    }

    var message: Text? {
        Text("Tap and hold any color swatch, then drag it to move colors between palettes.")
    }

    var image: Image? {
        Image(systemName: "hand.draw.fill")
    }

    var options: [TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

// MARK: - Palette Menu Tip

/// Tip explaining the palette menu button for actions.
struct PaletteMenuTip: Tip {

    /// Rule: Only show after the user has created at least one palette.
    @Parameter
    static var hasCreatedPalette: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasCreatedPalette) { $0 == true }
    }

    var title: Text {
        Text("Palette Actions")
    }

    var message: Text? {
        Text("Use this menu to rename, share, export, or delete your palette.")
    }

    var image: Image? {
        Image(systemName: "ellipsis.circle.fill")
    }

    var options: [TipOption] {
        Tips.MaxDisplayCount(1)
    }
}
