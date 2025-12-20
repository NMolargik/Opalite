//
//  CanvasView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI
import SwiftData
import PencilKit

struct CanvasListView: View {
    @Environment(ColorManager.self) private var colorManager: ColorManager
    @Environment(CanvasManager.self) private var canvasManager: CanvasManager

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var selectedCanvasFile: CanvasFile? = nil

    private var filteredCanvases: [CanvasFile] {
        let sorted = canvasManager.canvases.sorted(by: { $0.createdAt > $1.createdAt })
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(filteredCanvases) { canvasFile in
                    Button {
                        selectedCanvasFile = canvasFile
                    } label: {
                        HStack {
                            Label {
                                Text(canvasFile.title)
                            } icon: {
                                Image(systemName: "scribble")
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                        }
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            do {
                                try canvasManager.deleteCanvas(canvasFile)
                                if selectedCanvasFile?.id == canvasFile.id {
                                    selectedCanvasFile = nil
                                }
                            } catch {
                                // TODO: error handling
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .listStyle(.automatic)
            .refreshable {
                Task {
                    await canvasManager.refreshAll()
                }
            }
            .navigationTitle("Canvas")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .fullScreenCover(item: $selectedCanvasFile, onDismiss: { selectedCanvasFile = nil }) { file in
                NavigationStack {
                    CanvasView(canvasFile: file)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    selectedCanvasFile = nil
                                } label: {
                                    Label("Close", systemImage: "xmark")
                                }
                                
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        do {
                            let newCanvasFile = try canvasManager.createCanvas(title: "New Canvas")
                            selectedCanvasFile = newCanvasFile
                        } catch {
                            // TODO: error handling
                        }
                    }, label: {
                        Label("New Canvas", systemImage: "plus")
                    })
                    .tint(.red)
                }
            }
        }
    }
    
    private func delete(at offsets: IndexSet) {
        let items = filteredCanvases
        for index in offsets {
            guard items.indices.contains(index) else { continue }
            let file = items[index]
            do {
                try canvasManager.deleteCanvas(file)
                if selectedCanvasFile?.id == file.id {
                    selectedCanvasFile = nil
                }
            } catch {
                // TODO: error handling
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
    let colorManager = ColorManager(context: container.mainContext)
    let canvasManager = CanvasManager(context: container.mainContext)
    do {
        try colorManager.loadSamples()
        try canvasManager.loadSamples()
    } catch {
        print("Failed to load samples")
    }

    return CanvasListView()
        .modelContainer(container)
        .environment(colorManager)
        .environment(canvasManager)
}
