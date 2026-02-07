//
//  ColorListView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI

struct ColorListView: View {
    @Environment(WatchColorManager.self) private var colorManager

    let title: String
    let colors: [WatchColor]

    var body: some View {
        Group {
            if colors.isEmpty {
                ContentUnavailableView(
                    "No Colors",
                    systemImage: "paintpalette",
                    description: Text("Add colors to this palette in Opalite on your iPhone, iPad, or Mac and they'll appear here.")
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
        .refreshable {
            await colorManager.refreshAll()
        }
        .onAppear {
            colorManager.playNavigationHaptic()
        }
    }
}

#Preview("With Colors") {
    NavigationStack {
        ColorListView(
            title: "Ocean",
            colors: WatchColor.samples
        )
        .environment(WatchColorManager())
    }
}

#Preview("Empty") {
    NavigationStack {
        ColorListView(title: "Empty Palette", colors: [])
            .environment(WatchColorManager())
    }
}
