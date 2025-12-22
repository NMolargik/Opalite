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
    @Environment(ToastManager.self) private var toastManager

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var selectedCanvasFile: CanvasFile? = nil

    // Rename canvas state
    @State private var canvasToRename: CanvasFile? = nil
    @State private var renameText: String = ""

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
                        Button {
                            renameText = canvasFile.title
                            canvasToRename = canvasFile
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            do {
                                try canvasManager.deleteCanvas(canvasFile)
                                if selectedCanvasFile?.id == canvasFile.id {
                                    selectedCanvasFile = nil
                                }
                            } catch {
                                toastManager.show(error: .canvasDeletionFailed)
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
                            toastManager.show(error: .canvasCreationFailed)
                        }
                    }, label: {
                        Label("New Canvas", systemImage: "plus")
                    })
                    .tint(.red)
                }
            }
            .alert("Rename Canvas", isPresented: Binding(
                get: { canvasToRename != nil },
                set: { if !$0 { canvasToRename = nil } }
            )) {
                TextField("Canvas name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    canvasToRename = nil
                }
                Button("Rename") {
                    if let canvas = canvasToRename {
                        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            try? canvasManager.updateCanvas(canvas) { c in
                                c.title = trimmed
                            }
                        }
                    }
                    canvasToRename = nil
                }
            }
            .onChange(of: canvasManager.pendingCanvasToOpen) { _, newValue in
                if let canvas = newValue {
                    selectedCanvasFile = canvas
                    canvasManager.pendingCanvasToOpen = nil
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
                toastManager.show(error: .canvasDeletionFailed)
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
