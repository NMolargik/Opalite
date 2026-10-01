//
//  ContrastCheck.swift
//  OpaliteFeaturePortfolio
//
//  The contrast checker's state: a source color, an optional comparison, and the WCAG
//  criteria the pair meets. Comparison can come from a preset, a hex code, or another
//  color in the portfolio. Pure, so the pairing rules are host-tested.
//

import Foundation
import OpaliteCore

/// A portfolio color offered as a comparison.
nonisolated public struct ContrastCandidate: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String?
    public let rgba: RGBA

    public init(id: UUID, name: String?, rgba: RGBA) {
        self.id = id
        self.name = name
        self.rgba = rgba
    }

    public var label: String { name ?? rgba.hexString }
}

nonisolated public struct ContrastCheck: Equatable, Sendable {
    // MARK: - Criteria

    /// WCAG 2.x success criteria for text, in the order they're displayed.
    public enum Criterion: String, CaseIterable, Identifiable, Sendable {
        case aaNormal
        case aaLarge
        case aaaNormal
        case aaaLarge

        public var id: String { rawValue }

        public var threshold: Double {
            switch self {
            case .aaNormal: 4.5
            case .aaLarge: 3.0
            case .aaaNormal: 7.0
            case .aaaLarge: 4.5
            }
        }

        public var title: String {
            switch self {
            case .aaNormal: String(localized: "AA Normal")
            case .aaLarge: String(localized: "AA Large")
            case .aaaNormal: String(localized: "AAA Normal")
            case .aaaLarge: String(localized: "AAA Large")
            }
        }

        public var detail: String {
            switch self {
            case .aaNormal: String(localized: "Body text, 4.5:1")
            case .aaLarge: String(localized: "Large text, 3:1")
            case .aaaNormal: String(localized: "Enhanced body text, 7:1")
            case .aaaLarge: String(localized: "Enhanced large text, 4.5:1")
            }
        }
    }

    // MARK: - Presets

    /// Quick comparisons every designer reaches for.
    public enum Preset: String, CaseIterable, Identifiable, Sendable {
        case white
        case black
        case gray

        public var id: String { rawValue }

        public var rgba: RGBA {
            switch self {
            case .white: .white
            case .black: .black
            case .gray: RGBA(red: 0.5, green: 0.5, blue: 0.5)
            }
        }

        public var title: String {
            switch self {
            case .white: String(localized: "White")
            case .black: String(localized: "Black")
            case .gray: String(localized: "Gray")
            }
        }
    }

    // MARK: - State

    public var source: RGBA
    public var comparison: RGBA?

    public init(source: RGBA, comparison: RGBA? = nil) {
        self.source = source
        self.comparison = comparison
    }

    public var hasComparison: Bool { comparison != nil }

    /// The WCAG contrast ratio, 1...21, once a comparison is chosen.
    public var ratio: Double? {
        comparison.map { source.contrastRatio(against: $0) }
    }

    public var conformance: WCAGConformance? {
        ratio.map(WCAGConformance.init(ratio:))
    }

    /// "4.52:1", or an em dash placeholder before a comparison is chosen.
    public var ratioText: String {
        conformance?.ratioText ?? "—:1"
    }

    public func passes(_ criterion: Criterion) -> Bool {
        guard let ratio else { return false }
        return ratio >= criterion.threshold
    }

    /// The criteria the pair currently meets.
    public var passingCriteria: [Criterion] {
        Criterion.allCases.filter(passes)
    }

    // MARK: - Choosing a comparison

    public mutating func select(_ preset: Preset) {
        comparison = preset.rgba
    }

    public mutating func select(_ candidate: ContrastCandidate) {
        comparison = candidate.rgba
    }

    /// Applies a typed hex code; returns false (and leaves the comparison alone) when the
    /// text isn't a complete code.
    @discardableResult
    public mutating func select(hex: String) -> Bool {
        guard let parsed = RGBA(hex: hex) else { return false }
        comparison = parsed
        return true
    }

    public mutating func clearComparison() {
        comparison = nil
    }

    /// Portfolio colors worth offering as comparisons: everything but the source, capped.
    public static func candidates(from colors: [ContrastCandidate], excluding sourceID: UUID?, limit: Int = 24) -> [ContrastCandidate] {
        Array(colors.filter { $0.id != sourceID }.prefix(limit))
    }
}
