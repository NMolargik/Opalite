//
//  SystemColorSampler.swift
//  OpaliteServices
//
//  System-wide eyedropper on Mac Catalyst via AppKit's NSColorSampler, reached through the
//  ObjC runtime because AppKit isn't importable from Catalyst code.
//

#if targetEnvironment(macCatalyst)
import UIKit
import ObjectiveC
import OpaliteCore
import os

public enum SystemColorSampler {
    /// Shows the system eyedropper; the result is nil when cancelled or unavailable.
    public static func sample() async -> RGBA? {
        await withCheckedContinuation { continuation in
            sample { continuation.resume(returning: $0) }
        }
    }

    public static func sample(completion: @escaping @MainActor (RGBA?) -> Void) {
        guard let samplerClass = NSClassFromString("NSColorSampler") as? NSObject.Type else {
            Log.app.error("NSColorSampler unavailable")
            completion(nil)
            return
        }
        let sampler = samplerClass.init()
        let handler: @convention(block) (AnyObject?) -> Void = { object in
            let box = UncheckedSendableBox(value: object)
            Task { @MainActor in
                guard let nsColor = box.value else { completion(nil); return }
                completion(extractRGBA(from: nsColor))
            }
        }
        let selector = NSSelectorFromString("showSamplerWithSelectionHandler:")
        guard sampler.responds(to: selector) else { completion(nil); return }
        sampler.perform(selector, with: handler)
    }

    private static func extractRGBA(from nsColor: AnyObject) -> RGBA? {
        var color: AnyObject = nsColor
        if let spaceClass = NSClassFromString("NSColorSpace") as? NSObject.Type,
           spaceClass.responds(to: NSSelectorFromString("sRGBColorSpace")),
           let srgb = spaceClass.perform(NSSelectorFromString("sRGBColorSpace"))?.takeUnretainedValue(),
           nsColor.responds(to: NSSelectorFromString("colorUsingColorSpace:")),
           let converted = nsColor.perform(NSSelectorFromString("colorUsingColorSpace:"), with: srgb)?.takeUnretainedValue() {
            color = converted
        }

        typealias ComponentGetter = @convention(c) (AnyObject, Selector) -> CGFloat
        func component(_ name: String) -> CGFloat? {
            let selector = NSSelectorFromString(name)
            guard color.responds(to: selector), let imp = class_getMethodImplementation(type(of: color), selector) else { return nil }
            return unsafeBitCast(imp, to: ComponentGetter.self)(color, selector)
        }
        guard let r = component("redComponent"), let g = component("greenComponent"), let b = component("blueComponent") else { return nil }
        let a = component("alphaComponent") ?? 1
        return RGBA(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }
}
#endif
