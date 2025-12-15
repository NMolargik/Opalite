//
//  PaletteDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI

struct PaletteDetailView: View {
    let palette: OpalitePalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(palette.name)
                    .font(.largeTitle)
                    .bold()

                if let colors = palette.colors, !colors.isEmpty {
                    SwatchRowView(
                        colors: colors,
                        swatchWidth: 120,
                        swatchHeight: 120,
                        showBadge: true
                    )
                } else {
                    ContentUnavailableView(
                        "No Colors",
                        systemImage: "swatchpalette",
                        description: Text("This palette doesn’t have any colors yet.")
                    )
                }
            }
            .padding()
        }
        .navigationTitle(palette.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Palette Detail") {
    NavigationStack {
        PaletteDetailView(palette: OpalitePalette.sample)
    }
}
