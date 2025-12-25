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
        SectionCard(title: "Components", systemImage: "swatchpalette") {
            SwatchRowView(
                colors: palette.colors ?? [],
                palette: palette,
                swatchWidth: 180,
                swatchHeight: 150,
                showOverlays: true,
                showsNavigation: true,
                contextMenuContent: { color in
                    AnyView(
                        Group {
                            Button {
                                HapticsManager.shared.selection()
                                copyHex(for: color)
                            } label: {
                                Label("Copy Hex", systemImage: "number")
                            }

                            Button(role: .destructive) {
                                HapticsManager.shared.selection()
                                onRemoveColor(color)
                            } label: {
                                Label("Remove From Palette", systemImage: "xmark.circle")
                            }
                        }
                    )
                }
            )
        }
    }

    private func copyHex(for color: OpaliteColor) {
        #if canImport(UIKit)
        UIPasteboard.general.string = color.hexString
        #endif
    }
}

#Preview("Palette Components") {
    PaletteMembersView(
        palette: OpalitePalette.sample,
        onRemoveColor: { _ in }
    )
    .padding()
}
