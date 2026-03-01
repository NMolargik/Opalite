//
//  PaletteSectionHeaderView.swift
//  Opalite
//
//  Created by Nick Molargik on 2/28/26.
//

import SwiftData
import SwiftUI

struct PaletteSectionHeaderView: View {
    @Environment(ColorManager.self) private var colorManager
    
    @State private var isShowingArchivedPalettes: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row
            HStack(alignment: .center) {
                Image(systemName: "swatchpalette.fill")
                    .foregroundStyle(.purple.gradient, .orange.gradient, .red.gradient)
                    .accessibilityHidden(true)
                    .font(.title)

                Text("Palettes")
                    .font(.title)
                    .padding(.trailing)
                
                if !colorManager.archivedPalettes.isEmpty {
                    Button {
                        HapticsManager.shared.selection()
                        withAnimation {
                            isShowingArchivedPalettes = true
                        }
                    } label: {
                        Image(systemName: "archivebox")
                            .imageScale(.medium)
                            .foregroundStyle(.inverseTheme)
                            .frame(width: 15, height: 15)
                            .padding(8)
                            .background(
                                Circle().fill(.clear)
                            )
                            .glassIfAvailable(
                                GlassConfiguration(style: .regular)
                            )
                            .contentShape(Circle())
                            .hoverEffect(.lift)
                    }
                    .buttonStyle(.plain)
                }
            }
            .bold()
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Palettes, \(colorManager.palettes.count) items")
        }
        .padding(.horizontal)
        .fullScreenCover(isPresented: $isShowingArchivedPalettes) {
            ArchivedPalettesSheet()
        }
    }
}

#Preview("Palette Section Header") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        CanvasFile.self,
        configurations: config
    )
    let manager = ColorManager(context: container.mainContext)
    try? manager.loadSamples()

    return PaletteSectionHeaderView()
    .modelContainer(container)
    .environment(manager)
    .environment(ToastManager())
}
