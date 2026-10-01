//
//  TVPresentationDeck.swift
//  OpaliteFeatureTV
//
//  The value-type state behind full-screen presentation: a snapshot of the colors being
//  shown and the index being stepped by the remote. Platform-free so it is host-testable.
//

import Foundation
import OpaliteCore

/// A color snapshot for presentation — values only, so the deck never touches SwiftData.
nonisolated public struct TVPresentedColor: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String?
    public let rgba: RGBA

    public init(id: UUID = UUID(), name: String? = nil, rgba: RGBA) {
        self.id = id
        self.name = name
        self.rgba = rgba
    }

    /// The name when there is one, otherwise the hex.
    public var title: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return rgba.hexString
    }

    public var hasName: Bool { name?.trimmingCharacters(in: .whitespaces).isEmpty == false }
}

/// A slideshow of colors with a current position. Stepping wraps around the ends.
nonisolated public struct TVPresentationDeck: Equatable, Sendable {
    public private(set) var colors: [TVPresentedColor]
    public private(set) var index: Int

    public init(colors: [TVPresentedColor], startIndex: Int = 0) {
        self.colors = colors
        self.index = colors.isEmpty ? 0 : max(0, min(startIndex, colors.count - 1))
    }

    public var current: TVPresentedColor? {
        colors.indices.contains(index) ? colors[index] : nil
    }

    public var hasMultiple: Bool { colors.count > 1 }
    public var isEmpty: Bool { colors.isEmpty }

    /// "2 of 5", or nil for a single color.
    public var positionDescription: String? {
        hasMultiple ? String(localized: "\(index + 1) of \(colors.count)") : nil
    }

    public mutating func next() {
        guard hasMultiple else { return }
        index = (index + 1) % colors.count
    }

    public mutating func previous() {
        guard hasMultiple else { return }
        index = (index - 1 + colors.count) % colors.count
    }
}

/// The subtle, OLED-safe drift that keeps presentation mode from holding a static frame:
/// a soft highlight that orbits slowly and a label that wanders a few points.
nonisolated public enum TVDrift {
    /// Where the soft highlight's center is at `time`, as a unit point. Never leaves the
    /// central region so edges stay evenly lit.
    public static func highlightCenter(at time: Double) -> (x: Double, y: Double) {
        (0.5 + 0.22 * cos(time / 23), 0.5 + 0.22 * sin(time / 31))
    }

    /// How far the label is nudged from its resting spot at `time`, in points.
    public static func labelOffset(at time: Double, amplitude: Double = 18) -> (x: Double, y: Double) {
        (amplitude * sin(time / 17), amplitude * 0.6 * cos(time / 13))
    }

    /// The label hides after this long without remote input.
    public static let labelTimeout: Duration = .seconds(6)
}
