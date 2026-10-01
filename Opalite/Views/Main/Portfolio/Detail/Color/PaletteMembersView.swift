//
//  PaletteMembersView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftData
import SwiftUI

struct PaletteMembersView: View {
    @Environment(HexCopyManager.self) private var hexCopyManager

    let palette: OpalitePalette
    let onRemoveColor: (OpaliteColor) -> Void

    @State private var copiedColorID: UUID?

    var body: some View {
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
                    Label("Remove From Palette", systemImage: "minus.circle")
                }
            }
        )
    }
}

#Preview("Palette Members") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    do {
        try manager.loadSamples()
    } catch {
        print("Failed to load samples into context")
    }

    return PaletteMembersView(
        palette: OpalitePalette.sample,
        onRemoveColor: { _ in }
    )
    .environment(manager)
    .environment(HexCopyManager())
    .environment(ToastManager())
    .modelContainer(container)
}
