//
//  PaletteOrderSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 12/30/25.
//

import SwiftUI
import SwiftData

/// A sheet for reordering palettes and optionally selecting which to include in PDF export.
struct PaletteOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager

    @AppStorage(AppStorageKeys.paletteOrder) private var paletteOrderData: Data = Data()
    @AppStorage(AppStorageKeys.userName) private var userName: String = "User"

    /// When true, shows export controls and triggers PDF export on confirm
    let isForExport: Bool
    var onExport: (([OpalitePalette], [OpaliteColor]) -> Void)?

    @State private var orderedPaletteIDs: [UUID] = []
    @State private var selectedPaletteIDs: Set<UUID> = []
    @State private var includeLooseColors: Bool = true

    init(isForExport: Bool = false, onExport: (([OpalitePalette], [OpaliteColor]) -> Void)? = nil) {
        self.isForExport = isForExport
        self.onExport = onExport
    }

    private var orderedPalettes: [OpalitePalette] {
        let paletteDict = Dictionary(uniqueKeysWithValues: colorManager.palettes.map { ($0.id, $0) })
        var result: [OpalitePalette] = []

        // Add palettes in saved order
        for id in orderedPaletteIDs {
            if let palette = paletteDict[id] {
                result.append(palette)
            }
        }

        // Add any new palettes not in the saved order
        for palette in colorManager.palettes {
            if !orderedPaletteIDs.contains(palette.id) {
                result.append(palette)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if isForExport {
                    Section {
                        Toggle(isOn: $includeLooseColors) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Loose Colors")
                                    Text("\(colorManager.looseColors.count) colors")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "paintpalette")
                            }
                        }
                        .disabled(colorManager.looseColors.isEmpty)
                    } header: {
                        Text("Sections")
                    }
                }

                Section {
                    if orderedPalettes.isEmpty {
                        Text("No palettes")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(orderedPalettes) { palette in
                            HStack(spacing: 12) {
                                if isForExport {
                                    Image(systemName: selectedPaletteIDs.contains(palette.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedPaletteIDs.contains(palette.id) ? .blue : .secondary)
                                        .imageScale(.large)
                                        .onTapGesture {
                                            HapticsManager.shared.selection()
                                            if selectedPaletteIDs.contains(palette.id) {
                                                selectedPaletteIDs.remove(palette.id)
                                            } else {
                                                selectedPaletteIDs.insert(palette.id)
                                            }
                                        }
                                }

                                // Color preview swatches
                                HStack(spacing: -8) {
                                    ForEach(Array(palette.sortedColors.prefix(4).enumerated()), id: \.element.id) { index, color in
                                        Circle()
                                            .fill(color.swiftUIColor)
                                            .frame(width: 24, height: 24)
                                            .overlay(Circle().stroke(.white, lineWidth: 2))
                                            .zIndex(Double(4 - index))
                                    }
                                }
                                .frame(width: 72, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(palette.name)
                                        .fontWeight(.medium)
                                    Text("\(palette.sortedColors.count) colors")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard isForExport else { return }
                                HapticsManager.shared.selection()
                                if selectedPaletteIDs.contains(palette.id) {
                                    selectedPaletteIDs.remove(palette.id)
                                } else {
                                    selectedPaletteIDs.insert(palette.id)
                                }
                            }
                        }
                        .onMove(perform: movePalettes)
                    }
                } header: {
                    HStack {
                        Text("Palettes")
                        Spacer()
                        if isForExport && !orderedPalettes.isEmpty {
                            Button(selectedPaletteIDs.count == orderedPalettes.count ? "Deselect All" : "Select All") {
                                HapticsManager.shared.selection()
                                if selectedPaletteIDs.count == orderedPalettes.count {
                                    selectedPaletteIDs.removeAll()
                                } else {
                                    selectedPaletteIDs = Set(orderedPalettes.map { $0.id })
                                }
                            }
                            .font(.caption)
                            .textCase(.none)
                        }
                    }
                } footer: {
                    Text("Drag to reorder palettes. This order is used in the Portfolio view.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(isForExport ? "Export Portfolio" : "Reorder Palettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                    .tint(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isForExport {
                        Button("Export PDF") {
                            HapticsManager.shared.impact()
                            exportPDF()
                        }
                        .disabled(selectedPaletteIDs.isEmpty && !includeLooseColors)
                    } else {
                        Button("Done") {
                            HapticsManager.shared.selection()
                            saveOrder()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                loadOrder()
                if isForExport {
                    // Pre-select all palettes for export
                    selectedPaletteIDs = Set(colorManager.palettes.map { $0.id })
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Private Methods

    private func loadOrder() {
        guard !paletteOrderData.isEmpty,
              let decoded = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) else {
            orderedPaletteIDs = colorManager.palettes.map { $0.id }
            return
        }
        orderedPaletteIDs = decoded
    }

    private func saveOrder() {
        let ids = orderedPalettes.map { $0.id }
        if let encoded = try? JSONEncoder().encode(ids) {
            paletteOrderData = encoded
        }
    }

    private func movePalettes(from source: IndexSet, to destination: Int) {
        var ids = orderedPalettes.map { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        orderedPaletteIDs = ids
        saveOrder()
    }

    private func exportPDF() {
        let selectedPalettes = orderedPalettes.filter { selectedPaletteIDs.contains($0.id) }
        let looseColors = includeLooseColors ? colorManager.looseColors : []

        if let onExport = onExport {
            onExport(selectedPalettes, looseColors)
        }

        dismiss()
    }
}

#Preview("Reorder") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )
    let manager = ColorManager(context: container.mainContext)
    try? manager.loadSamples()

    return PaletteOrderSheet(isForExport: false)
        .environment(manager)
        .environment(ToastManager())
        .modelContainer(container)
}

#Preview("Export") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
        OpaliteColor.self,
        configurations: config
    )
    let manager = ColorManager(context: container.mainContext)
    try? manager.loadSamples()

    return PaletteOrderSheet(isForExport: true) { palettes, colors in
        print("Exporting \(palettes.count) palettes, \(colors.count) loose colors")
    }
        .environment(manager)
        .environment(ToastManager())
        .modelContainer(container)
}
