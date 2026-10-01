//
//  Tips.swift
//  OpaliteFeaturePortfolio
//
//  The Portfolio's TipKit guidance: the first "create something" nudge, then — once the
//  user has content — how to open details, drag between palettes, and find the palette
//  menu. The shell calls `Tips.configure`; this file only declares the tips and the one
//  hook that advances them after content is created.
//

#if canImport(TipKit)
import SwiftUI
import TipKit

/// Advances the onboarding tips once the user has made something.
public enum PortfolioTips {
    /// Call after a color or palette is created so the follow-on tips become eligible.
    public static func advanceAfterContentCreation() {
        ColorDetailsTip.hasSeenCreateTip = true
        DragAndDropTip.hasCreatedPalette = true
        PaletteMenuTip.hasCreatedPalette = true
    }
}

// MARK: - Create content

/// Shown to new users: the + menu creates colors, palettes, and imports.
nonisolated struct CreateContentTip: Tip {
    var title: Text { Text("Create Your First Color") }

    var message: Text? {
        Text("Use the + button to create a color, start a palette, add a hex code, or import a file.")
    }

    var image: Image? { Image(systemName: "sparkles") }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

// MARK: - Color details

/// Tapping a swatch opens its details. Only eligible after the create tip was seen.
nonisolated struct ColorDetailsTip: Tip {
    @Parameter
    static var hasSeenCreateTip: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasSeenCreateTip) { $0 == true }
    }

    var title: Text { Text("Color Details") }

    var message: Text? {
        Text("Tap any swatch to see its codes, find harmonious colors, and check contrast.")
    }

    var image: Image? { Image(systemName: "info.circle.fill") }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

// MARK: - Drag and drop

/// Organizing by drag and drop, once there's a palette to drop into.
nonisolated struct DragAndDropTip: Tip {
    @Parameter
    static var hasCreatedPalette: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasCreatedPalette) { $0 == true }
    }

    var title: Text { Text("Organize with Drag & Drop") }

    var message: Text? {
        Text("Touch and hold a swatch, then drag it onto a palette to move it.")
    }

    var image: Image? { Image(systemName: "hand.draw.fill") }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

// MARK: - Palette menu

/// The palette overflow menu, once there's a palette.
nonisolated struct PaletteMenuTip: Tip {
    @Parameter
    static var hasCreatedPalette: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasCreatedPalette) { $0 == true }
    }

    var title: Text { Text("Palette Actions") }

    var message: Text? {
        Text("Use a palette's menu to rename, export, publish, archive, or delete it.")
    }

    var image: Image? { Image(systemName: "ellipsis.circle.fill") }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(1)
    }
}

// MARK: - Screen sampler (Mac only)

#if targetEnvironment(macCatalyst)
/// The system-wide eyedropper on the Mac.
nonisolated struct ScreenSamplerTip: Tip {
    var title: Text { Text("Sample Colors from Anywhere") }

    var message: Text? {
        Text("Choose + › Sample from Screen (⌘⇧E) to pick a color from any app on your Mac.")
    }

    var image: Image? { Image(systemName: "macwindow.on.rectangle") }

    var options: [any TipOption] {
        Tips.MaxDisplayCount(3)
    }
}
#endif
#endif
