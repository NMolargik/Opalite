//
//  ColorDetailView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/7/25.
//

import SwiftUI
import SwiftData

struct ColorDetailView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(ColorManager.self) private var colorManager
    
    let color: OpaliteColor
    @State private var viewModel: ViewModel
    @FocusState private var isNameFieldFocused: Bool
    
    init(color: OpaliteColor) {
        self.color = color
        self._viewModel = State(initialValue: ViewModel(color: color))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LargeSwatchView(
                    viewModel: viewModel,
                    isNameFieldFocused: $isNameFieldFocused
                )
                
                ColorMetadataView(
                    isExpanded: $viewModel.isDetailsExpanded,
                    createdByText: viewModel.createdByText,
                    createdOnDeviceText: viewModel.createdOnDeviceText,
                    createdAtText: viewModel.createdAtText,
                    updatedAtText: viewModel.updatedAtText,
                    updatedOnDeviceText: viewModel.updatedOnDeviceText
                )
                
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeaderView(title: "Other Colors", systemImage: "paintpalette")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            OtherColorTileView(
                                color: viewModel.color.complementaryColor(),
                                badge: "Complementary",
                                saveColor: {
                                    viewModel.saveOtherColor(viewModel.color.complementaryColor(), using: colorManager)
                                },
                                saveToPalette: {
                                    viewModel.saveColorToPalette(color: viewModel.color.complementaryColor())
                                }
                            )
                            ForEach(viewModel.color.harmoniousColors(), id: \.id) { harm in
                                OtherColorTileView(
                                    color: harm,
                                    badge: "Harmonious",
                                    saveColor: {
                                        viewModel.saveOtherColor(harm, using: colorManager)
                                    },
                                    saveToPalette: {
                                        viewModel.saveColorToPalette(color: harm)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1)
                )
                
                Spacer(minLength: 8)
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        viewModel.isEditingColor = true
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.titleOnly)
                }
                
                Button {
                    viewModel.beginEditName()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isNameFieldFocused = true
                    }
                } label: {
                    Label("Name", systemImage: "character.cursor.ibeam")
                }
                
                Button {
                    viewModel.saveColorToPalette(color: viewModel.color)
                } label: {
                    Label("Palette", systemImage: "swatchpalette")
                }
                
                Button {
                    viewModel.copyHex()
                } label: {
                    Label("Hashtag", systemImage: viewModel.didCopyHex ? "checkmark" : "number")
                }
                
                Menu {
                    // TODO: fix color data sharing
                    ShareLink(item: (viewModel.color.name?.isEmpty == false ? "\(viewModel.color.name!) (\(viewModel.color.hexString))" : viewModel.color.hexString)) {
                        Label("Share Color", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        viewModel.shareColorAsImage()
                    } label: {
                        Label("Share As Image", systemImage: "photo")
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingPalettePicker) {
            PaletteSelectionSheet(
                palettes: colorManager.palettes,
                onCancel: {
                    viewModel.cancelPaletteSelection()
                },
                onCreateAndSelect: { name in
                    viewModel.createPaletteAndSavePendingColor(named: name, using: colorManager)
                },
                onSelect: { palette in
                    viewModel.savePendingColor(to: palette, using: colorManager)
                }
            )
            #if os(iOS) || os(visionOS)
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled()
            #endif
        }
        .sheet(isPresented: $viewModel.isEditingColor) {
            NavigationStack {
                ColorEditorView(
                    color: viewModel.color,
                    onCancel: {
                        viewModel.isEditingColor = false
                    },
                    onApprove: { editedColor in
                        viewModel.approveEdit(with: editedColor, using: colorManager)
                    }
                )
            }
            #if os(iOS) || os(visionOS)
            .presentationDetents([.large])
            .interactiveDismissDisabled()
            #endif
        }
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

    // Insert sample data into the in-memory context for previews
    // Assumes `OpalitePalette.sample` and `OpaliteColor.sample` static properties exist
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

    // Optionally refresh the manager's caches for immediate display
    Task { await colorManager.refresh() }

    return ColorDetailView(color: OpaliteColor.sample)
        .modelContainer(container)
        .environment(colorManager)
}
