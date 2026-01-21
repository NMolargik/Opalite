//
//  ColorListView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI

struct ColorListView: View {
    let title: String
    let colors: [WatchColor]

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
