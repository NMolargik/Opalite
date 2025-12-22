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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var shareImage: UIImage?
    @State private var shareImageTitle: String = "Shared from Opalite"
    @State private var isShowingShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isShowingColorEditor = false
    @State private var isEditingName: Bool? = false
    @State private var notesDraft: String = ""
    @State private var isSavingNotes: Bool = false
    @State private var isShowingPaletteSelection: Bool = false
    @State private var showDetachConfirmation: Bool = false
    @State private var shareFileURL: URL?
    @State private var isShowingFileShareSheet = false
    
    let palette: OpalitePalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SwatchView(
                    fill: palette.colors?.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? [],
                    height: 260,
                    badgeText: palette.name,
                    showOverlays: true,
                    isEditingBadge: $isEditingName,
                    saveBadge: { newName in
                        do {
                            try colorManager.updatePalette(palette) { pal in
                                pal.name = newName.isEmpty ? palette.name : newName
                            }
                        } catch {
                            // TODO: error handling
                        }
                    },
                    allowBadgeTapToEdit: true
                )
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        PaletteDetailsSectionView(palette: palette)
                            .frame(maxWidth: .infinity, alignment: .top)

                        VStack(alignment: .leading, spacing: 16) {
                            PaletteMembersView(palette: palette, onRemoveColor: { color in
                                colorManager.detachColorFromPalette(color)
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
                                        // TODO: error handling
                                    }
                                }
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        PaletteMembersView(palette: palette, onRemoveColor: { color in
                            colorManager.detachColorFromPalette(color)
                        })
                        
                        PaletteDetailsSectionView(palette: palette)

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
                                    // TODO: error handling
                                }
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .onAppear {
            notesDraft = palette.notes ?? ""
        }
        .navigationTitle("Palette")
        .navigationBarTitleDisplayMode(.inline)
        .background(shareSheet(image: shareImage))
        .alert("Delete \(palette.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}

            Button("Delete Palette", role: .destructive) {
                dismiss()
                
                do {
                    try colorManager.deletePalette(palette, andColors: false)
                } catch {
                    // TODO: error handling
                }
            }

            if (!(palette.colors?.isEmpty ?? false)) {
                Button("Delete Palette and Colors", role: .destructive) {
                    dismiss()

                    do {
                        try colorManager.deletePalette(palette, andColors: true)
                    } catch {
                        // TODO: error handling
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive){
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingName = true
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
            }
            
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button {
                        if let image = gradientImage(from: palette.colors ?? []) {
                            shareImage = image
                            shareImageTitle = palette.name
                            isShowingShareSheet = true
                        }
                    } label: {
                        Label("Share As Image", systemImage: "photo.badge.plus")
                    }
                    
                    Button {
                        do {
                            shareFileURL = try SharingService.exportPalette(palette)
                            isShowingFileShareSheet = true
                        } catch {
                            // Export failed silently
                        }
                    } label: {
                        Label("Share Palette", systemImage: "swatchpalette.fill")
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
    
    @ViewBuilder
    private func shareSheet(image: UIImage?) -> some View {
        EmptyView()
            .background(
                ShareSheetPresenter(image: image, title: shareImageTitle, isPresented: $isShowingShareSheet)
            )
            .background(
                FileShareSheetPresenter(fileURL: shareFileURL, isPresented: $isShowingFileShareSheet)
            )
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
    }
}
