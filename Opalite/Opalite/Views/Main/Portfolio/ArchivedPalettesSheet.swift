//
//  ArchivedPalettesSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 2/28/26.
//

import SwiftUI
import SwiftData

struct ArchivedPalettesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    @State private var isProcessing: Bool = false
    @State private var paletteToDelete: OpalitePalette?
    @State private var isShowingDeleteConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            List {
                if colorManager.archivedPalettes.isEmpty {
                    ContentUnavailableView(
                        "No Archived Palettes",
                        systemImage: "archivebox",
                        description: Text("When you archive a palette, it will appear here.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(colorManager.archivedPalettes) { palette in
                            Button {
                                HapticsManager.shared.selection()
                                unarchivePalette(palette)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(palette.name)
                                            .font(.headline)

                                        if palette.sortedColors.isEmpty {
                                            Text("No colors")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        } else {
                                            HStack(spacing: 4) {
                                                ForEach(palette.sortedColors.prefix(8)) { paletteColor in
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(paletteColor.swiftUIColor)
                                                        .frame(width: 24, height: 24)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 4)
                                                                .strokeBorder(.secondary.opacity(0.2), lineWidth: 0.5)
                                                        )
                                                }

                                                if palette.sortedColors.count > 8 {
                                                    Text("+\(palette.sortedColors.count - 8)")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                        .padding(.leading, 2)
                                                }
                                            }
                                            .accessibilityHidden(true)
                                        }
                                    }
                                    Spacer()
                                    
                                    Label("Unarchive", systemImage: "arrow.uturn.backward")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                        .labelStyle(.iconOnly)
                                        .accessibilityHidden(true)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    HapticsManager.shared.selection()
                                    paletteToDelete = palette
                                    isShowingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(palette.name), \(palette.sortedColors.count) colors")
                            .accessibilityHint("Double tap to unarchive this palette. Swipe left to delete.")
                        }
                    } header: {
                        Text("Archived Palettes (\(colorManager.archivedPalettes.count))")
                    } footer: {
                        Text("Tap a palette to unarchive it and return it to your active palettes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Archived Palettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                }
            }
            .alert(
                "Delete \(paletteToDelete?.name ?? "Palette")?",
                isPresented: $isShowingDeleteConfirmation
            ) {
                Button("Cancel", role: .cancel) {
                    HapticsManager.shared.selection()
                    paletteToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    HapticsManager.shared.selection()
                    if let palette = paletteToDelete {
                        deletePalette(palette)
                    }
                    paletteToDelete = nil
                }
            } message: {
                if let palette = paletteToDelete {
                    if palette.sortedColors.isEmpty {
                        Text("This action cannot be undone.")
                    } else {
                        Text("This will permanently delete the palette and \(palette.sortedColors.count) color\(palette.sortedColors.count == 1 ? "" : "s"). This action cannot be undone.")
                    }
                } else {
                    Text("This action cannot be undone.")
                }
            }
        }
    }

    private func unarchivePalette(_ palette: OpalitePalette) {
        withAnimation {
            isProcessing = true
            defer { isProcessing = false }

            do {
                try colorManager.unarchivePalette(palette)
                Task { await colorManager.refreshAll() }
                toastManager.show(
                    message: "\(palette.name) unarchived",
                    style: .success
                )
            } catch {
                toastManager.show(error: .paletteUpdateFailed)
#if DEBUG
                print("[ArchivedPalettesSheet] unarchivePalette error: \(error)")
#endif
            }
        }
    }

    private func deletePalette(_ palette: OpalitePalette) {
        withAnimation {
            isProcessing = true
            defer { isProcessing = false }

            do {
                try colorManager.deletePalette(palette, andColors: true)
                Task { await colorManager.refreshAll() }
                toastManager.show(
                    message: "\(palette.name) deleted",
                    style: .success
                )
            } catch {
                toastManager.show(error: .paletteDeletionFailed)
#if DEBUG
                print("[ArchivedPalettesSheet] deletePalette error: \(error)")
#endif
            }
        }
    }
}

#Preview("Archived Palettes Sheet") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    
    // Create some archived palettes for preview
    let archivedPalette1 = OpalitePalette(
        name: "Archived Sunset",
        isArchived: true,
        colors: [
            OpaliteColor(name: "Orange", red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0),
            OpaliteColor(name: "Red", red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ]
    )
    let archivedPalette2 = OpalitePalette(
        name: "Archived Ocean",
        isArchived: true,
        colors: []
    )
    
    _ = try? manager.createPalette(existing: archivedPalette1)
    _ = try? manager.createPalette(existing: archivedPalette2)
    
    return ArchivedPalettesSheet()
        .environment(manager)
        .environment(ToastManager())
        .modelContainer(container)
}
