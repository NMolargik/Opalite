//
//  ColorDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI

struct ColorDetailView: View {
    let color: OpaliteColor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SwatchView(
                    fill: [color],
                    height: 260,
                    badgeText: color.name ?? color.hexString
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 8) {
                    Text(color.name ?? "Unnamed Color")
                        .font(.title)
                        .bold()

                    Text(color.hexString)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Placeholder for future metadata/actions
                Text("Details coming soon…")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(color.name ?? "Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Color Detail") {
    NavigationStack {
        ColorDetailView(color: OpaliteColor.sample)
    }
}
