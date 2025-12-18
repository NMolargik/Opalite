//
//  ColorsView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/16/25.
//

import SwiftUI
import SwiftData

struct ColorsView: View {
    @Environment(ColorManager.self) private var colorManager
    var matchedNamespace: Namespace.ID? = nil

    var body: some View {
        NavigationStack {
            ScrollView() {
                VStack(spacing: 12) {
                    ForEach(colorManager.colors.filter( { $0.palette == nil }), id: \.self) { color in
                        NavigationLink {
                            ColorDetailView(color: color)
                        } label: {
                            SwatchView(
                                fill: [color],
                                width: 200,
                                height: 200,
                                badgeText: color.name ?? color.hexString,
                                showOverlays: false,
                                isEditingBadge: .constant(nil),
                                saveBadge: nil,
                                palette: nil,
                                matchedNamespace: matchedNamespace,
                                matchedID: color.id,
                                menu: nil,
                                contextMenu: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 5)
                }
                .padding(.leading)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview("Colors") {
    // In-memory SwiftData container for previews
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

    return ColorsView()
        .environment(manager)
        .modelContainer(container)
}
