//
//  PortfolioLayout.swift
//  OpaliteFeaturePortfolio
//
//  The pure layout decisions of the Portfolio root: which sections appear and in what
//  order, the navigation subtitle, how the swatch-size toggle cycles, and when palettes
//  flow into two columns. Value types only, so every rule is host-tested.
//

import Foundation
import CoreGraphics
import OpaliteCore

// MARK: - Sections

nonisolated public enum PortfolioSectionKind: Hashable, Sendable {
    case loose
    case palette(UUID)
}

/// A value snapshot of one palette as the root needs it.
nonisolated public struct PaletteSummary: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let colorIDs: [UUID]

    public init(id: UUID, name: String, colorIDs: [UUID]) {
        self.id = id
        self.name = name
        self.colorIDs = colorIDs
    }
}

/// One row of the Portfolio: the loose colors, or a palette.
nonisolated public struct PortfolioSection: Identifiable, Hashable, Sendable {
    public let kind: PortfolioSectionKind
    public let title: String
    public let colorIDs: [UUID]

    public init(kind: PortfolioSectionKind, title: String, colorIDs: [UUID]) {
        self.kind = kind
        self.title = title
        self.colorIDs = colorIDs
    }

    public var id: PortfolioSectionKind { kind }
    public var count: Int { colorIDs.count }
    public var isLoose: Bool { kind == .loose }

    public var paletteID: UUID? {
        if case .palette(let id) = kind { return id }
        return nil
    }
}

// MARK: - Layout rules

nonisolated public enum PortfolioLayout {
    /// Windows at least this wide (in a regular size class) show palettes in two columns.
    public static let wideWindowThreshold: CGFloat = 900

    /// The minimum width of a palette card in the two-column grid.
    public static let paletteCardMinimumWidth: CGFloat = 420

    /// The sections in display order: loose colors first, then the palettes in the
    /// user's order. The loose section is always present so the drop target exists.
    public static func sections(looseColorIDs: [UUID], palettes: [PaletteSummary]) -> [PortfolioSection] {
        let loose = PortfolioSection(kind: .loose, title: String(localized: "Colors"), colorIDs: looseColorIDs)
        let paletteSections = palettes.map { PortfolioSection(kind: .palette($0.id), title: $0.name, colorIDs: $0.colorIDs) }
        return [loose] + paletteSections
    }

    /// "12 colors · 3 palettes" (grammar-agreed), or nil for an empty portfolio.
    public static func subtitle(colorCount: Int, paletteCount: Int) -> String? {
        guard colorCount > 0 || paletteCount > 0 else { return nil }
        let colors = colorCount == 1 ? String(localized: "1 color") : String(localized: "\(colorCount) colors")
        let palettes = paletteCount == 1 ? String(localized: "1 palette") : String(localized: "\(paletteCount) palettes")
        return "\(colors) · \(palettes)"
    }

    /// The size after a tap on the swatch-size toggle: compact widths skip `large`.
    public static func nextSwatchSize(after size: SwatchSize, isCompactWidth: Bool) -> SwatchSize {
        isCompactWidth ? size.nextCompact : size.next
    }

    /// Whether the next toggle grows the swatches (for the toolbar glyph).
    public static func nextSwatchSizeGrows(after size: SwatchSize, isCompactWidth: Bool) -> Bool {
        nextSwatchSize(after: size, isCompactWidth: isCompactWidth).side > size.side
    }

    /// Two palette columns only in a regular size class with a wide window and enough
    /// palettes to fill them.
    public static func paletteColumns(width: CGFloat, isRegularWidth: Bool, paletteCount: Int) -> Int {
        guard isRegularWidth, width >= wideWindowThreshold, paletteCount > 1 else { return 1 }
        return 2
    }

    /// A short "Delete n colors?" style title for batch confirmation.
    public static func batchDeleteTitle(count: Int) -> String {
        count == 1 ? String(localized: "Delete 1 Color?") : String(localized: "Delete \(count) Colors?")
    }
}

// MARK: - Selection

/// Multi-select state for the loose colors row (select → move/delete in one go).
nonisolated public struct LooseColorSelection: Equatable, Sendable {
    public private(set) var isActive = false
    public private(set) var selectedIDs: Set<UUID> = []

    public init() {}

    public var isEmpty: Bool { selectedIDs.isEmpty }
    public var count: Int { selectedIDs.count }

    public mutating func begin() {
        isActive = true
        selectedIDs.removeAll()
    }

    public mutating func end() {
        isActive = false
        selectedIDs.removeAll()
    }

    public mutating func toggle(_ id: UUID) {
        guard isActive else { return }
        if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
    }

    public func isAllSelected(of ids: [UUID]) -> Bool {
        !ids.isEmpty && Set(ids).isSubset(of: selectedIDs)
    }

    /// Selects everything, or clears when everything was already selected.
    public mutating func toggleAll(of ids: [UUID]) {
        guard isActive else { return }
        if isAllSelected(of: ids) { selectedIDs.removeAll() } else { selectedIDs = Set(ids) }
    }

    /// Drops ids that no longer exist (a color deleted elsewhere).
    public mutating func prune(keeping ids: [UUID]) {
        selectedIDs.formIntersection(ids)
    }
}
