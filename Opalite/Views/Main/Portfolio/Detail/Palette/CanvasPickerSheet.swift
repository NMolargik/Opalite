//
//  CanvasPickerSheet.swift
//  Opalite
//
//  Created by Nick Molargik on 2/21/26.
//

import SwiftUI
import SwiftData

#if canImport(PencilKit)
struct CanvasPickerSheet: View {
    @Environment(CanvasManager.self) private var canvasManager
    @Environment(\.dismiss) private var dismiss

    let onCanvasSelected: (CanvasFile) -> Void

    @State private var searchText: String = ""

    private var filteredCanvases: [CanvasFile] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return canvasManager.canvases }
        return canvasManager.canvases.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCanvases) { canvas in
                    Button {
                        HapticsManager.shared.selection()
                        onCanvasSelected(canvas)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "scribble")
                                .foregroundStyle(.red)

                            Text(canvas.title)
                                .bold()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.automatic)
            .navigationTitle("Choose Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticsManager.shared.selection()
                        dismiss()
                    }
                    .tint(.red)
                }
            }
            .overlay {
                if canvasManager.canvases.isEmpty {
                    ContentUnavailableView(
                        "No Canvases",
                        systemImage: "pencil.and.scribble",
                        description: Text("Create a canvas first from the Canvas tab.")
                    )
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: OpaliteColor.self,
        OpalitePalette.self,
        CanvasFile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let canvasManager = CanvasManager(context: container.mainContext)
    do {
        try canvasManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }

    return CanvasPickerSheet { canvas in
        print("Selected: \(canvas.title)")
    }
    .environment(canvasManager)
}
#endif
