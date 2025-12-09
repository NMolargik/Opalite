//
//  PaletteTabView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/8/25.
//

import SwiftUI
import SwiftData
import Observation

struct PaletteTabView: View {
    @Environment(ColorManager.self) private var colorManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ViewModel()

    var unassignedColors: [OpaliteColor] {
        colorManager.colors.filter { $0.palette == nil }
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            Group {
                if horizontalSizeClass == .compact {
                    compactView
                } else {
                    regularView
                }
            }
            .navigationTitle("Opalite")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .palette(let palette):
                    PaletteDetailView(palette: palette)
                case .color(let color):
                    ColorDetailView(color: color)
                }
            }
        }
        .fullScreenCover(
            isPresented: $viewModel.isPresentingNewColorEditor
        ) {
            NavigationStack {
                ColorEditorView(
                    color: nil,
                    palette: nil,
                    onCancel: {
                        withAnimation {
                            viewModel.cancelCreateColor()
                        }
                    },
                    onApprove: { newColor in
                        withAnimation {
                            do {
                                try colorManager.addColor(newColor)
                            } catch {
                                print("Failed to save new color: \(error)")
                            }
                            viewModel.cancelCreateColor()
                            viewModel.pushColor(newColor)
                        }
                        Task { await colorManager.refresh() }
                    }
                )
            }
            .interactiveDismissDisabled()
        }
        .alert(
            "Delete Palette?",
            isPresented: $viewModel.isShowingDeletePaletteAlert,
            presenting: viewModel.pendingDeletionPalette
        ) { palette in
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeletePalette()
            }
            Button("Delete", role: .destructive) {
                if let toDelete = viewModel.pendingDeletionPalette {
                    withAnimation {
                        modelContext.delete(toDelete)
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to delete palette: \(error)")
                        }
                        Task { await colorManager.refresh() }
                    }
                }
                viewModel.cancelDeletePalette()
            }
        } message: { palette in
            Text("Are you sure you want to delete \"\(palette.name)\" and all of its colors?")
        }
        .alert(
            "Delete Color?",
            isPresented: $viewModel.isShowingDeleteColorAlert,
            presenting: viewModel.pendingDeletionColor
        ) { palette in
            Button("Cancel", role: .cancel) {
                viewModel.cancelDeleteColor()
            }
            Button("Delete", role: .destructive) {
                if let toDelete = viewModel.pendingDeletionColor {
                    withAnimation {
                        modelContext.delete(toDelete)
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to delete color: \(error)")
                        }
                        Task { await colorManager.refresh() }
                    }
                }
                viewModel.cancelDeleteColor()
            }
        } message: { color in
            Text("Are you sure you want to delete this color?")
        }
    }
    

    // MARK: - Layout Variants
    
    // MARK: - Compact View
    @ViewBuilder
    private var compactView: some View {
        List {
            // Palettes Section
            Section {
                DisclosureGroup(isExpanded: $viewModel.isPalettesExpanded) {
                    if colorManager.palettes.isEmpty {
                        ContentUnavailableView("No Palettes", systemImage: "swatchpalette")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(colorManager.palettes.sorted { ($0.isPinned == true) && ($1.isPinned == false) }, id: \.id) { palette in
                            NavigationLink(value: Route.palette(palette)) {
                                PaletteRowView(palette: palette)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    withAnimation {
                                        palette.isPinned.toggle()
                                        do {
                                            try modelContext.save()
                                        } catch {
                                            print("Failed to toggle pin: \(error)")
                                        }
                                        Task { await colorManager.refresh() }
                                    }
                                } label: {
                                    Label(palette.isPinned == true ? "Unpin" : "Pin",
                                          systemImage: palette.isPinned == true ? "pin.slash" : "pin.fill")
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .trailing) {
                                // Swipe right to request deletion (with confirmation alert)
                                Button(role: .destructive) {
                                    viewModel.requestDeletePalette(palette)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Palettes", systemImage: "swatchpalette")
                        .bold()
                        .foregroundStyle(.inverseTheme, .blue, .red)
                        .symbolEffect(viewModel.isPalettesExpanded ? .bounce.up : .bounce.down, value: viewModel.isPalettesExpanded)
                }
            }
            
            // Unassigned Colors Section
            Section {
                DisclosureGroup(isExpanded: $viewModel.isUnassignedExpanded) {
                    if unassignedColors.isEmpty {
                        ContentUnavailableView("No Loose Colors", systemImage: "paintpalette")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(unassignedColors.sorted { ($0.isPinned == true) && ($1.isPinned == false) }, id: \.id) { color in
                            NavigationLink(value: Route.color(color)) {
                                ColorRowView(color: color)
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            withAnimation {
                                                color.isPinned.toggle()
                                                do {
                                                    try modelContext.save()
                                                } catch {
                                                    print("Failed to toggle pin: \(error)")
                                                }
                                                Task { await colorManager.refresh() }
                                            }
                                        } label: {
                                            Label(color.isPinned == true ? "Unpin" : "Pin",
                                                  systemImage: color.isPinned == true ? "pin.slash" : "pin.fill")
                                        }
                                        .tint(.yellow)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        // Swipe right to request deletion (with confirmation alert)
                                        Button(role: .destructive) {
                                            viewModel.requestDeleteColor(color)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                } label: {
                    Label("Loose Colors", systemImage: "paintpalette")
                        .foregroundStyle(.inverseTheme, .blue, .red)
                        .bold()
                        .symbolEffect(viewModel.isUnassignedExpanded ? .bounce.up : .bounce.down, value: viewModel.isUnassignedExpanded)
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.inset)
#endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        withAnimation {
                            createPalette()
                        }
                    } label: {
                        Label("New Palette", systemImage: "swatchpalette")
                            .foregroundStyle(.inverseTheme, .blue, .red)
                    }
                    Button {
                        withAnimation {
                            createColor()
                        }
                    } label: {
                        Label("New Color", systemImage: "paintpalette")
                            .foregroundStyle(.inverseTheme, .blue, .red)
                        
                    }
                } label: {
                    Text("Create")
                        .bold()
                        .padding(5)
                }
            }
        }
    }
    
    // MARK: - Wide View

    @ViewBuilder
    private var regularView: some View {
        VStack(spacing: 20) {
            HStack {
                Label("Palettes", systemImage: "swatchpalette")
                    .bold()
                    .font(.title)
                    .foregroundStyle(.inverseTheme, .blue, .red)
                
                Spacer()
                
                Button("Create") {
                    withAnimation {
                        createPalette()
                    }
                }
                .padding(5)
                .bold()
                .buttonStyle(.borderedProminent)
                
                
            }
            .padding(10)
            .background(.thickMaterial)
            .cornerRadius(20)

            ScrollView {
                if colorManager.palettes.isEmpty {
                    ContentUnavailableView("No Palettes", systemImage: "swatchpalette")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(colorManager.palettes.sorted { ($0.isPinned == true) && ($1.isPinned == false) }, id: \.id) { palette in
                        NavigationLink(value: Route.palette(palette)) {
                            PaletteRowView(palette: palette)
                        }
                    }
                }
            }
            
            Section {
                HStack {
                    Label("Loose Colors", systemImage: "paintpalette")
                        .bold()
                        .font(.title)
                        .foregroundStyle(.inverseTheme, .blue, .red)
                    
                    Spacer()
                    
                    Button("Create") {
                        withAnimation {
                            createColor()
                        }
                    }
                    .padding(5)
                    .bold()
                    .buttonStyle(.borderedProminent)
                    
                    
                }
                .padding(10)
                .background(.thickMaterial)
                .cornerRadius(20)

                if unassignedColors.isEmpty {
                    ContentUnavailableView("No Loose Colors", systemImage: "paintpalette")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        ForEach(unassignedColors.sorted { ($0.isPinned == true) && ($1.isPinned == false) }, id: \.id) { color in
                            NavigationLink(value: Route.color(color)) {
                                ColorRowView(color: color)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func createPalette() {
        let name = Date.now.formatted(date: .numeric, time: .shortened)
        let newPalette = OpalitePalette(name: name)
        if newPalette.colors == nil { newPalette.colors = [] }

        do {
            try colorManager.addPalette(newPalette)
            viewModel.pushPalette(newPalette)
        } catch {
            print("Failed to add palette: \(error)")
        }
        
        Task { await colorManager.refresh() }
    }
    
    private func createColor() {
        viewModel.beginCreateColor()
    }
}

#Preview {
    let container: ModelContainer
    do {
        container = try ModelContainer(for: OpaliteColor.self, OpalitePalette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    } catch {
        fatalError("Preview ModelContainer setup failed: \(error)")
    }
    let colorManager = ColorManager(context: container.mainContext)
    let paletteSample = OpalitePalette.sample
    let colorSample = OpaliteColor.sample
    let colorSample2 = OpaliteColor.sample2

    // Associate the sample color with the sample palette if not already associated
    colorSample.palette = paletteSample
    if paletteSample.colors == nil { paletteSample.colors = [] }
    if !(paletteSample.colors?.contains(where: { $0.id == colorSample.id }) ?? false) {
        paletteSample.colors?.append(colorSample)
    }

    // Insert into the context
    container.mainContext.insert(paletteSample)
    container.mainContext.insert(colorSample)
    container.mainContext.insert(colorSample2)

    Task { await colorManager.refresh() }

    return PaletteTabView()
        .modelContainer(container)
        .environment(colorManager)
}

