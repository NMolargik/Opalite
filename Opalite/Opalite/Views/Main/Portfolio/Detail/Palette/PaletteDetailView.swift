//
//  PaletteDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData

struct PaletteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"

    @State private var showDeleteConfirmation = false
    @State private var isEditingName: Bool? = false
    @State private var notesDraft: String = ""
    @State private var isSavingNotes: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @State private var isShowingColorEditor: Bool = false

    let palette: OpalitePalette

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Hero Preview
                PalettePreviewView(
                    palette: palette,
                    isEditingName: $isEditingName
                )
                .padding(.horizontal)
                .padding(.top)
                .overlay(alignment: .bottom) {
                    PaletteInfoTilesRow(palette: palette)
                        .padding(.horizontal, 30)
                        .offset(y: 45)
                        .zIndex(1)
                }

                Spacer(minLength: 80)

                // MARK: - Content Sections
                VStack(spacing: 20) {
                    // Colors section
                    SectionCard(title: "Components", systemImage: "swatchpalette") {
                        PaletteMembersView(palette: palette, onRemoveColor: { color in
                            withAnimation {
                                colorManager.detachColorFromPalette(color)
                            }
                        })
                    }

                    // Notes section
                    NotesSectionView(
                        notes: $notesDraft,
                        isSaving: $isSavingNotes,
                        onSave: {
                            isSavingNotes = true
                            defer { isSavingNotes = false }

                            do {
                                try colorManager.updatePalette(palette) { pal in
                                    let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                    pal.notes = trimmed.isEmpty ? nil : trimmed
                                }
                            } catch {
                                toastManager.show(error: .paletteUpdateFailed)
                            }
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.top, -20)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            notesDraft = palette.notes ?? ""
            colorManager.activePalette = palette
        }
        .onDisappear {
            colorManager.activePalette = nil
        }
        .onChange(of: colorManager.renamePaletteTrigger) { _, newValue in
            if newValue != nil {
                colorManager.renamePaletteTrigger = nil
                withAnimation {
                    isEditingName = true
                }
            }
        }
        .navigationTitle("Palette")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingExportSheet) {
            PaletteExportSheet(palette: palette)
        }
        .alert("Delete \(palette.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }

            Button("Delete Palette", role: .destructive) {
                HapticsManager.shared.selection()
                dismiss()

                do {
                    try colorManager.deletePalette(palette, andColors: false)
                } catch {
                    toastManager.show(error: .paletteDeletionFailed)
                }
            }

            if !(palette.colors?.isEmpty ?? false) {
                Button("Delete Palette and Colors", role: .destructive) {
                    HapticsManager.shared.selection()
                    dismiss()

                    do {
                        try colorManager.deletePalette(palette, andColors: true)
                    } catch {
                        toastManager.show(error: .paletteDeletionFailed)
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .toolbar {
            // Export button first for priority
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingExportSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
                .disabled(palette.sortedColors.isEmpty)
                .accessibilityLabel("Share palette")
                .accessibilityHint("Opens share options for this palette")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingColorEditor = true
                } label: {
                    Label("Add Color", systemImage: "plus.square.dashed")
                }
            }

            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }

            // Ellipsis menu with palette info and actions
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Palette info section
                    Section("Palette Info") {
                        Label("\(palette.sortedColors.count) colors", systemImage: "swatchpalette")
                        Label("Created \(formattedDate(palette.createdAt))", systemImage: "calendar")
                        Label("Updated \(formattedDate(palette.updatedAt))", systemImage: "clock.arrow.circlepath")
                        if let creator = palette.createdByDisplayName {
                            Label("By \(creator)", systemImage: "person")
                        }
                    }

                    Section {
                        Button {
                            HapticsManager.shared.selection()
                            withAnimation {
                                isEditingName = true
                            }
                        } label: {
                            Label("Rename", systemImage: "character.cursor.ibeam")
                        }

                        Button {
                            HapticsManager.shared.selection()
                            duplicatePalette()
                        } label: {
                            Label("Duplicate Palette", systemImage: "plus.square.on.square")
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            HapticsManager.shared.selection()
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .toolbarButtonTint()
            }
        }
        .toolbarRole(horizontalSizeClass == .compact ? .automatic : .editor)
        .fullScreenCover(isPresented: $isShowingColorEditor) {
            ColorEditorView(
                color: nil,
                palette: palette,
                onCancel: {
                    isShowingColorEditor = false
                },
                onApprove: { newColor in
                    do {
                        let createdColor = try colorManager.createColor(existing: newColor)
                        colorManager.attachColor(createdColor, to: palette)
                    } catch {
                        toastManager.show(error: .colorCreationFailed)
                    }

                    isShowingColorEditor = false
                }
            )
        }
    }

    // MARK: - Helper Functions

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func duplicatePalette() {
        do {
            let newPalette = try colorManager.createPalette(name: "\(palette.name) Copy")
            // Copy colors to the new palette
            for color in palette.sortedColors {
                let newColor = try colorManager.createColor(
                    name: color.name,
                    notes: color.notes,
                    device: color.createdOnDeviceName,
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: color.alpha,
                    palette: newPalette
                )
                colorManager.attachColor(newColor, to: newPalette)
            }
        } catch {
            toastManager.show(error: .paletteCreationFailed)
        }
    }
}

// MARK: - Palette Info Tile View

private struct PaletteInfoTileView: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(height: 30)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: 200, maxHeight: 85)
        .modifier(PaletteGlassTileBackground())
    }
}

private struct PaletteGlassTileBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 5)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white)
                        .shadow(radius: 5)
                )
        }
    }
}

// MARK: - Palette Info Tiles Row

private struct PaletteInfoTilesRow: View {
    @Bindable var palette: OpalitePalette

    var body: some View {
        HStack(spacing: 12) {
            PaletteInfoTileView(
                icon: "swatchpalette.fill",
                iconColor: .purple,
                value: "\(palette.sortedColors.count)",
                label: "Colors"
            )

            PaletteInfoTileView(
                icon: "person.fill",
                iconColor: .orange,
                value: palette.createdByDisplayName ?? "Unknown",
                label: "Created By"
            )

            PaletteInfoTileView(
                icon: "clock.fill",
                iconColor: .indigo,
                value: formattedShortDate(palette.updatedAt),
                label: "Updated On"
            )
        }
    }

    private func formattedShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview("Palette Detail") {
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

    return NavigationStack {
        PaletteDetailView(palette: OpalitePalette.sample)
            .environment(manager)
            .environment(ToastManager())
            .environment(SubscriptionManager())
            .environment(HexCopyManager())
    }
}
