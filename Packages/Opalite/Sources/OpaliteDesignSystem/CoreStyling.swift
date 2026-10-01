//
//  CoreStyling.swift
//  OpaliteDesignSystem
//
//  Localized titles, icons, and tints for Core enums (Core stays SwiftUI-free and
//  string-free). SwiftUI's key-based initializers resolve these in the app's catalog.
//

import SwiftUI
import OpaliteCore

extension AppTab {
    public var title: String {
        switch self {
        case .portfolio: String(localized: "Portfolio")
        case .community: String(localized: "Community")
        case .search: String(localized: "Search")
        case .canvas: String(localized: "Canvas")
        case .settings: String(localized: "Settings")
        }
    }

    public var color: Color {
        switch self {
        case .portfolio: .blue
        case .community: .teal
        case .search: .green
        case .canvas: .red
        case .settings: .orange
        }
    }
}

extension ColorPickerTab {
    public var title: String {
        switch self {
        case .spectrum: String(localized: "Spectrum")
        case .grid: String(localized: "Grid")
        case .shuffle: String(localized: "Shuffle")
        case .sliders: String(localized: "Channels")
        case .codes: String(localized: "Codes")
        case .image: String(localized: "Image")
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .spectrum: String(localized: "Color spectrum")
        case .grid: String(localized: "Color grid")
        case .shuffle: String(localized: "Shuffle color")
        case .sliders: String(localized: "Channel sliders")
        case .codes: String(localized: "Color codes")
        case .image: String(localized: "Sample from image")
        }
    }
}

extension ColorBlindnessMode {
    public var title: String {
        switch self {
        case .off: String(localized: "Off")
        case .protanopia: String(localized: "Protanopia (Red-blind)")
        case .deuteranopia: String(localized: "Deuteranopia (Green-blind)")
        case .tritanopia: String(localized: "Tritanopia (Blue-blind)")
        case .achromatopsia: String(localized: "Achromatopsia (No Color)")
        }
    }

    public var shortTitle: String {
        switch self {
        case .off: String(localized: "Normal Vision")
        case .protanopia: String(localized: "Protanopia")
        case .deuteranopia: String(localized: "Deuteranopia")
        case .tritanopia: String(localized: "Tritanopia")
        case .achromatopsia: String(localized: "Achromatopsia")
        }
    }

    public var modeDescription: String {
        switch self {
        case .off: String(localized: "No simulation active")
        case .protanopia: String(localized: "Difficulty distinguishing red from green; red appears darker")
        case .deuteranopia: String(localized: "Difficulty distinguishing green from red; most common form")
        case .tritanopia: String(localized: "Difficulty distinguishing blue from yellow; rare form")
        case .achromatopsia: String(localized: "Complete color blindness; sees only in grayscale")
        }
    }
}

extension AppThemeOption {
    public var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

extension AppIconOption {
    public var title: String {
        switch self {
        case .dark: String(localized: "Dark")
        case .light: String(localized: "Light")
        }
    }
}

extension SwatchSize {
    public var accessibilityName: String {
        switch self {
        case .extraSmall: String(localized: "Extra Small")
        case .small: String(localized: "Small")
        case .medium: String(localized: "Medium")
        case .large: String(localized: "Large")
        }
    }
}

extension PreviewBackground {
    public var displayName: String {
        switch self {
        case .white: String(localized: "White")
        case .black: String(localized: "Black")
        case .cream: String(localized: "Cream")
        case .lightGray: String(localized: "Light Gray")
        case .darkGray: String(localized: "Dark Gray")
        case .navy: String(localized: "Navy")
        case .forest: String(localized: "Forest")
        case .burgundy: String(localized: "Burgundy")
        }
    }
}

extension CanvasShape {
    public var displayName: String {
        switch self {
        case .square: String(localized: "Square")
        case .rectangle: String(localized: "Rectangle")
        case .circle: String(localized: "Circle")
        case .triangle: String(localized: "Triangle")
        case .line: String(localized: "Line")
        case .arrow: String(localized: "Arrow")
        case .shirt: String(localized: "Shirt")
        }
    }
}

extension CommunitySortOption {
    public var title: String {
        switch self {
        case .newest: String(localized: "Newest")
        case .oldest: String(localized: "Oldest")
        case .alphabetical: String(localized: "A–Z")
        }
    }
}

extension CommunitySegment {
    public var title: String {
        switch self {
        case .colors: String(localized: "Colors")
        case .palettes: String(localized: "Palettes")
        }
    }
}

extension ReportReason {
    public var title: String {
        switch self {
        case .inappropriate: String(localized: "Inappropriate Content")
        case .copyright: String(localized: "Copyright Violation")
        case .spam: String(localized: "Spam")
        case .other: String(localized: "Other")
        }
    }
}

extension OnyxSubscription {
    public var displayName: String {
        switch self {
        case .annual: String(localized: "Onyx Annual")
        case .lifetime: String(localized: "Onyx Lifetime")
        }
    }

