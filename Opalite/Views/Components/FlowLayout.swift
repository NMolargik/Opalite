//
//  FlowLayout.swift
//  Opalite
//
//  Created by Nick Molargik on 12/26/25.
//

import SwiftUI

/// A layout that arranges views in a flowing, wrapping horizontal arrangement.
///
/// Views are placed horizontally until they exceed the available width,
/// then wrap to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = Self.calculateLayout(itemSizes: sizes, maxWidth: proposal.width ?? .infinity, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = Self.calculateLayout(itemSizes: sizes, maxWidth: proposal.width ?? .infinity, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    /// Pure layout calculation for an array of item sizes.
    /// Arranges items horizontally, wrapping to the next line when exceeding maxWidth.
    static func calculateLayout(
        itemSizes: [CGSize],
        maxWidth: CGFloat,
        spacing: CGFloat
    ) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for size in itemSizes {
            // Check if we need to wrap to the next line
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview("Flow Layout") {
    FlowLayout(spacing: 8) {
        ForEach(["Dusty Rose", "Ocean Mist", "Burnt Sienna", "Midnight Blue", "Forest Green"], id: \.self) { name in
            Text(name)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.blue.opacity(0.2), in: Capsule())
        }
    }
    .padding()
    .frame(width: 250)
}
