//
//  PaletteImportConfirmationSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

struct PaletteImportConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager

    let preview: PaletteImportPreview
    let onComplete: () -> Void

    @State private var isImporting = false
    @State private var errorMessage: String?

    private var allColors: [OpaliteColor] {
        preview.palette.colors ?? []
    }

    private var canImport: Bool {
        // Can import if there's a new palette, or if there are new colors to add to existing palette
        !preview.willUpdate || !preview.newColors.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Palette Preview
                    SwatchView(
                        fill: allColors,
                        height: 180,
                        badgeText: preview.palette.name,
                        showOverlays: true
                    )

                    // Metadata
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("Name", value: preview.palette.name)
                            LabeledContent("Colors", value: "\(allColors.count)")
                            if !preview.palette.tags.isEmpty {
                                LabeledContent("Tags", value: preview.palette.tags.joined(separator: ", "))
                            }
                            if let author = preview.palette.createdByDisplayName, !author.isEmpty {
                                LabeledContent("Created by", value: author)
                            }
                            if let notes = preview.palette.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(notes)
                                        .font(.callout)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Import Summary
                    GroupBox("Import Summary") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(preview.newColors.count) new color(s) will be imported")
                                    .font(.callout)
                            }

                            if !preview.existingColors.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(.yellow)
                                    Text("\(preview.existingColors.count) color(s) already exist and will be skipped")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Duplicate Palette Warning
                    if preview.willUpdate {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Palette Already Exists")
                                    .font(.headline)
                                if preview.newColors.isEmpty {
                                    Text("This palette and all its colors already exist in your portfolio.")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("This palette exists, but \(preview.newColors.count) new color(s) will be added to it.")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Import Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        performImport()
                    }
                    .disabled(isImporting || !canImport)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func performImport() {
        isImporting = true

        do {
            if preview.willUpdate {
                // Palette exists - only add new colors to existing palette
                if let existingPalette = preview.existingPalette {
                    for color in preview.newColors {
                        let createdColor = try colorManager.createColor(existing: color)
                        colorManager.attachColor(createdColor, to: existingPalette)
                    }
                }
            } else {
                // Create new palette with only new colors (skip existing ones)
                let paletteToImport = OpalitePalette(
                    id: preview.palette.id,
                    name: preview.palette.name,
                    createdAt: preview.palette.createdAt,
                    updatedAt: preview.palette.updatedAt,
                    createdByDisplayName: preview.palette.createdByDisplayName,
                    notes: preview.palette.notes,
                    tags: preview.palette.tags,
                    colors: preview.newColors
                )
                _ = try colorManager.createPalette(existing: paletteToImport)
            }

            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isImporting = false
        }
    }
}
