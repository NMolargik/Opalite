//
//  DetailFormatting.swift
//  OpaliteFeaturePortfolio
//
//  Small formatting rules the detail screens share: short device labels for info tiles
//  and date presentation. Pure and host-tested.
//

import Foundation
import OpaliteCore

nonisolated public enum DetailFormatting {
    /// "iPhone", "iPad", "Mac", "Apple Watch", "Apple Vision Pro" — or the raw name when
    /// it isn't a known family. Nil/blank names become an em dash.
    public static func shortDeviceName(_ name: String?) -> String {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return "—" }
        switch DeviceKind.from(name) {
        case .iPhone: return "iPhone"
        case .iPad: return "iPad"
        case .appleWatch: return "Apple Watch"
        case .visionPro: return "Apple Vision Pro"
        case .appleTV: return "Apple TV"
        case .iMac, .macStudio, .macMini, .macPro, .macBook: return "Mac"
        case .unknown: return name
        }
    }

    /// "Feb 8" for info tiles.
    public static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Feb 8, 2026 at 2:14 PM" for detail rows.
    public static func longDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    /// "C 10%  M 20%  Y 30%  K 40%".
    public static func cmykString(_ cmyk: CMYK) -> String {
        func pct(_ value: Double) -> Int { Int((ColorMath.clamp(value) * 100).rounded()) }
        return "cmyk(\(pct(cmyk.cyan))%, \(pct(cmyk.magenta))%, \(pct(cmyk.yellow))%, \(pct(cmyk.key))%)"
    }

    /// Author line: "by Nick" or nil for anonymous/blank.
    public static func authorName(_ name: String?) -> String {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return "—" }
        return name
    }

    /// Normalizes a typed tag: trimmed, no leading "#", collapsed whitespace; nil when empty.
    public static func normalizedTag(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasPrefix("#") { text.removeFirst() }
        let words = text.split(whereSeparator: \.isWhitespace)
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    /// Adds a tag unless an equal (case-insensitive) one exists; returns the new list.
    public static func addingTag(_ raw: String, to tags: [String]) -> [String] {
        guard let tag = normalizedTag(raw) else { return tags }
        if tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) { return tags }
        return tags + [tag]
    }
}
