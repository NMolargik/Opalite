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
            VStack(alignment: .leading, spacing: 16) {
                PalettePreviewView(
                    palette: palette,
                    isEditingName: $isEditingName
                )
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        PaletteDetailsSectionView(palette: palette)
                            .frame(maxWidth: .infinity, alignment: .top)

                        VStack(alignment: .leading, spacing: 16) {
                            PaletteMembersView(palette: palette, onRemoveColor: { color in
                                withAnimation {
                                    colorManager.detachColorFromPalette(color)
                                }
                            })

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
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        PaletteMembersView(palette: palette, onRemoveColor: { color in
                            withAnimation {
                                colorManager.detachColorFromPalette(color)
                            }
                        })
                        
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
                        
                        PaletteDetailsSectionView(palette: palette)
                    }
                }
            }
            .padding()
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

            if (!(palette.colors?.isEmpty ?? false)) {
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
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
                .disabled(palette.sortedColors.isEmpty)
                .accessibilityLabel("Export palette")
                .accessibilityHint("Opens export options for this palette")
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingColorEditor = true
                } label: {
                    Label("Add Color", systemImage: "plus")
                }
                .tint(.blue)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    withAnimation {
                        isEditingName = true
                    }
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
                .toolbarButtonTint()
            }

            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive){
                    HapticsManager.shared.selection()
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
                .tint(.red)
            }
        }
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
    }
}
