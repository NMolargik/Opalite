//
//  ColorListView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI
import SwiftData

struct ColorListView: View {
    let title: String
    let colors: [OpaliteColor]

    var body: some View {
        Group {
            if colors.isEmpty {
                ContentUnavailableView(
                    "No Colors",
                    systemImage: "paintpalette",
                    description: Text("Colors will appear here once synced from your iPhone.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(colors) { color in
                            WatchSwatchView(color: color)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .navigationTitle(title)
    }
}

#Preview("With Colors") {
    NavigationStack {
        ColorListView(
            title: "Ocean",
            colors: [
                OpaliteColor(name: "Deep Blue", red: 0.05, green: 0.20, blue: 0.45),
                OpaliteColor(name: "Sea", red: 0.00, green: 0.55, blue: 0.65),
                OpaliteColor(name: "Foam", red: 0.80, green: 0.95, blue: 0.95)
            ]
        )
        .environment(WatchColorManager(context: try! ModelContainer(
            for: OpaliteColor.self, OpalitePalette.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ).mainContext))
    }
}

#Preview("Empty") {
    NavigationStack {
        ColorListView(title: "Empty Palette", colors: [])
            .environment(WatchColorManager(context: try! ModelContainer(
                for: OpaliteColor.self, OpalitePalette.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ).mainContext))
    }
}
