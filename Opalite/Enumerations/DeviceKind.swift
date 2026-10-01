//
//  DeviceKind.swift
//  Opalite
//
//  Created by Nick Molargik on 12/22/25.
//

import Foundation

enum DeviceKind {
    case appleWatch
    case visionPro
    case iPhone
    case iPad
    case iMac
    case macStudio
    case macMini
    case macPro
    case macBook
    case unknown

    var symbolName: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .visionPro:  return "vision.pro"
        case .iPhone:     return "iphone"
        case .iPad:       return "ipad"
        case .iMac:       return "desktopcomputer"
        case .macStudio:  return "macstudio"
        case .macMini:    return "macmini"
        case .macPro:     return "macpro.gen3"
        case .macBook:    return "macbook"
        case .unknown:    return "ipad.and.iphone"
        }
    }

    static func from(_ deviceName: String?) -> DeviceKind {
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

        return .unknown
    }
}
