//
//  SwatchBarViewModel.swift
//  OpaliteFeatureSwatchBar
//
//  The host-testable state behind the SwatchBar window: the search filter, which sections
//  are collapsed, the swatch density, and the quick-add hex field's validation. It reads
//  the portfolio through `PortfolioModel` and never touches the store directly. Kept out of
//  the `#if os(iOS) || os(visionOS)` gate so the macOS host can run its tests.
//

import Foundation
import Observation
import OpaliteCore
import OpaliteFeatureShared
import os

// MARK: - Swatch density

/// How much room each swatch gets in the narrow window. Sized for a 250pt-wide window:
/// `compact` packs four small squares per row, `regular` fits two labeled tiles, and
/// `large` gives each color a full-width band — all grow into extra columns as the user
/// widens the window.
nonisolated public enum SwatchBarSwatchSize: String, CaseIterable, Identifiable, Sendable {
    case compact
    case regular
    case large

    public var id: String { rawValue }

    /// The narrowest a swatch may be before the grid drops a column.
    public var minimumSide: CGFloat {
        switch self {
        case .compact: 44
        case .regular: 96
        case .large: 200
        }
    }

    /// The swatch height. `compact` is square, so this is nil.
    public var height: CGFloat? {
        switch self {
        case .compact: nil
        case .regular: 72
        case .large: 104
        }
    }

    /// Whether the swatch shows its name/hex badge. Compact squares are too small.
    public var showsOverlays: Bool { self != .compact }

    /// Whether the badge shows name *and* hex rather than just the display name.
    public var showsHexInBadge: Bool { self == .large }

    /// The next size when cycling with the toolbar toggle; wraps around.
    public var next: SwatchBarSwatchSize {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    public var title: String {
        switch self {
        case .compact: String(localized: "Compact")
        case .regular: String(localized: "Regular")
        case .large: String(localized: "Large")
        }
    }

    public var systemImage: String {
        switch self {
        case .compact: "square.grid.3x3"
        case .regular: "square.grid.2x2"
        case .large: "rectangle.grid.1x2"
        }
    }
}

// MARK: - Quick-add validation

/// What the quick-add field's text currently means. Drives the button state, the inline
/// preview chip, and the hint under the field.
nonisolated public enum SwatchBarQuickAddState: Equatable, Sendable {
    /// Nothing typed yet.
    case empty
    /// Only hex digits so far, but not a complete 3/4/6/8-digit code.
    case incomplete
    /// Contains characters that can never form a hex code.
    case invalid
    /// A complete code; `duplicateOf` names an existing color with the same hex, if any.
    case valid(RGBA, hex: String, duplicateOf: String?)

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    public var rgba: RGBA? {
        if case .valid(let rgba, _, _) = self { return rgba }
        return nil
    }
}

// MARK: - Sections

/// One collapsible group in the list: a palette's colors or the loose colors.
public struct SwatchBarSection: Identifiable {
    public enum Kind: Hashable, Sendable {
        case palette(UUID)
        case loose
    }

    public let kind: Kind
    public let title: String
    public let systemImage: String
    public let colors: [OpaliteColor]

    public var id: Kind { kind }
    public var count: Int { colors.count }
}

// MARK: - View model

@MainActor
@Observable
public final class SwatchBarViewModel {

    /// Defaults keys owned by this window. (Candidates for `AppStorageKeys` once the
    /// SwatchBar's preferences are shared with Settings.)
    nonisolated public enum Keys {
        public static let swatchSize = "swatchBarSwatchSize"
    }

    /// The longest text the hex field accepts: "#" plus eight digits.
    public static let maximumHexLength = 9

    @ObservationIgnored private let defaults: any KeyValueStoring

    // MARK: State

    /// The search text; empty shows everything.
    public var query = ""

    /// The quick-add field's raw text.
    public var quickAddText = "" {
        didSet {
            if quickAddText.count > Self.maximumHexLength {
                quickAddText = String(quickAddText.prefix(Self.maximumHexLength))
            }
        }
    }

    /// Sections the user has collapsed. Searching ignores this so matches are always visible.
    public private(set) var collapsedSections: Set<SwatchBarSection.Kind> = []

    /// The swatch density; persisted across launches.
    public var swatchSize: SwatchBarSwatchSize {
        didSet { defaults.set(swatchSize.rawValue, forKey: Keys.swatchSize) }
    }

    public init(defaults: any KeyValueStoring = UserDefaults.standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Keys.swatchSize) ?? ""
        self.swatchSize = SwatchBarSwatchSize(rawValue: stored) ?? .regular
    }

    // MARK: - Derived

    public var isSearching: Bool { !PortfolioSearch.normalized(query).isEmpty }

    /// The sections to show: the user's active palettes (in their order) that have colors,
    /// then the loose colors. While searching, only matching colors remain and empty
    /// sections drop out; a palette whose name matches keeps all of its colors.
    public func sections(from portfolio: PortfolioModel) -> [SwatchBarSection] {
        var sections: [SwatchBarSection] = []

        for palette in portfolio.orderedPalettes {
            let colors = palette.sortedColors
            guard !colors.isEmpty else { continue }
            let visible: [OpaliteColor]
            if isSearching {
                if PortfolioSearch.matches(paletteName: palette.name, notes: palette.notes, tags: palette.tags, query: query) {
                    visible = colors
                } else {
                    visible = colors.filter(matches)
                }
            } else {
                visible = colors
            }
            guard !visible.isEmpty else { continue }
            sections.append(SwatchBarSection(kind: .palette(palette.id), title: palette.name, systemImage: "swatchpalette", colors: visible))
        }

        let loose = isSearching ? portfolio.looseColors.filter(matches) : portfolio.looseColors
        if !loose.isEmpty {
            sections.append(SwatchBarSection(kind: .loose, title: String(localized: "Colors"), systemImage: "paintpalette", colors: loose))
        }

        return sections
    }

    /// The number of swatches currently visible across all sections.
    public func visibleColorCount(in portfolio: PortfolioModel) -> Int {
        sections(from: portfolio).reduce(0) { $0 + $1.count }
    }

    private func matches(_ color: OpaliteColor) -> Bool {
        PortfolioSearch.matches(name: color.name, notes: color.notes, hex: color.hexString, rgba: color.rgba, query: query)
    }

    // MARK: - Collapsing

    /// Whether a section's swatches are shown. Searching forces every section open.
    public func isExpanded(_ kind: SwatchBarSection.Kind) -> Bool {
        isSearching || !collapsedSections.contains(kind)
    }

    public func toggle(_ kind: SwatchBarSection.Kind) {
        if collapsedSections.contains(kind) {
            collapsedSections.remove(kind)
        } else {
            collapsedSections.insert(kind)
        }
    }

    /// True when no visible section is collapsed.
    public func allExpanded(in portfolio: PortfolioModel) -> Bool {
        sections(from: portfolio).allSatisfy { isExpanded($0.kind) }
    }

    /// Collapses every section if they are all open; otherwise opens them all.
    public func toggleAll(in portfolio: PortfolioModel) {
        let kinds = sections(from: portfolio).map(\.kind)
        if allExpanded(in: portfolio) {
            collapsedSections.formUnion(kinds)
        } else {
            collapsedSections.subtract(kinds)
        }
    }

    // MARK: - Swatch size

    public func cycleSwatchSize() {
        swatchSize = swatchSize.next
    }

    // MARK: - Quick add

    /// Interprets the quick-add text against the portfolio (to flag duplicates).
    public func quickAddState(in portfolio: PortfolioModel) -> SwatchBarQuickAddState {
        Self.quickAddState(for: quickAddText, existing: portfolio.colors)
    }

    /// Validation of the raw text, exposed for tests and the view's live hint.
    public static func quickAddState(for text: String, existing: [OpaliteColor] = []) -> SwatchBarQuickAddState {
        var digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty else { return .empty }
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard !digits.isEmpty else { return .incomplete }
        guard digits.allSatisfy(\.isHexDigit) else { return .invalid }

        guard let rgba = ColorMath.parseHex(digits) else {
            // Hex digits only, but not a length `parseHex` accepts (1, 2, 5, 7 digits).
            return .incomplete
        }
        let hex = digits.count == 8 ? rgba.hexWithAlphaString : rgba.hexString
        let duplicate = existing.first { candidate in
            digits.count == 8 ? candidate.hexWithAlphaString == hex : (candidate.alpha == 1 && candidate.hexString == hex)
        }
        return .valid(rgba, hex: hex, duplicateOf: duplicate?.displayName)
    }

    /// Creates a loose color from the field when it holds a valid hex; clears the field on
    /// success. Returns the new color, or nil when the text wasn't a complete hex or the
    /// store refused (the portfolio already toasted that).
    @discardableResult
    public func submitQuickAdd(into portfolio: PortfolioModel) -> OpaliteColor? {
        guard case .valid(let rgba, let hex, _) = quickAddState(in: portfolio) else { return nil }
        guard let color = portfolio.createColor(rgba) else {
            Log.portfolio.error("SwatchBar quick-add failed for \(hex, privacy: .public)")
            return nil
        }
        quickAddText = ""
        Log.portfolio.info("SwatchBar quick-added \(hex, privacy: .public)")
        return color
    }
}
