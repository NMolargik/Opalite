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
        Color(uiColor: UIColor { @Sendable trait in trait.userInterfaceStyle == .dark ? .white : .black })
        #else
        Color.primary
        #endif
    }

    // MARK: Text-safe variants

    /// The brand blue deepened until it reads as text on white (5.1:1).
    public static let opaliteBlueDeep = Color(.displayP3, red: 0x23 / 255, green: 0x75 / 255, blue: 0x9E / 255)
    /// The brand purple deepened until white text reads on it (5.5:1).
    public static let opalitePurpleDeep = Color(.displayP3, red: 0x6C / 255, green: 0x64 / 255, blue: 0x82 / 255)
    /// The brand tan deepened until it reads as text on white (4.5:1).
    public static let opaliteTanDeep = Color(.displayP3, red: 0x7E / 255, green: 0x75 / 255, blue: 0x69 / 255)

    /// Blue for text and glyphs: deep in light mode, the pale brand blue in dark mode.
    public static var opaliteBlueInk: Color { adaptive(light: .opaliteBlueDeep, dark: .opaliteBlue) }
    /// Purple for text and glyphs: deep in light mode, the brand purple in dark mode.
    public static var opalitePurpleInk: Color { adaptive(light: .opalitePurpleDeep, dark: .opalitePurple) }
    /// Tan for text and glyphs: deep in light mode, the brand tan in dark mode.
    public static var opaliteTanInk: Color { adaptive(light: .opaliteTanDeep, dark: .opaliteTan) }

    /// The text-safe version of a brand tint (`opaliteBlue` → `opaliteBlueInk`); any other
    /// color passes through. Button styles use it for tinted labels.
    public var inkVariant: Color {
        switch self {
        case .opaliteBlue: .opaliteBlueInk
        case .opalitePurple: .opalitePurpleInk
        case .opaliteTan: .opaliteTanInk
        default: self
        }
    }

    /// The version of a brand tint that carries white text in either appearance
    /// (prominent fills); any other color passes through.
    public var fillVariant: Color {
        switch self {
        case .opaliteBlue: .opaliteBlueDeep
        case .opalitePurple: .opalitePurpleDeep
        case .opaliteTan: .opaliteTanDeep
        default: self
        }
    }

    /// UIKit resolves dynamic colors on SwiftUI's render thread, so the provider closure
    /// must stay off the main actor: resolve both `UIColor`s up front and capture them.
    private nonisolated static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit) && !os(watchOS)
        let lightColor = UIColor(light)
        let darkColor = UIColor(dark)
        return Color(uiColor: UIColor { @Sendable trait in trait.userInterfaceStyle == .dark ? darkColor : lightColor })
        #else
        return light
        #endif
    }
}

extension ShapeStyle where Self == Color {
    public static var opaliteBlue: Color { Color.opaliteBlue }
    public static var opalitePurple: Color { Color.opalitePurple }
    public static var opaliteTan: Color { Color.opaliteTan }
    public static var onyx: Color { Color.onyx }
    public static var opaliteBlueInk: Color { Color.opaliteBlueInk }
    public static var opalitePurpleInk: Color { Color.opalitePurpleInk }
    public static var opaliteTanInk: Color { Color.opaliteTanInk }
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
