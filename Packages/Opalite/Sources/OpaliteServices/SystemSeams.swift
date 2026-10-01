//
//  SystemSeams.swift
//  OpaliteServices
//
//  Production conformances for the small Core seams: device naming (DeviceKit), the
//  pasteboard, and WidgetCenter reloads.
//

import Foundation
import OpaliteCore
#if canImport(DeviceKit)
import DeviceKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Device

nonisolated public struct DeviceInfo: DeviceDescribing {
    public init() {}

    /// The marketing name ("iPhone 17 Pro"), or the model family when unknown.
    public var deviceName: String {
        #if canImport(DeviceKit)
        return Device.current.safeDescription
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "This Device"
        #endif
    }
}

// MARK: - Pasteboard

public final class SystemPasteboard: Pasteboarding {
    public init() {}

    public func copy(string: String) {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    public func copy(data: Data, type: String, fallbackString: String?) {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        UIPasteboard.general.setData(data, forPasteboardType: type)
        if let fallbackString { UIPasteboard.general.string = fallbackString }
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: NSPasteboard.PasteboardType(type))
        if let fallbackString { NSPasteboard.general.setString(fallbackString, forType: .string) }
        #endif
    }
}

// MARK: - Widgets

public struct WidgetCenterReloader: WidgetTimelineReloading {
    nonisolated public init() {}

    public func reloadTimelines(ofKind kind: String) {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        #endif
    }

    public func reloadAllTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
