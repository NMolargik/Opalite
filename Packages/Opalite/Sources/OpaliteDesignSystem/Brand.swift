//
//  Brand.swift
//  OpaliteDesignSystem
//
//  The Molargik Software visual language as used by Opalite: brand colors in code (the
//  app's asset catalog isn't visible to package modules; values match the Display P3
//  colorsets), spacing/radius tokens, and the hex ↔ Color bridge.
//

import SwiftUI
import OpaliteCore

// MARK: - Brand colors

extension Color {
    /// The accent: a pale sky blue (#C4E9F9).
    public static let opaliteBlue = Color(.displayP3, red: 0xC4 / 255, green: 0xE9 / 255, blue: 0xF9 / 255)
    /// A dusty lavender (#9D95AC).
    public static let opalitePurple = Color(.displayP3, red: 0x9D / 255, green: 0x95 / 255, blue: 0xAC / 255)
    /// A warm stone (#DAD5CF).
    public static let opaliteTan = Color(.displayP3, red: 0xDA / 255, green: 0xD5 / 255, blue: 0xCF / 255)
    /// Onyx's near-black.
    public static let onyx = Color(.displayP3, red: 0x14 / 255, green: 0x12 / 255, blue: 0x18 / 255)

    /// Black in light mode, white in dark mode (toolbar glyphs on pre-26 systems).
    public static var opaliteInverse: Color {
        #if canImport(UIKit) && !os(watchOS)
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .white : .black })
        #else
        Color.primary
        #endif
    }
}

extension ShapeStyle where Self == Color {
    public static var opaliteBlue: Color { Color.opaliteBlue }
    public static var opalitePurple: Color { Color.opalitePurple }
    public static var opaliteTan: Color { Color.opaliteTan }
    public static var onyx: Color { Color.onyx }
}

@MainActor extension LinearGradient {
    /// The brand wash: blue → purple → tan, top-leading to bottom-trailing.
    public static var opalite: LinearGradient {
        LinearGradient(colors: [.opaliteBlue, .opalitePurple, .opaliteTan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A soft page background wash of the brand gradient.
    public static var opaliteWash: LinearGradient {
        LinearGradient(colors: [Color.opaliteBlue.opacity(0.25), Color.opalitePurple.opacity(0.18), Color.opaliteTan.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Horizontal blue → purple, for inline text and icons.
    public static var opaliteHorizontal: LinearGradient {
        LinearGradient(colors: [.opaliteBlue, .opalitePurple], startPoint: .leading, endPoint: .trailing)
    }

    /// Onyx's glossy black.
    public static var onyx: LinearGradient {
        LinearGradient(colors: [Color(white: 0.22), .onyx], startPoint: .top, endPoint: .bottom)
    }
}

@MainActor extension AngularGradient {
    /// The full hue wheel (spectrum pickers, harmony wheel).
    public static var hueWheel: AngularGradient {
        AngularGradient(
            colors: stride(from: 0.0, through: 360.0, by: 30).map { Color(hue: $0 / 360, saturation: 1, brightness: 1) },
            center: .center
        )
    }

    /// The Apple Intelligence rainbow ring.
    public static var appleIntelligence: AngularGradient {
        AngularGradient(colors: [.orange, .red, .purple, .blue, .purple, .red, .orange, .orange], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }
}

// MARK: - Tokens

nonisolated public enum Brand {
    /// Spacing scale (4-pt grid).
    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    /// Continuous corner radii.
    public enum Radius {
        public static let chip: CGFloat = 10
        public static let control: CGFloat = 14
        public static let swatch: CGFloat = 16
        public static let card: CGFloat = 18
        public static let sheet: CGFloat = 24
    }

    /// The readable width for centered forms and onboarding content.
    public static let readableWidth: CGFloat = 520

    /// The widest a detail column should grow on iPad/Mac before centering.
    public static let detailMaxWidth: CGFloat = 760
}

// MARK: - Hex colors

nonisolated extension Color {
    /// A Color from "#RRGGBB" / "RRGGBB" / "#RGB" / "#RRGGBBAA", or nil.
    public init?(hex: String) {
        guard let rgba = RGBA(hex: hex) else { return nil }
        self.init(rgba)
    }

    /// A Color from sRGB components.
    public init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
