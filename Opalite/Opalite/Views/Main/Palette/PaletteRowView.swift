//
//  PaletteRowView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI

struct PaletteRowView: View {
    let palette: OpalitePalette

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(palette.name)
                        .font(.headline)
                    if palette.isPinned == true {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                if let colors = palette.colors, !colors.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(colors.prefix(8)).indices, id: \.self) { index in
                            let color = Array(colors.prefix(8))[index]
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color.swiftUIColor)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        if colors.count > 8 {
                            Text("+\(colors.count - 8)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            if let colors = palette.colors {
                Text("\(colors.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    PaletteRowView(palette: OpalitePalette.sample)
}
