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

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#endif

struct ColorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var viewModel: ColorDetailView.ViewModel

    @State private var shareImage: PlatformImage?
    @State private var shareImageTitle: String = "Shared from Opalite"
    @State private var isShowingShareSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isShowingColorEditor = false
    @State private var isEditingName: Bool? = false
    @State private var isShowingPaletteSelection: Bool = false
    @State private var showDetachConfirmation: Bool = false
    @State private var didCopyHex: Bool = false
    @State private var shareFileURL: URL?
    @State private var isShowingFileShareSheet = false
    @State private var isShowingPaywall: Bool = false

    let color: OpaliteColor
    
    init(color: OpaliteColor) {
        self.color = color
        _viewModel = State(wrappedValue: ColorDetailView.ViewModel.init(color: color))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SwatchView(
                    fill: [color],
                    height: 260,
                    badgeText: viewModel.badgeText,
                    showOverlays: true,
                    isEditingBadge: $isEditingName,
                    saveBadge: { newName in
                        viewModel.rename(to: newName, using: colorManager) { error in
                            toastManager.show(error: error)
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
                                        let _ = try colorManager.createColor(
                                            name: nil,
                                            notes: suggested.notes,
                                            device: nil,
                                            red: suggested.red,
                                            green: suggested.green,
                                            blue: suggested.blue,
                                            alpha: suggested.alpha,
                                            palette: color.palette
                                        )
                                    } catch {
                                        toastManager.show(error: .colorCreationFailed)
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
                                        alpha: suggested.alpha,
                                        palette: color.palette
                                    )
                                } catch {
                                    toastManager.show(error: .colorCreationFailed)
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
        .navigationBarTitleDisplayMode(.inline)
        .background(shareSheet(image: shareImage))
        .alert("Delete \(color.name ?? color.hexString)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }
            Button("Delete", role: .destructive) {
                HapticsManager.shared.selection()
                do {
                    try viewModel.deleteColor(using: colorManager)
                    dismiss()
                } catch {
                    toastManager.show(error: .colorDeletionFailed)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Remove from Palette?", isPresented: $showDetachConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }
            Button("Remove", role: .destructive) {
                HapticsManager.shared.selection()
                viewModel.detachFromPalette(using: colorManager)
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
                    viewModel.applyEditorUpdate(from: updatedColor, using: colorManager) { error in
                        toastManager.show(error: error)
                    }
                    isShowingColorEditor.toggle()
                }
            )
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(featureContext: "Data file export requires Onyx")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    isShowingColorEditor = true
                } label: {
                    Text("Edit")
                }
            }
            
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
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
                    HapticsManager.shared.selection()
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
                    HapticsManager.shared.selection()
                    withAnimation {
                        isEditingName = true
                    }
                } label: {
                    Label("Rename", systemImage: "character.cursor.ibeam")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive){
                    HapticsManager.shared.selection()
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Menu {
                    Button {
                        HapticsManager.shared.selection()
                        if let image = solidColorImage(from: color) {
                            shareImage = image
                            shareImageTitle = color.name ?? color.hexString
                            isShowingShareSheet = true
                        }
                    } label: {
                        Label("Share As Image", systemImage: "photo.badge.plus")
                    }
                    
                    Button {
                        HapticsManager.shared.selection()
                        if subscriptionManager.hasOnyxEntitlement {
                            do {
                                shareFileURL = try SharingService.exportColor(color)
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
                                Text("Export Color")
                                if !subscriptionManager.hasOnyxEntitlement {
                                    Image(systemName: "lock.fill")
                                        .font(.footnote)
                                }
                            }
                        } icon: {
                            Image(systemName: "paintpalette.fill")
                        }
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
    
    @ViewBuilder
    private func shareSheet(image: PlatformImage?) -> some View {
        EmptyView()
            .background(
                ShareSheetPresenter(image: image, title: shareImageTitle, isPresented: $isShowingShareSheet)
            )
            .background(
                FileShareSheetPresenter(fileURL: shareFileURL, isPresented: $isShowingFileShareSheet)
            )
    }

    @ViewBuilder
    private var notesSection: some View {
        NotesSectionView(
            notes: $viewModel.notesDraft,
            isSaving: $viewModel.isSavingNotes,
            onSave: {
                viewModel.saveNotes(using: colorManager) { error in
                    toastManager.show(error: error)
                }
            }
        )
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
    .environment(ToastManager())
    .environment(SubscriptionManager())
    .modelContainer(container)
}
