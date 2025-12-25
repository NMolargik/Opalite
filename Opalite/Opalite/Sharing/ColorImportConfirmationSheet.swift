//
//  ColorImportConfirmationSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/21/25.
//

import SwiftUI

struct ColorImportConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager

    let preview: ColorImportPreview
    let onComplete: () -> Void

    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Color Preview
                    SwatchView(
                        fill: [preview.color],
                        height: 180,
                        badgeText: preview.color.name ?? preview.color.hexString,
                        showOverlays: true
                    )

                    // Metadata
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            if let name = preview.color.name, !name.isEmpty {
                                LabeledContent("Name", value: name)
                            }
                            LabeledContent("Hex", value: preview.color.hexString)
                            LabeledContent("RGB", value: preview.color.rgbString)
                            if let author = preview.color.createdByDisplayName, !author.isEmpty, author != "Unknown" {
                                LabeledContent("Created by", value: author)
                            }
                            if let notes = preview.color.notes, !notes.isEmpty {
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

                    // Duplicate Warning
                    if preview.willSkip {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Color Already Exists")
                                    .font(.headline)
                                Text("A color with this ID is already in your portfolio. It will be skipped.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
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
            .navigationTitle("Import Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.impact()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        HapticsManager.shared.impact()
                        withAnimation {
                            performImport()
                        }
                    }
                    .disabled(isImporting || preview.willSkip)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func performImport() {
        isImporting = true
        preview.color.updatedAt = Date()

        do {
            _ = try colorManager.createColor(existing: preview.color)
            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isImporting = false
        }
    }
}
