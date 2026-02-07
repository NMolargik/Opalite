//
//  ContentView.swift
//  OpaliteWatch Watch App
//
//  Created by Nick Molargik on 12/29/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchColorManager.self) private var colorManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var deepLinkColor: WatchColor?

    var body: some View {
        Group {
            if !colorManager.hasCompletedInitialSync {
                WatchSyncingView()
            } else {
                mainContent
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                colorManager.hasCompletedInitialSync = false
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "opalite",
              url.host == "color",
              url.pathComponents.count >= 2,
              let colorID = UUID(uuidString: url.pathComponents[1]) else { return }

        colorManager.pendingDeepLinkColorID = colorID

        // Skip sync view so the user immediately sees content
        if !colorManager.hasCompletedInitialSync {
            colorManager.hasCompletedInitialSync = true
        }
    }

    private func handlePendingDeepLink() {
        guard let colorID = colorManager.pendingDeepLinkColorID else { return }
        colorManager.pendingDeepLinkColorID = nil

        if let color = colorManager.colors.first(where: { $0.id == colorID }) {
            deepLinkColor = color
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        NavigationStack {
            Group {
                if colorManager.colors.isEmpty && colorManager.palettes.isEmpty {
                    if colorManager.isPhoneReachable {
                        ContentUnavailableView(
                            "No Colors Yet",
                            systemImage: "paintpalette",
                            description: Text("Get started by creating colors in Opalite on your iPhone, iPad, or Mac. They'll sync here automatically.")
                        )
                    } else {
                        ContentUnavailableView(
                            "iPhone Not Connected",
                            systemImage: "iphone.slash",
                            description: Text("Your iPhone needs to be nearby with Opalite open to sync. Create colors on your iPhone, iPad, or Mac to see them here.")
                        )
                    }
                } else {
                    List {
                        // Offline indicator
                        if !colorManager.isPhoneReachable {
                            Section {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("iPhone Not Connected")
                                        Text("Showing cached colors. Sync will resume when your iPhone is nearby.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: "iphone.slash")
                                        .foregroundStyle(.orange)
                                }
                                .font(.caption)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("iPhone not connected. Showing cached colors. Sync will resume when your iPhone is nearby.")
                            }
                        }

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
                            .accessibilityLabel("Colors, \(colorManager.looseColors.count)")
                            .accessibilityHint("Opens color list")
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
                                    .accessibilityLabel("\(palette.name), \(paletteColors.count) colors")
                                    .accessibilityHint("Opens palette")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Opalite")
            .navigationDestination(item: $deepLinkColor) { color in
                WatchColorDetailView(color: color)
            }
            .onAppear {
                handlePendingDeepLink()
            }
            .onChange(of: colorManager.pendingDeepLinkColorID) { _, _ in
                handlePendingDeepLink()
            }
            .refreshable {
                await colorManager.refreshAll()
            }
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
