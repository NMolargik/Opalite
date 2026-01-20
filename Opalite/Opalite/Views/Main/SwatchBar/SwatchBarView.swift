//
//  SwatchBarView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import SwiftUI
import SwiftData
#if targetEnvironment(macCatalyst)
import UIKit
#endif

struct SwatchBarView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(HexCopyManager.self) private var hexCopyManager
    @Environment(\.openWindow) private var openWindow

    @State private var copiedColorID: UUID?
    @State private var expandedPalettes: Set<UUID> = []
    @State private var showingSwatchBarInfo: Bool = false

    private let swatchHeight: CGFloat = 100

    var body: some View {
        NavigationStack {
            Group {
                if colorManager.colors.isEmpty {
                    ContentUnavailableView("No Colors Created", systemImage: "questionmark.square.dashed")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            // MARK: - Palette Sections (collapsible with sticky headers)
                            // Palettes sorted by createdAt (newest first)
                            ForEach(colorManager.palettes) { palette in
                                let paletteColors = palette.sortedColors
                                if !paletteColors.isEmpty {
                                    Section {
                                        if expandedPalettes.contains(palette.id) {
                                            ForEach(paletteColors) { color in
                                                swatchCell(for: color)
                                                    .padding(.horizontal)
                                                    .padding(.vertical, 4)
                                            }
                                        }
                                    } header: {
                                        sectionHeader(for: palette)
                                    }
                                }
                            }

                            // MARK: - Loose Colors Section
                            // Colors are pre-sorted by updatedAt from ColorManager
                            if !colorManager.looseColors.isEmpty {
                                Section {
                                    ForEach(colorManager.looseColors) { color in
                                        swatchCell(for: color)
                                            .padding(.horizontal)
                                            .padding(.vertical, 4)
                                    }
                                } header: {
                                    looseColorsHeader
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom)
            .background(.ultraThinMaterial)
            .navigationTitle("Opalite")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.automatic)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticsManager.shared.selection()
                        #if os(iOS)
                        AppDelegate.openMainWindow()
                        #else
                        openWindow(id: "main")
                        #endif
                    } label: {
                        Label("Opalite", systemImage: "macwindow")
                    }
                    .tint(.red)
                }

                ToolbarItem {
                    Button {
                        HapticsManager.shared.selection()
                        showingSwatchBarInfo = true
                    } label: {
                        Label("Info", systemImage: "info.circle")
                    }
                    .tint(.blue)
                }
            }
            .sheet(isPresented: $showingSwatchBarInfo) {
                swatchBarInfoSheet
            }
        }
        .frame(minWidth: 250)
        #if targetEnvironment(macCatalyst)
        .onAppear {
            positionSwatchBarWindowAtRightEdge()
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func positionSwatchBarWindowAtRightEdge() {
        // Find the SwatchBar window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { scene in
                // Find the scene that isn't the main window
                scene.session !== AppDelegate.mainSceneSession
            }) else { return }

        let screenBounds = windowScene.screen.bounds

        // SwatchBar dimensions
        let swatchBarWidth: CGFloat = 250
        let swatchBarHeight: CGFloat = min(1000, screenBounds.height - 100)

        // Position near the right edge with padding
        let rightPadding: CGFloat = 20
        let topPadding: CGFloat = 50

        let xPosition = screenBounds.width - swatchBarWidth - rightPadding
        let yPosition = topPadding

        let targetFrame = CGRect(
            x: xPosition,
            y: yPosition,
            width: swatchBarWidth,
            height: swatchBarHeight
        )

        let geometryPreferences = UIWindowScene.GeometryPreferences.Mac(systemFrame: targetFrame)
        windowScene.requestGeometryUpdate(geometryPreferences) { error in
            print("[Opalite] SwatchBar positioning error: \(error.localizedDescription)")
        }
    }
    #endif

    @ViewBuilder
    private func sectionHeader(for palette: OpalitePalette) -> some View {
        Button {
            HapticsManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedPalettes.contains(palette.id) {
                    expandedPalettes.remove(palette.id)
                } else {
                    expandedPalettes.insert(palette.id)
                }
            }
        } label: {
            HStack {
                Label(palette.name, systemImage: "swatchpalette")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .rotationEffect(expandedPalettes.contains(palette.id) ? .degrees(90) : .zero)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
        .buttonStyle(.plain)
    }

    private var looseColorsHeader: some View {
        HStack {
            Label("Colors", systemImage: "paintpalette")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Info Sheet

    private var swatchBarInfoSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button("Done") {
                    showingSwatchBarInfo = false
                }
                .fontWeight(.medium)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Content
            VStack(spacing: 20) {
                // Icon and title
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        Image(systemName: "swatchpalette.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.purple)
                    }

                    Text("SwatchBar")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Quick access to your colors")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Feature rows
                VStack(spacing: 12) {
                    infoRow(
                        icon: "hand.tap.fill",
                        iconColor: .blue,
                        title: "Copy Color Code",
                        description: "Tap any swatch to copy its hex code"
                    )

                    infoRow(
                        icon: "line.3.horizontal.decrease.circle.fill",
                        iconColor: .orange,
                        title: "Organized by Palette",
                        description: "Tap headers to expand or collapse"
                    )

                    infoRow(
                        icon: "macwindow.badge.plus",
                        iconColor: .green,
                        title: "Always Available",
                        description: "Keep SwatchBar open while you work"
                    )
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            Spacer()
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
    }

    private func infoRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func swatchCell(for color: OpaliteColor) -> some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width

            let labelText: String = {
                let hex = "\(color.hexString)"
                if let name = color.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    return "\(name) - \(hex)"
                } else {
                    return hex
                }
            }()

            SwatchView(
                color: color,
                width: availableWidth,
                height: swatchHeight,
                badgeText: labelText,
                showOverlays: true
            )
            .frame(width: availableWidth, height: swatchHeight)
            .overlay {
                // Copy feedback overlay
                if copiedColorID == color.id {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Image(systemName: "number")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(color.idealTextColor())
                        }
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap(for: color)
            }
            .contextMenu {
                Text(labelText)

                Button {
                    HapticsManager.shared.selection()
                    copyHexWithFeedback(for: color)
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }
            }
        }
        .frame(height: swatchHeight)
    }

    private func handleTap(for color: OpaliteColor) {
        // Copy hex to clipboard
        copyHexWithFeedback(for: color)

        // Also set the canvas color for any open CanvasView
        colorManager.selectedCanvasColor = color
    }

    private func copyHexWithFeedback(for color: OpaliteColor) {
        hexCopyManager.copyHex(for: color)

        // Show feedback overlay
        withAnimation(.easeIn(duration: 0.1)) {
            copiedColorID = color.id
        }

        // Hide after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                copiedColorID = nil
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    try? manager.loadSamples()

    return SwatchBarView()
        .environment(manager)
        .environment(HexCopyManager())
        .modelContainer(container)
}
