//
//  PaletteRowHeaderView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData
import TipKit

struct PaletteRowHeaderView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager

    private let paletteMenuTip = PaletteMenuTip()

    @State private var showDeleteConfirmation = false
    @State private var showRenameAlert = false
    @State private var renameText: String = ""
    @State private var isShowingColorEditor = false
    @State private var isShowingExportSheet: Bool = false

    let palette: OpalitePalette
    var showTip: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTip {
                TipView(paletteMenuTip)
                    .tipCornerRadius(16)
                    .padding(.horizontal, 5)
            }
            
            HStack(alignment: .center, spacing: 8) {
            Menu {
                if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
                    Button(role: .confirm) {
                        HapticsManager.shared.selection()
                        isShowingColorEditor.toggle()
                    } label: {
                        Label("Add Color", systemImage: "plus.square.dashed")
                    }
                } else {
                    Button {
                        HapticsManager.shared.selection()
                        isShowingColorEditor.toggle()
                    } label: {
                        Label("Add Color", systemImage: "plus.square.dashed")
                    }
                }
                
                Button {
                    HapticsManager.shared.selection()
                    renameText = palette.name
                    showRenameAlert = true
                } label: {
                    Label("Rename Palette", systemImage: "pencil")
                }
                
                Divider()
                
                Button {
                    HapticsManager.shared.selection()
                    isShowingExportSheet = true
                } label: {
                    Label("Share Palette", systemImage: "square.and.arrow.up")
                        .tint(.blue)

                }
                .disabled(palette.sortedColors.isEmpty)
                
                Divider()
                
                Button(role: .destructive) {
                    HapticsManager.shared.selection()
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Palette", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .imageScale(.large)
                    .foregroundStyle(.inverseTheme)
                    .frame(height: 20)
                    .padding(8)
                    .background(
                        Circle().fill(.clear)
                    )
                    .glassIfAvailable(
                        GlassConfiguration(style: .regular)
                    )
                    .contentShape(Circle())
                    .hoverEffect(.lift)
            }

            NavigationLink {
                PaletteDetailView(palette: palette)
                    .tint(.none)
            } label: {
                HStack(spacing: 8) {
                    Text(palette.name)
                        .font(.title2)

                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                }
                .frame(maxWidth: 300)
                .frame(height: 40)
                .bold()
                .padding(.leading)
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .hoverEffect(.lift)
            }
            .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .alert("Delete \(palette.name)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
            }

            Button("Delete Palette", role: .destructive) {
                withAnimation {
                    HapticsManager.shared.selection()
                    do {
                        try colorManager.deletePalette(palette, andColors: false)
                    } catch {
                        toastManager.show(error: .paletteDeletionFailed)
                    }
                }
            }

            if !(palette.colors?.isEmpty ?? false) {
                Button("Delete Palette and Colors", role: .destructive) {
                    HapticsManager.shared.selection()
                    withAnimation {
                        do {
                            try colorManager.deletePalette(palette, andColors: true)
                        } catch {
                            toastManager.show(error: .paletteDeletionFailed)
                        }
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Rename Palette", isPresented: $showRenameAlert) {
            TextField("Palette name", text: $renameText)
            Button("Cancel", role: .cancel) {
                HapticsManager.shared.selection()
                renameText = ""
            }
            Button("Save") {
                HapticsManager.shared.selection()
                let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !newName.isEmpty {
                    do {
                        try colorManager.renamePalette(palette, to: newName)
                    } catch {
                        toastManager.show(error: .paletteUpdateFailed)
                    }
                }
                renameText = ""
            }
        } message: {
            Text("Enter a new name for this palette.")
        }
        .sheet(isPresented: $isShowingExportSheet) {
            PaletteExportSheet(palette: palette)
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

                    isShowingColorEditor.toggle()
                }
            )
        }
    }
}

#Preview("Palette Header") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
            OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    return PaletteRowHeaderView(
        palette: OpalitePalette.sample
    )
    .environment(manager)
    .environment(ToastManager())
    .environment(SubscriptionManager())
    .modelContainer(container)
}
