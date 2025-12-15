//
//  PaletteSelectionSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/14/25.
//

import SwiftUI
import SwiftData

struct PaletteSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager

    let color: OpaliteColor

    @State private var newPaletteName: String = ""
    @State private var isCreating: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("New palette name", text: $newPaletteName)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            createNewPaletteAndAttach()
                        } label: {
                            Label("Create New Palette", systemImage: "plus.circle")
                                .font(.headline)
                                .labelStyle(.titleOnly)
                        }
                        .disabled(isCreating)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Create")
                }

                Section {
                    if colorManager.palettes.isEmpty {
                        ContentUnavailableView(
                            "No Palettes",
                            systemImage: "swatchpalette",
                            description: Text("Create a palette above, or add more palettes to your portfolio.")
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(colorManager.palettes) { palette in
                            Button {
                                attach(color, to: palette)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(palette.name)
                                            .font(.headline)
                                        if let count = palette.colors?.count {
                                            Text("\(count) color\(count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isCreating)
                        }
                    }
                } header: {
                    Text("Existing Palettes")
                }
            }
            .navigationTitle("Add to Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // A friendly default name
                if newPaletteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    newPaletteName = "New Palette"
                }
            }
        }
    }

    private func createNewPaletteAndAttach() {
        let name = newPaletteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isCreating = true
        defer { isCreating = false }

        do {
            let palette = try colorManager.createPalette(name: name)
            colorManager.attachColor(color, to: palette)
            dismiss()
        } catch {
            #if DEBUG
            print("[PaletteSelectionSheet] createNewPaletteAndAttach error: \(error)")
            #endif
        }
    }

    private func attach(_ color: OpaliteColor, to palette: OpalitePalette) {
        isCreating = true
        defer { isCreating = false }

        do {
            colorManager.attachColor(color, to: palette)
            try colorManager.saveContext()
            Task { await colorManager.refreshAll() }
            dismiss()
        } catch {
            #if DEBUG
            print("[PaletteSelectionSheet] attach error: \(error)")
            #endif
        }
    }
}

#Preview("Palette Selection Sheet") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
            OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    return PaletteSelectionSheet(color: OpaliteColor.sample)
    .environment(manager)
    .modelContainer(container)
}
