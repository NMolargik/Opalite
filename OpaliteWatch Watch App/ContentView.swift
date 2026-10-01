//
//  ContentView.swift
//  OpaliteWatch Watch App
//
//  The watch's home: loose colors and palettes, offline guidance, and complication deep links.
//

import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

struct ContentView: View {
    @Environment(WatchColorManager.self) private var colorManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var deepLinkColor: WatchColor?

    var body: some View {
        NavigationStack {
            Group {
                if colorManager.colors.isEmpty && colorManager.palettes.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Opalite")
            .navigationDestination(item: $deepLinkColor) { color in
                WatchColorDetailView(color: color)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await colorManager.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.pulse, isActive: colorManager.isSyncing)
                    }
                    .accessibilityLabel("Sync with iPhone")
                }
            }
        }
        .task {
            if !colorManager.hasCachedData { await colorManager.refreshAll() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await colorManager.refreshAll() } }
        }
        .onOpenURL { colorManager.handle(url: $0) }
        .onChange(of: colorManager.pendingDeepLinkColorID, initial: true) { _, id in
            guard let id, let color = colorManager.colors.first(where: { $0.id == id }) else { return }
            colorManager.pendingDeepLinkColorID = nil
            deepLinkColor = color
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(colorManager.isPhoneReachable ? "No Colors Yet" : "iPhone Not Connected", systemImage: colorManager.isPhoneReachable ? "paintpalette" : "iphone.slash")
        } description: {
            Text(colorManager.isPhoneReachable
                 ? "Create colors in Opalite on your iPhone, iPad, or Mac and they'll sync here."
                 : "Bring your iPhone nearby with Opalite open to sync your colors.")
        }
    }

    private var list: some View {
        List {
            if !colorManager.isPhoneReachable {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iPhone Not Connected")
                            Text("Showing cached colors.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "iphone.slash").foregroundStyle(.orange)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .combine)
                }
            }
            if !colorManager.looseColors.isEmpty {
                NavigationLink {
                    ColorListView(title: String(localized: "Colors"), colors: colorManager.looseColors)
                } label: {
                    Label {
                        HStack {
                            Text("Colors")
                            Spacer()
                            Text(colorManager.looseColors.count, format: .number)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: "paintpalette.fill").foregroundStyle(.opaliteBlue)
                    }
                }
                .accessibilityLabel("Colors, \(colorManager.looseColors.count)")
            }
            if !colorManager.palettes.isEmpty {
                Section("Palettes") {
                    ForEach(colorManager.palettes) { palette in
                        let colors = colorManager.colors(for: palette)
                        NavigationLink {
                            ColorListView(title: palette.name, colors: colors)
                        } label: {
                            Label {
                                HStack {
                                    Text(palette.name)
                                    Spacer()
                                    Text(colors.count, format: .number)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            } icon: {
                                if let first = colors.first {
                                    Circle().fill(first.swiftUIColor).frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "swatchpalette.fill").foregroundStyle(.opalitePurple)
                                }
                            }
                        }
                        .accessibilityLabel("\(palette.name), \(colors.count) colors")
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
