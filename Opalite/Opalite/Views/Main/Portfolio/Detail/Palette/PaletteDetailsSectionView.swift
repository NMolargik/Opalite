//
//  PaletteDetailsSectionView.swift
//  
//
//  Created by OpenAI on 2025-12-17.
//

import SwiftUI

struct PaletteDetailsSectionView: View {
    let palette: OpalitePalette

    var body: some View {
        SectionCard(title: "Details", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 16) {
                DetailRowView(icon: "person", title: "Created By", value: palette.createdByDisplayName ?? "—")
                DetailRowView(icon: "calendar", title: "Created At", value: formatted(palette.createdAt))
                Divider()
                    .opacity(0.25)
                DetailRowView(icon: "clock.arrow.circlepath", title: "Updated At", value: formatted(palette.updatedAt))
                DetailRowView(icon: "swatchpalette", title: "Colors", value: "\(palette.colors?.count ?? 0)")
            }
            .padding([.horizontal, .bottom])
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview("Palette Details") {
    PaletteDetailsSectionView(palette: OpalitePalette.sample)
        .padding()
}
