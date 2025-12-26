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
    @State private var isShowingPaywall: Bool = false
    @State private var exportPDFURL: URL?
    @State private var isShowingPDFShareSheet = false
    
    let palette: OpalitePalette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SwatchView(
                    // Colors are pre-sorted by updatedAt from ColorManager
                    fill: palette.colors ?? [],
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
                            toastManager.show(error: .paletteUpdateFailed)
                        }
                    },
                    allowBadgeTapToEdit: true
                )
                .overlay {
                    if palette.colors?.isEmpty == true {
                        Text("No Colors Added To This Palette")
                    }
                }
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
                                    toastManager.show(error: .paletteUpdateFailed)
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
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Data file export requires Onyx")
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
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive){
                    HapticsManager.shared.selection()
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
            }
            
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button {
                        HapticsManager.shared.selection()
                        if let image = gradientImage(from: palette.colors ?? []) {
                            shareImage = image
                            shareImageTitle = palette.name
                            isShowingShareSheet = true
                        }
                    } label: {
                        Label("Share As Image", systemImage: "photo.badge.plus")
                    }
                    
                    Button {
                        HapticsManager.shared.selection()
                        do {
                            exportPDFURL = try PortfolioPDFExporter.exportPalette(palette, userName: userName)
                            isShowingPDFShareSheet = true
                        } catch {
                            toastManager.show(error: .pdfExportFailed)
                        }
                    } label: {
                        Label("Share As PDF", systemImage: "doc.richtext")
                    }

                    Button {
                        HapticsManager.shared.selection()
                        if subscriptionManager.hasOnyxEntitlement {
                            do {
                                shareFileURL = try SharingService.exportPalette(palette)
                                isShowingFileShareSheet = true
                            } catch {
                                // Export failed silently
                            }
                        } else {
                            isShowingPaywall = true
                        }
                    } label: {
                        Label {
                            HStack {
                                Text("Export Palette")
                                if !subscriptionManager.hasOnyxEntitlement {
                                    Image(systemName: "lock.fill")
                                        .font(.footnote)
                                }
                            }
                        } icon: {
                            Image(systemName: "swatchpalette.fill")
                        }
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
            .background(
                FileShareSheetPresenter(fileURL: exportPDFURL, isPresented: $isShowingPDFShareSheet)
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
            .environment(ToastManager())
            .environment(SubscriptionManager())
    }
}
