//
//  ContentView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchColorManager.self) private var colorManager

    var body: some View {
        Group {
            if !colorManager.hasCompletedInitialSync {
                // Show syncing screen on first launch
                WatchSyncingView()
            } else {
                mainContent
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        NavigationStack {
            Group {
                if colorManager.colors.isEmpty && colorManager.palettes.isEmpty {
                    ContentUnavailableView(
                        "No Colors Yet",
                        systemImage: "paintpalette",
                        description: Text("Create colors on your iPhone and they will sync here automatically.")
                    )
                } else {
                    List {
                        // Loose Colors section
                        if !colorManager.looseColors.isEmpty {
                            NavigationLink {
                                ColorListView(
                                    title: "Colors",
                                    colors: colorManager.looseColors
                                )
                            } label: {
                                Label {
                                    HStack {
                                        Text("Colors")
                                        Spacer()
                                        Text("\(colorManager.looseColors.count)")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                } icon: {
                                    Image(systemName: "paintpalette.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }

                        // Palettes section
                        if !colorManager.palettes.isEmpty {
                            Section("Palettes") {
                                ForEach(colorManager.palettes) { palette in
                                    let paletteColors = colorManager.colors(for: palette)
                                    NavigationLink {
                                        ColorListView(
                                            title: palette.name,
                                            colors: paletteColors
                                        )
                                    } label: {
                                        Label {
                                            HStack {
                                                Text(palette.name)
                                                Spacer()
                                                Text("\(paletteColors.count)")
                                                    .foregroundStyle(.secondary)
                                                    .font(.caption)
                                            }
                                        } icon: {
                                            // Show a small color preview if palette has colors
                                            if let firstColor = paletteColors.first {
                                                Circle()
                                                    .fill(firstColor.swiftUIColor)
                                                    .frame(width: 20, height: 20)
                                            } else {
                                                Image(systemName: "swatchpalette.fill")
                                                    .foregroundStyle(.purple)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Opalite")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await colorManager.refreshAll()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(WatchColorManager())
}