    public var priceDescription: String {
        switch self {
        case .annual: String(localized: "per year")
        case .lifetime: String(localized: "one-time purchase")
        }
    }
}

extension ColorExportFormat {
    public var displayName: String {
        switch self {
        case .image: String(localized: "Save as Image")
        case .opalite: String(localized: "Opalite Color")
        case .ase: String(localized: "Adobe Swatch Exchange")
        case .procreate: String(localized: "Procreate Swatch")
        case .gpl: String(localized: "GIMP Palette")
        case .css: String(localized: "CSS Code")
        case .swiftui: String(localized: "SwiftUI Code")
        }
    }

    public var formatDescription: String {
        switch self {
        case .image: String(localized: "Share as a PNG image. Perfect for social media or design inspiration.")
        case .opalite: String(localized: "Native Opalite format. Import back into Opalite on any device.")
        case .ase: String(localized: "Works with Adobe Photoshop, Illustrator, InDesign, and other Adobe apps.")
        case .procreate: String(localized: "Import directly into Procreate on iPad for digital painting.")
        case .gpl: String(localized: "Works with GIMP, Inkscape, Krita, and other open-source tools.")
        case .css: String(localized: "A CSS custom property ready to paste into your stylesheets.")
        case .swiftui: String(localized: "A SwiftUI Color extension ready for your Xcode project.")
        }
    }

    public var tint: Color {
        switch self {
        case .image: .cyan
        case .opalite: .purple
        case .ase: .red
        case .procreate: .orange
        case .gpl: .green
        case .css: .blue
        case .swiftui: .orange
        }
    }
}

extension PaletteExportFormat {
    public var displayName: String {
        switch self {
        case .image: String(localized: "Save as Image")
        case .pdf: String(localized: "PDF Document")
        case .opalite: String(localized: "Opalite Palette")
        case .ase: String(localized: "Adobe Swatch Exchange")
        case .procreate: String(localized: "Procreate Swatches")
        case .gpl: String(localized: "GIMP Palette")
        case .css: String(localized: "CSS Code")
        case .swiftui: String(localized: "SwiftUI Code")
        }
    }

    public var formatDescription: String {
        switch self {
        case .image: String(localized: "Share as a PNG image. Perfect for social media or design inspiration.")
        case .pdf: String(localized: "A PDF with color details. Great for printing or sharing with clients.")
        case .opalite: String(localized: "Native Opalite format. Import back into Opalite on any device.")
        case .ase: String(localized: "Works with Adobe Photoshop, Illustrator, InDesign, and other Adobe apps.")
        case .procreate: String(localized: "Import directly into Procreate on iPad for digital painting.")
        case .gpl: String(localized: "Works with GIMP, Inkscape, Krita, and other open-source tools.")
        case .css: String(localized: "CSS custom properties ready to paste into your stylesheets.")
        case .swiftui: String(localized: "A SwiftUI Color extension ready for your Xcode project.")
        }
    }

    public var tint: Color {
        switch self {
        case .image: .cyan
        case .pdf: .red
        case .opalite: .purple
        case .ase: .red
        case .procreate: .orange
        case .gpl: .green
        case .css: .blue
        case .swiftui: .orange
        }
    }
}

extension WCAGConformance.Level {
    public var color: Color {
        switch self {
        case .aaa: .green
        case .aa: .mint
        case .aaLarge: .orange
        case .fail: .red
        }
    }

    public var title: String {
        switch self {
        case .aaa: String(localized: "AAA")
        case .aa: String(localized: "AA")
        case .aaLarge: String(localized: "AA Large")
        case .fail: String(localized: "Fail")
        }
    }
}
