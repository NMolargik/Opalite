//
//  ColorDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

struct ColorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var shareImage: UIImage?
    @State private var isShowingShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isShowingColorEditor = false
    @State private var isEditingName: Bool? = false
    @State private var notesDraft: String = ""
    @State private var isSavingNotes: Bool = false
    @State private var isShowingPaletteSelection: Bool = false
    @State private var showDetachConfirmation: Bool = false
    @State private var didCopyHex: Bool = false
    @State private var shareFileURL: URL?
    @State private var isShowingFileShareSheet = false

    let color: OpaliteColor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SwatchView(
                    fill: [color],
                    height: 260,
                    badgeText: color.name ?? color.hexString,
                    showOverlays: true,
                    isEditingBadge: $isEditingName,
                    saveBadge: { newName in
                        do {
                            try colorManager.updateColor(color) { c in
                                c.name = newName.isEmpty ? nil : newName
                            }
                        } catch {
                            // TODO: error handling
                        }
                    },
                    allowBadgeTapToEdit: true
                )
                
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        ColorDetailsSectionView(color: color)
                            .frame(maxWidth: .infinity, alignment: .top)

                        VStack(alignment: .leading, spacing: 16) {
                            ColorRecommendedColorsView(
                                baseColor: color,
                                onCreateColor: { suggested in
                                    do {
                                        let createdColor = try colorManager.createColor(
                                            name: nil,
                                            notes: suggested.notes,
                                            device: nil,
                                            red: suggested.red,
                                            green: suggested.green,
                                            blue: suggested.blue,
                                            alpha: suggested.alpha
                                        )
                                        
                                        if let palette = color.palette {
                                            colorManager.attachColor(createdColor, to: palette)
                                        }
                                    } catch {
                                        // TODO: error handling
                                    }
                                }
                            )

                            notesSection
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        ColorRecommendedColorsView(
                            baseColor: color,
                            onCreateColor: { suggested in
                                do {
                                    _ = try colorManager.createColor(
                                        name: suggested.name,
                                        notes: suggested.notes,
                                        device: nil,
                                        red: suggested.red,
                                        green: suggested.green,
                                        blue: suggested.blue,
                                        alpha: suggested.alpha
                                    )
                                } catch {
                                    // TODO: error handling
                                }
                            }
                        )
                        
                        ColorDetailsSectionView(color: color)

                        notesSection
                    }
                }
            }
            .padding()
        }
        .onAppear {
            notesDraft = color.notes ?? ""
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(shareSheet(image: shareImage))
        .alert("Delete \(color.name ?? color.hexString)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                do {
                    try colorManager.deleteColor(color)
                    dismiss()
                } catch {
                    // TODO: error handling
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Remove from Palette?", isPresented: $showDetachConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                colorManager.detachColorFromPalette(color)
            }
        } message: {
            Text("This color will be removed from its palette.")
        }
        .sheet(isPresented: $isShowingPaletteSelection) {
            PaletteSelectionSheet(color: color)
                .environment(colorManager)
        }
        .fullScreenCover(isPresented: $isShowingColorEditor) {
            ColorEditorView(
                color: color,
                palette: color.palette,
                onCancel: {
                    isShowingColorEditor = false
                },
                onApprove: { updatedColor in
                    do {
                        try colorManager.updateColor(color) { c in
                            c.name = updatedColor.name
                            c.red = updatedColor.red
                            c.green = updatedColor.green
                            c.blue = updatedColor.blue
                            c.alpha = updatedColor.alpha
                        }
                    } catch {
                        // TODO: error handling
                    }
                    
                    isShowingColorEditor.toggle()
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingColorEditor = true
                } label: {
                    Text("Edit")
                }
            }
            
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if color.palette != nil {
                        showDetachConfirmation = true
                    } else {
                        isShowingPaletteSelection = true
                    }
                } label: {
                    Label("Palette", systemImage: (color.palette != nil) ? "swatchpalette.fill" : "swatchpalette")
                        .foregroundStyle(.purple, .orange, .red)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    copyHex(for: color)
                    withAnimation(.easeIn(duration: 0.15)) {
                        didCopyHex = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            didCopyHex = false
                        }
                    }
                } label: {
                    Label(
                        didCopyHex ? "Copied" : "Copy Hex",
                        systemImage: didCopyHex ? "checkmark" : "number"
                    )
                }
                .tint(didCopyHex ? .green : nil)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingName = true
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive){
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button {
                        if let image = solidColorImage(from: color) {
                            shareImage = image
                            isShowingShareSheet = true
                        }
                    } label: {
                        Label("Share As Image", systemImage: "photo.badge.plus")
                    }
                    
                    Button {
                        do {
                            shareFileURL = try SharingService.exportColor(color)
                            isShowingFileShareSheet = true
                        } catch {
                            // Export failed silently
                        }
                    } label: {
                        Label("Share Color", systemImage: "paintpalette.fill")
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
                ShareSheetPresenter(image: image, isPresented: $isShowingShareSheet)
            )
            .background(
                FileShareSheetPresenter(fileURL: shareFileURL, isPresented: $isShowingFileShareSheet)
            )
    }

    @ViewBuilder
    private var notesSection: some View {
        NotesSectionView(
            notes: $notesDraft,
            isSaving: $isSavingNotes,
            onSave: saveNotes
        )
    }

    private func saveNotes() {
        isSavingNotes = true
        defer { isSavingNotes = false }

        do {
            try colorManager.updateColor(color) { c in
                let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                c.notes = trimmed.isEmpty ? nil : trimmed
            }
        } catch {
            // TODO: error handling
        }
    }
}

#Preview("Color Detail") {
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
        ColorDetailView(color: OpaliteColor.sample)
    }
    .environment(manager)
    .modelContainer(container)
}
