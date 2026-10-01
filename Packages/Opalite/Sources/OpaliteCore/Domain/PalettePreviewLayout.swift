//
//  PalettePreviewLayout.swift
//  OpaliteCore
//
//  Grid geometry for palette previews (sheets, exports, widgets): picks the row count that
//  yields the largest square swatch for the available area.
//

import Foundation
import CoreGraphics

nonisolated public struct PalettePreviewLayout: Equatable, Sendable {
    public let rows: Int
    public let columns: Int
    public let swatchSize: CGFloat
    public let horizontalSpacing: CGFloat
    public let verticalSpacing: CGFloat
    public let showHexBadges: Bool

    public static let empty = PalettePreviewLayout(rows: 0, columns: 0, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0, showHexBadges: false)

    public init(rows: Int, columns: Int, swatchSize: CGFloat, horizontalSpacing: CGFloat, verticalSpacing: CGFloat, showHexBadges: Bool) {
        self.rows = rows
        self.columns = columns
        self.swatchSize = swatchSize
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.showHexBadges = showHexBadges
    }

    public static func calculate(
        colorCount: Int,
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        minSpacing: CGFloat = 6,
        maxSpacing: CGFloat = 12,
        maxRows: Int = 2,
        hexBadgeMinSize: CGFloat? = nil
    ) -> PalettePreviewLayout {
        guard colorCount > 0, availableWidth > 0, availableHeight > 0 else { return .empty }

        var best = PalettePreviewLayout(rows: 1, columns: 1, swatchSize: 0, horizontalSpacing: 0, verticalSpacing: 0, showHexBadges: false)

        for rows in 1...max(1, maxRows) {
            let columns = Int(ceil(Double(colorCount) / Double(rows)))
            let verticalSpacing: CGFloat = rows > 1 ? minSpacing : 0
            let totalVerticalSpacing = CGFloat(rows - 1) * verticalSpacing
            let totalHorizontalSpacing = CGFloat(columns - 1) * maxSpacing

            let maxHeightPerSwatch = (availableHeight - totalVerticalSpacing) / CGFloat(rows)
            let maxWidthPerSwatch = (availableWidth - totalHorizontalSpacing) / CGFloat(columns)
            let swatchSize = max(0, min(maxWidthPerSwatch, maxHeightPerSwatch))

            var horizontalSpacing: CGFloat = columns > 1 ? minSpacing : 0
            if columns > 1 {
                let usedWidth = CGFloat(columns) * swatchSize
                horizontalSpacing = min((availableWidth - usedWidth) / CGFloat(columns - 1), maxSpacing)
            }

            if swatchSize > best.swatchSize {
                best = PalettePreviewLayout(
                    rows: rows,
                    columns: columns,
                    swatchSize: swatchSize,
                    horizontalSpacing: horizontalSpacing,
                    verticalSpacing: verticalSpacing,
                    showHexBadges: hexBadgeMinSize.map { swatchSize >= $0 } ?? false
                )
            }
        }
        return best
    }

    /// The index into the color list for a grid cell, or nil past the end.
    public func index(row: Int, column: Int, colorCount: Int) -> Int? {
        let index = row * columns + column
        return index < colorCount ? index : nil
    }
}
