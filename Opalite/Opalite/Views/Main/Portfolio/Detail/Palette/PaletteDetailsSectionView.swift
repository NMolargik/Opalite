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
                DetailRow(icon: "person", title: "Created By", value: palette.createdByDisplayName ?? "—")
                DetailRow(icon: "calendar", title: "Created At", value: formatted(palette.createdAt))
                Divider()
                    .opacity(0.25)
                DetailRow(icon: "clock.arrow.circlepath", title: "Updated At", value: formatted(palette.updatedAt))
                DetailRow(icon: "swatchpalette", title: "Colors", value: "\(palette.colors?.count ?? 0)")
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

    private struct DetailRow: View {
        let icon: String
        let title: String
        let value: String

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview("Palette Details") {
    PaletteDetailsSectionView(palette: OpalitePalette.sample)
        .padding()
}
