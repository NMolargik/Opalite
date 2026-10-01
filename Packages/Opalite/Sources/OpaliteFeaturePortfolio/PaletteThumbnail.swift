//
//  PaletteThumbnail.swift
//  OpaliteFeaturePortfolio
//
//  A tiny strip of a palette's first colors for lists, sheets, and search rows.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct PaletteThumbnail: View {
    let colors: [RGBA]
    var size: CGFloat = 36
    var maximum: Int = 4

    var body: some View {
        HStack(spacing: 0) {
            if colors.isEmpty {
                Rectangle().fill(.quaternary)
            } else {
                ForEach(Array(colors.prefix(maximum).enumerated()), id: \.offset) { _, rgba in
                    Rectangle().fill(rgba.color)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip * size / 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Brand.Radius.chip * size / 36, style: .continuous).strokeBorder(.quaternary))
        .accessibilityHidden(true)
    }
}

/// A palette row body shared by the selection, archive, and reorder sheets.
struct PaletteRowLabel: View {
    let name: String
    let colors: [RGBA]
    var detail: String? = nil

    var body: some View {
        HStack(spacing: Brand.Space.md) {
            PaletteThumbnail(colors: colors, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)
                Text(detail ?? (colors.count == 1 ? String(localized: "1 color") : String(localized: "\(colors.count) colors")))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
