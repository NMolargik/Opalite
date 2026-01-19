//
//  Color-rgbaComponents.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

extension Color {
    /// Attempts to extract RGBA components (in the sRGB color space) from a SwiftUI Color.
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double)? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        return (Double(r), Double(g), Double(b), Double(a))
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        // On macOS, bridge to NSColor and extract sRGB components
        let nsColor = NSColor(self)
            .usingColorSpace(.sRGB) ?? NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
        #else
        // Unsupported platform
        return nil
        #endif
    }

    #if canImport(UIKit)
    var uiColor: UIColor {
        UIColor(self)
    }
    #endif
}
