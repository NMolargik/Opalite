//
//  ColorBridging.swift
//  OpaliteDesignSystem
//
//  SwiftUI/UIKit faces for the Core color types. Core stays SwiftUI-free; every view
//  reaches a model's `Color` through here.
//

import SwiftUI
import OpaliteCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - RGBA

extension RGBA {
    public var color: Color { Color(self) }
    /// Black or white, whichever contrasts better.
    public var idealTextColor: Color { prefersDarkText ? .black : .white }

    #if canImport(UIKit)
    public var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    #endif
}

// MARK: - OpaliteColor

extension OpaliteColor {
    public var swiftUIColor: Color { rgba.color }
    public func idealTextColor() -> Color { rgba.idealTextColor }
    /// The display color with the active color-vision simulation applied.
    public func simulatedSwiftUIColor(_ mode: ColorBlindnessMode) -> Color {
        ColorBlindnessSimulator.simulate(rgba, mode: mode).color
    }
    #if canImport(UIKit)
    public var uiColor: UIColor { rgba.uiColor }
    #endif
}

// MARK: - CommunityColor / WatchColor / WidgetColor

extension CommunityColor {
    public var swiftUIColor: Color { rgba.color }
    public func idealTextColor() -> Color { rgba.idealTextColor }
    public func simulatedSwiftUIColor(_ mode: ColorBlindnessMode) -> Color {
        ColorBlindnessSimulator.simulate(rgba, mode: mode).color
    }
}

extension WatchColor {
    public var swiftUIColor: Color { rgba.color }
    public func idealTextColor() -> Color { rgba.idealTextColor }
}

extension WidgetColor {
    public var swiftUIColor: Color { Color(RGBA(red: red, green: green, blue: blue, alpha: alpha)) }
    public var idealTextColor: Color { prefersDarkText ? .black : .white }
}

extension PreviewBackground {
    public var color: Color { rgba.color }
    public var idealTextColor: Color { prefersDarkText ? .black : .white }
    public static func defaultFor(colorScheme: ColorScheme) -> PreviewBackground { defaultFor(isDark: colorScheme == .dark) }
}

// MARK: - SwiftUI Color → components

extension Color {
    /// The sRGB components of this color, when resolvable.
    public var rgba: RGBA? {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBA(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
        #elseif canImport(AppKit)
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return RGBA(red: Double(ns.redComponent), green: Double(ns.greenComponent), blue: Double(ns.blueComponent), alpha: Double(ns.alphaComponent))
        #else
        return nil
        #endif
    }

    /// "#RRGGBB" for this color, when resolvable.
    public func toHex() -> String? { rgba?.hexString }
}
