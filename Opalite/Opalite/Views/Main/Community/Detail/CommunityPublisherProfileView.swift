//
//  CommunityPublisherProfileView.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import SwiftUI
import CloudKit

struct CommunityPublisherProfileView: View {
    let userRecordID: CKRecord.ID
    let displayName: String

    @Environment(CommunityManager.self) private var communityManager
    @Environment(ToastManager.self) private var toastManager

    @State private var colors: [CommunityColor] = []
    @State private var palettes: [CommunityPalette] = []
    @State private var isLoading = true
    @State private var isLoadingPaletteColors = false
    @State private var selectedSegment: CommunitySegment = .colors

    var body: some View {
        VStack(spacing: 0) {
            // Profile Header
            profileHeader

            // Segment Picker
            Picker("Content Type", selection: $selectedSegment) {
                ForEach(CommunitySegment.allCases) { segment in
                    Label(segment.rawValue, systemImage: segment.icon)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            if isLoading {
                Spacer()
                ProgressView("Finding Creator...")
                Spacer()
            } else if selectedSegment == .colors {
                colorsContent
            } else {
                palettesContent
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContent()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(displayName)
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 24) {
                VStack {
                    Text("\(colors.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("\(palettes.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Palettes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Colors Content

    private var colorsContent: some View {
        Group {
            if colors.isEmpty {
                ContentUnavailableView {
                    Label("No Colors", systemImage: "paintpalette")
                } description: {
                    Text("This publisher hasn't shared any colors yet.")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(colors) { color in
                            NavigationLink(value: CommunityNavigationNode.colorDetail(color)) {
                                CommunityColorCardView(color: color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Palettes Content

    private var palettesContent: some View {
        Group {
            if palettes.isEmpty {
                ContentUnavailableView {
                    Label("No Palettes", systemImage: "swatchpalette")
                } description: {
                    Text("This publisher hasn't shared any palettes yet.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(palettes) { palette in
                            NavigationLink(value: CommunityNavigationNode.paletteDetail(palette)) {
                                CommunityPaletteCardView(palette: palette)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Load Content

    private func loadContent() async {
        isLoading = true
        do {
            // First phase: fetch colors and palette metadata (without palette colors)
            let content = try await communityManager.fetchPublisherContentMetadata(userRecordID: userRecordID)
            colors = content.colors
            palettes = content.palettes
            isLoading = false

            // Second phase: load palette colors concurrently in background
            if !palettes.isEmpty {
                isLoadingPaletteColors = true
                await loadPaletteColors()
                isLoadingPaletteColors = false
            }
        } catch {
            toastManager.show(error: .communityFetchFailed(reason: error.localizedDescription))
            isLoading = false
        }
    }

    private func loadPaletteColors() async {
        await withTaskGroup(of: (CKRecord.ID, [CommunityColor]).self) { group in
            for palette in palettes {
                group.addTask {
                    let colors = (try? await communityManager.fetchPaletteColors(paletteRecordID: palette.id)) ?? []
                    return (palette.id, colors)
                }
            }

            for await (paletteID, paletteColors) in group {
                if let index = palettes.firstIndex(where: { $0.id == paletteID }) {
                    var updatedPalette = palettes[index]
                    updatedPalette.colors = paletteColors
                    palettes[index] = updatedPalette
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CommunityPublisherProfileView(
            userRecordID: CKRecord.ID(recordName: "sample-user"),
            displayName: "Sample User"
        )
    }
    .environment(CommunityManager())
    .environment(ToastManager())
}
