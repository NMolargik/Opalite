//
//  SwatchBarSupport.swift
//  OpaliteDesignSystem
//
//  Whether this device gets the SwatchBar, the slim second window that parks beside other
//  apps. It is an iPad, Mac, and visionOS feature: iPhone, including iPhone Duo, has no
//  room for a floating panel even where the system allows a second scene, so every entry
//  point (Settings, the Portfolio menu, the deep link, the menu bar, the quick action, and
//  the scene itself) asks here instead of `supportsMultipleWindows`.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum SwatchBarSupport {
    /// True on iPad, Mac Catalyst, and visionOS; false on iPhone, including iPhone Duo.
    public static var isAvailable: Bool {
        #if os(visionOS) || targetEnvironment(macCatalyst)
        true
        #elseif os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }
}
