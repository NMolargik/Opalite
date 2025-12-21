//
//  PortfolioView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct PortfolioView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.openWindow) private var openWindow
    @Environment(ColorManager.self) private var colorManager
    
    @State private var paletteSelectionColor: OpaliteColor?
    @State private var shareImage: UIImage?
    @State private var isShowingShareSheet = false
    @State private var isShowingColorEditor = false
    @State private var pendingPaletteToAddTo: OpalitePalette? = nil
    @State private var swatchSize: SwatchSize = .small
    @State private var navigationPath = [PortfolioNavigationNode]()
    
    @Namespace private var namespace
    @Namespace private var swatchNS
    
    var isCompact: Bool { hSizeClass == .compact }

    private var isIPadOrMac: Bool {
#if os(macOS)
        return true
#elseif targetEnvironment(macCatalyst)
        return true
#else
        return UIDevice.current.userInterfaceIdiom == .pad
#endif
    }
    
    var body: some View {
        NavigationStack() {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 20) {
                    
                    // MARK: - Colors Row
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Colors")
                    }
                    .font(.title)
                    .bold()
                    .padding(.leading, 20)
                    
                    SwatchRowView(
                        colors: colorManager.looseColors,
                        palette: pendingPaletteToAddTo,
                        swatchWidth: swatchSize.size,
                        swatchHeight: swatchSize.size,
                        showOverlays: swatchSize.showOverlays,
                        menuContent: { color in
                            if (swatchSize.showOverlays) {
                                return menuContent(color: color)
                            } else {
                                return AnyView(EmptyView())
                            }
                        },
                        contextMenuContent: { color in
                            if (!swatchSize.showOverlays) {
                                return menuContent(color: color)
                            } else {
                                return AnyView(EmptyView())
                            }
                        },
                        matchedNamespace: swatchNS
                    )
                    .zIndex(1)
                    
                    // MARK: - Palette Rows
                    HStack {
                        Image(systemName: "swatchpalette.fill")
                            .foregroundStyle(.purple.gradient, .orange.gradient, .red.gradient)
                        
                        Text("Palettes")
                    }
                    .font(.title)
                    .bold()
                    .padding(.leading, 20)
                    
                    if (colorManager.palettes.isEmpty) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.turn.down.right")
                                .bold()
                            
                            Button {
                                do {
                                    try colorManager.createPalette(name: "New Palette")
                                } catch {
                                    // TODO: error handling
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "swatchpalette")
                                        .font(.title2)
                                    
                                    Text("Create A New Palette")
                                }
                                .bold()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(height: isCompact ? 20 : 40)
                                .padding(8)
                                .multilineTextAlignment(.center)
                                .glassEffect(.clear.tint(.blue).interactive())
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                                .hoverEffect(.lift)
                            }
                            
                            Spacer()
                        }
                        .padding(.leading, 35)
                    } else {
                        ForEach(colorManager.palettes.sorted(by: { $0.createdAt > $1.createdAt } )) { palette in
                            VStack(alignment: .leading, spacing: 5) {
                                PaletteRowHeaderView(palette: palette)
                                    .zIndex(0)
                                
                                SwatchRowView(
                                    colors: palette.colors?.sorted(by: { $0.updatedAt > $1.updatedAt }) ?? [],
                                    palette: palette,
                                    swatchWidth: swatchSize.size,
                                    swatchHeight: swatchSize.size,
                                    showOverlays: swatchSize.showOverlays,
                                    menuContent: { color in
                                        if (swatchSize.showOverlays) {
                                            return menuContent(color: color, palette: palette)
                                        } else {
                                            return AnyView(EmptyView())
                                        }
                                    },
                                    contextMenuContent: { color in
                                        if (!swatchSize.showOverlays) {
                                            return menuContent(color: color, palette: palette)
                                        } else {
                                            return AnyView(EmptyView())
                                        }
                                    },
                                    matchedNamespace: swatchNS
                                )
                                .zIndex(1)
                            }
                        }
                    }
                }
            }
            .toolbarBackground(.hidden)
            .task {
                swatchSize = isCompact ? .small : .medium
            }
            .refreshable {
                Task { await colorManager.refreshAll() }
            }
            .background(shareSheet(image: shareImage))
            .sheet(item: $paletteSelectionColor) { color in
                PaletteSelectionSheet(color: color)
                    .environment(colorManager)
            }
            .fullScreenCover(isPresented: $isShowingColorEditor) {
                ColorEditorView(
                    color: nil,
                    palette: pendingPaletteToAddTo,
                    onCancel: {
                        pendingPaletteToAddTo = nil
                        isShowingColorEditor = false
                    },
                    onApprove: { newColor in
                        do {
                            _ = try colorManager.createColor(existing: newColor)
                        } catch {
                            // TODO: error handling
                        }
                        
                        isShowingColorEditor.toggle()
                    }
                )
            }
            .toolbar {
                if isIPadOrMac && !colorManager.isSwatchBarOpen {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            openWindow(id: "swatchBar")
                        } label: {
                            Label("Open SwatchBar", systemImage: "square.stack")
                        }
                    }

                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                
                if !isCompact {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            withAnimation(.bouncy) {
                                swatchSize = swatchSize.next
                            }
                        }) {
                            Image(systemName: "square.arrowtriangle.4.outward")
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button(action: {
                            isShowingColorEditor.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundStyle(.green)
                                
                                Text("New Color")
                                    .bold()
                            }
                        })
                        
                        Button(action: {
                            do {
                                try colorManager.createPalette(name: "New Palette")
                            } catch {
                                // TODO: error handling
                            }
                        }, label: {
                            HStack {
                                Image(systemName: "swatchpalette.fill")
                                    .foregroundStyle(.purple, .orange, .red)
                                
                                Text("New Palette")
                                    .bold()
                            }
                        })
                    } label: {
                        Label("Create", systemImage: "plus")
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
    }
    
    @ViewBuilder
    private func shareSheet(image: UIImage?) -> some View {
        EmptyView()
            .background(
                ShareSheetPresenter(image: image, isPresented: $isShowingShareSheet)
            )
    }
    
    @ViewBuilder
    private func menuContent(color: OpaliteColor, palette: OpalitePalette? = nil) -> AnyView {
        AnyView(
            Group {
                Button {
                    copyHex(for: color)
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }
                  
                if palette == nil {
                    Button {
                        paletteSelectionColor = color
                    } label: {
                        Label("Add To Palette", systemImage: "swatchpalette.fill")
                    }
                }
                
                Divider()
                
                Button {
                    if let image = solidColorImage(from: color) {
                        shareImage = image
                        isShowingShareSheet = true
                    }
                } label: {
                    Label("Share As Image", systemImage: "photo.on.rectangle")
                }
                
                Button {
                    // TODO: Share Color
                } label: {
                    Label("Share Color", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                if let _ = palette {
                    Button(role: .destructive) {
                        colorManager.detachColorFromPalette(color)
                    } label: {
                        Label("Remove From Palette", systemImage: "swatchpalette")
                    }
                } else {
                    Button(role: .destructive) {
                        do {
                            try colorManager.deleteColor(color)
                        } catch {
                            // TODO: error handling
                        }
                    } label: {
                        Label("Delete Color", systemImage: "trash.fill")
                    }
                }
            }
        )
    }
}

#Preview("Portfolio") {
    // In-memory SwiftData container for previews
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: OpalitePalette.self,
            OpaliteColor.self,
        configurations: config
    )

    let manager = ColorManager(context: container.mainContext)
    do {
        try manager.loadSamples()
    } catch {
        print("Failed to load samples into context")
    }

    return PortfolioView()
        .environment(manager)
        .modelContainer(container)
}
