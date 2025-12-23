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
    @Environment(SubscriptionManager.self) private var subscriptionManager

    let color: OpaliteColor

    @State private var newPaletteName: String = ""
    @State private var isCreating: Bool = false
    @State private var isShowingPaywall: Bool = false

    private var canCreate: Bool {
        !newPaletteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    private var canCreatePalette: Bool {
        subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "character.cursor.ibeam")
                                .foregroundStyle(.secondary)
                                .font(.body)

                            TextField("Palette name", text: $newPaletteName)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                                .onSubmit {
                                    if canCreate && canCreatePalette {
                                        createNewPaletteAndAttach()
                                    } else if canCreate && !canCreatePalette {
                                        isShowingPaywall = true
                                    }
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20))

                        Button {
                            HapticsManager.shared.selection()
                            if canCreatePalette {
                                createNewPaletteAndAttach()
                            } else {
                                isShowingPaywall = true
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if canCreatePalette {
                                    Label("Create New Palette", systemImage: "plus")
                                        .font(.headline)
                                } else {
                                    Label("Create New Palette", systemImage: "lock.fill")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreate)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                } header: {
                    HStack {
                        Text("Create")
                        if !canCreatePalette {
                            Text("(Onyx Required)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    if colorManager.palettes.isEmpty {
                        ContentUnavailableView(
                            "No Palettes",
                            systemImage: "swatchpalette",
                            description: Text("Create a palette above, or add more palettes to your Portfolio.")
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(colorManager.palettes) { palette in
                            Button {
                                HapticsManager.shared.selection()
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
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(featureContext: "Unlimited palettes require Onyx")
            }
        }
    }

    private func createNewPaletteAndAttach() {
        withAnimation {
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
    }

    private func attach(_ color: OpaliteColor, to palette: OpalitePalette) {
        withAnimation {
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
        .environment(SubscriptionManager())
        .environment(ToastManager())
        .modelContainer(container)
}
