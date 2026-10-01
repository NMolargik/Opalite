//
//  DeviceKind.swift
//  OpaliteCore
//
//  Classifies a device description ("iPhone 17 Pro", "MacBook Pro") into an SF Symbol.
//

import Foundation

nonisolated public enum DeviceKind: Sendable, Equatable {
    case appleWatch, visionPro, iPhone, iPad, iMac, macStudio, macMini, macPro, macBook, appleTV, unknown

    public var systemImage: String {
        switch self {
        case .appleWatch: "applewatch"
        case .visionPro: "vision.pro"
        case .iPhone: "iphone"
        case .iPad: "ipad"
        case .iMac: "desktopcomputer"
        case .macStudio: "macstudio"
        case .macMini: "macmini"
        case .macPro: "macpro.gen3"
        case .macBook: "macbook"
        case .appleTV: "appletv"
        case .unknown: "ipad.and.iphone"
        }
    }

    public static func from(_ deviceName: String?) -> DeviceKind {
        guard let deviceName = deviceName?.trimmingCharacters(in: .whitespacesAndNewlines), !deviceName.isEmpty else {
            return .unknown
        }
        let name = deviceName.lowercased()
        if name.contains("watch") { return .appleWatch }
        if name.contains("vision") { return .visionPro }
        if name.contains("iphone") { return .iPhone }
        if name.contains("ipad") { return .iPad }
        if name.contains("imac") { return .iMac }
        if name.contains("mac studio") || name.contains("macstudio") { return .macStudio }
        if name.contains("mac mini") || name.contains("macmini") { return .macMini }
        if name.contains("mac pro") || name.contains("macpro") { return .macPro }
        if name.contains("macbook") { return .macBook }
        if name.contains("apple tv") || name.contains("appletv") { return .appleTV }
        return .unknown
    }
}
