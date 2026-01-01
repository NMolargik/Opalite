//
//  PaletteMembersView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI

struct PaletteMembersView: View {
    @Environment(HexCopyManager.self) private var hexCopyManager

    let palette: OpalitePalette
    let onRemoveColor: (OpaliteColor) -> Void

    @State private var copiedColorID: UUID?

    var body: some View {
        SectionCard(title: "Components", systemImage: "swatchpalette") {
            SwatchRowView(
                colors: palette.sortedColors,
                palette: palette,
                swatchWidth: 180,
                swatchHeight: 150,
                showOverlays: true,
                showsNavigation: true,
                menuContent: { color in
                    componentMenuContent(for: color)
                },
                contextMenuContent: { color in
                    componentMenuContent(for: color)
                },
                copiedColorID: $copiedColorID
            )
            .clipped()
        }
    }

    private func componentMenuContent(for color: OpaliteColor) -> AnyView {
        AnyView(
            Group {
                Button {
                    HapticsManager.shared.selection()
                    hexCopyManager.copyHex(for: color)
                    withAnimation {
                        copiedColorID = color.id
                    }
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
}

#Preview("Palette Components") {
    PaletteMembersView(
        palette: OpalitePalette.sample,
        onRemoveColor: { _ in }
    )
    .padding()
    .environment(HexCopyManager())
}
