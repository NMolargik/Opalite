//
//  SystemColorSampler.swift
//  Opalite
//
//  Created by Nick Molargik on 12/30/25.
//

import UIKit
import ObjectiveC

/// Provides system-wide color sampling on Mac Catalyst using NSColorSampler.
/// This allows sampling colors from anywhere on screen, including other apps.
enum SystemColorSampler {

    /// Shows the system color sampler (eyedropper) and returns the selected color.
    /// - Parameter completion: Called with the sampled color, or nil if cancelled/failed.
    static func sample(completion: @escaping (UIColor?) -> Void) {
        // Dynamically load NSColorSampler from AppKit
        guard let samplerClass = NSClassFromString("NSColorSampler") as? NSObject.Type else {
            print("[SystemColorSampler] NSColorSampler class not found")
            completion(nil)
            return
        }

        // Create an instance of NSColorSampler
        let sampler = samplerClass.init()

        // Define the completion block that NSColorSampler expects
        // NSColorSampler's showSamplerWithSelectionHandler: takes a block (NSColor?) -> Void
        let handler: @convention(block) (AnyObject?) -> Void = { nsColorObj in
            DispatchQueue.main.async {
                guard let nsColor = nsColorObj else {
                    completion(nil)
                    return
                }

                // Convert NSColor to UIColor by extracting sRGB components
                if let uiColor = extractUIColor(from: nsColor) {
                    completion(uiColor)
                } else {
                    completion(nil)
                }
            }
        }

        // Call showSamplerWithSelectionHandler: using performSelector
        let selector = NSSelectorFromString("showSamplerWithSelectionHandler:")

        if sampler.responds(to: selector) {
            sampler.perform(selector, with: handler)
        } else {
            print("[SystemColorSampler] NSColorSampler does not respond to showSamplerWithSelectionHandler:")
            completion(nil)
        }
    }

    /// Extracts UIColor from an NSColor object using dynamic method calls.
    private static func extractUIColor(from nsColor: AnyObject) -> UIColor? {
        // First, convert to sRGB color space for consistent color values
        let sRGBSelector = NSSelectorFromString("colorUsingColorSpace:")
        let sRGBColorSpaceSelector = NSSelectorFromString("sRGBColorSpace")

        guard let colorSpaceClass = NSClassFromString("NSColorSpace") as? NSObject.Type else {
            return extractComponentsDirectly(from: nsColor)
        }

        // Get sRGB color space
        guard colorSpaceClass.responds(to: sRGBColorSpaceSelector),
              let sRGBColorSpace = colorSpaceClass.perform(sRGBColorSpaceSelector)?.takeUnretainedValue() else {
            return extractComponentsDirectly(from: nsColor)
        }

        // Convert color to sRGB
        var colorInSRGB: AnyObject = nsColor
        if nsColor.responds(to: sRGBSelector) {
            if let converted = nsColor.perform(sRGBSelector, with: sRGBColorSpace)?.takeUnretainedValue() {
                colorInSRGB = converted
            }
        }

        return extractComponentsDirectly(from: colorInSRGB)
    }

    /// Extracts RGBA components directly from an NSColor object.
    private static func extractComponentsDirectly(from nsColor: AnyObject) -> UIColor? {
        // Try to get components using redComponent, greenComponent, etc.
        let redSelector = NSSelectorFromString("redComponent")
        let greenSelector = NSSelectorFromString("greenComponent")
        let blueSelector = NSSelectorFromString("blueComponent")
        let alphaSelector = NSSelectorFromString("alphaComponent")

        guard nsColor.responds(to: redSelector),
              nsColor.responds(to: greenSelector),
              nsColor.responds(to: blueSelector),
              nsColor.responds(to: alphaSelector) else {
            // Try alternative approach using CGColor
            return extractViaCGColor(from: nsColor)
        }

        // Use IMP and method signatures to call the component getters
        // These return CGFloat (Double on 64-bit)
        typealias ComponentGetter = @convention(c) (AnyObject, Selector) -> CGFloat

        let redIMP = unsafeBitCast(
            class_getMethodImplementation(type(of: nsColor), redSelector),
            to: ComponentGetter.self
        )
        let greenIMP = unsafeBitCast(
            class_getMethodImplementation(type(of: nsColor), greenSelector),
            to: ComponentGetter.self
        )
        let blueIMP = unsafeBitCast(
            class_getMethodImplementation(type(of: nsColor), blueSelector),
            to: ComponentGetter.self
        )
        let alphaIMP = unsafeBitCast(
            class_getMethodImplementation(type(of: nsColor), alphaSelector),
            to: ComponentGetter.self
        )

        let red = redIMP(nsColor, redSelector)
        let green = greenIMP(nsColor, greenSelector)
        let blue = blueIMP(nsColor, blueSelector)
        let alpha = alphaIMP(nsColor, alphaSelector)

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Fallback: Extract color via CGColor property.
    private static func extractViaCGColor(from nsColor: AnyObject) -> UIColor? {
        let cgColorSelector = NSSelectorFromString("CGColor")

        guard nsColor.responds(to: cgColorSelector) else {
            print("[SystemColorSampler] Cannot extract color components")
            return nil
        }

        // CGColor is a struct/ref type, need careful handling
        typealias CGColorGetter = @convention(c) (AnyObject, Selector) -> CGColor

        let cgColorIMP = unsafeBitCast(
            class_getMethodImplementation(type(of: nsColor), cgColorSelector),
            to: CGColorGetter.self
        )

        let cgColor = cgColorIMP(nsColor, cgColorSelector)
        return UIColor(cgColor: cgColor)
    }
}
