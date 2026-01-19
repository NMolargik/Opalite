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
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var path = NavigationPath()
    @State private var searchText = ""
    @State private var selectedCanvasFile: CanvasFile?
    @State private var isShowingPaywall: Bool = false

    // Rename canvas state
    @State private var canvasToRename: CanvasFile?
    @State private var renameText: String = ""

    private var filteredCanvases: [CanvasFile] {
        // Canvases are pre-sorted by CanvasManager
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return canvasManager.canvases }
        return canvasManager.canvases.filter { $0.title.localizedCaseInsensitiveContains(trimmedSearch) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(filteredCanvases) { canvasFile in
                    Button {
                        HapticsManager.shared.impact()
                        if subscriptionManager.hasOnyxEntitlement {
                            selectedCanvasFile = canvasFile
                        } else {
                            isShowingPaywall = true
                        }
                    } label: {
                        HStack {
                            Label {
                                Text(canvasFile.title)
                            } icon: {
                                Image(systemName: "scribble")
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                            if !subscriptionManager.hasOnyxEntitlement {
                                Image(systemName: "lock.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            HapticsManager.shared.impact()
                            renameText = canvasFile.title
                            canvasToRename = canvasFile
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Divider()

                        Button(role: .destructive) {
                            HapticsManager.shared.impact()
                            do {
                                try canvasManager.deleteCanvas(canvasFile)
                                if selectedCanvasFile?.id == canvasFile.id {
                                    selectedCanvasFile = nil
                                }
                            } catch {
                                toastManager.show(error: .canvasDeletionFailed)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
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
                                    HapticsManager.shared.impact()
                                    selectedCanvasFile = nil
                                } label: {
                                    Label("Close", systemImage: "xmark")
                                }
                                .tint(.red)
                            }
                        }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        HapticsManager.shared.impact()
                        if subscriptionManager.hasOnyxEntitlement {
                            do {
                                let newCanvasFile = try canvasManager.createCanvas(title: "New Canvas")
                                selectedCanvasFile = newCanvasFile
                            } catch {
                                toastManager.show(error: .canvasCreationFailed)
                            }
                        } else {
                            isShowingPaywall = true
                        }
                    }, label: {
                        Label("New Canvas", systemImage: "plus")
                    })
                    .tint(.red)
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(featureContext: "Canvas access requires Onyx")
            }
            .alert("Rename Canvas", isPresented: Binding(
                get: { canvasToRename != nil },
                set: { if !$0 { canvasToRename = nil } }
            )) {
                TextField("Canvas name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    HapticsManager.shared.impact()
                    canvasToRename = nil
                }
                .tint(.red)

                Button("Rename") {
                    HapticsManager.shared.impact()
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
        .environment(SubscriptionManager())
        .environment(ToastManager())
}
