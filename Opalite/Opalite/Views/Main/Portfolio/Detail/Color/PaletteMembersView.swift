//
//  PaletteMembersView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct PaletteMembersView: View {
    let palette: OpalitePalette
    let onRemoveColor: (OpaliteColor) -> Void

    var body: some View {
        SectionCard(title: "Palette Members", systemImage: "swatchpalette") {
            SwatchRowView(
                colors: palette.colors ?? [],
                palette: palette,
                swatchWidth: 180,
                swatchHeight: 150,
                showOverlays: true,
                showsNavigation: false,
                menuContent: { color in
                    AnyView(
                        Group {
                            Button {
                                copyHex(for: color)
                            } label: {
                                Label("Copy Hex", systemImage: "number")
                            }

                            Button(role: .destructive) {
                                onRemoveColor(color)
                            } label: {
                                Label("Remove From Palette", systemImage: "swatchpalette")
                            }
                        }
                    )
                }
            )
        }
    }
}

#Preview("Palette Members") {
    PaletteMembersView(
        palette: OpalitePalette.sample,
        onRemoveColor: { _ in }
    )
    .padding()
}
