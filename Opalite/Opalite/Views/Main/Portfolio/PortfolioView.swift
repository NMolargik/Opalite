//
//  PortfolioView.swift
//  Opalite
//
//  Created by Nick Molargik on 12/17/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Observation

#if canImport(UIKit)
import UIKit
#endif

struct PortfolioView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.openWindow) private var openWindow
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(QuickActionManager.self) private var quickActionManager

    @State private var paletteSelectionColor: OpaliteColor?
    @State private var isShowingPaywall: Bool = false
    @State private var shareImage: UIImage?
    @State private var shareImageTitle: String = "Shared from Opalite"
    @State private var isShowingShareSheet = false
    @State private var isShowingColorEditor = false
    @State private var pendingPaletteToAddTo: OpalitePalette? = nil
    @State private var swatchSize: SwatchSize = .small
    @State private var navigationPath = [PortfolioNavigationNode]()
    @State private var shareFileURL: URL?
    @State private var isShowingFileShareSheet = false
    @State private var isShowingFileImporter = false
    @State private var importError: String?
    @State private var isShowingImportError = false
    @State private var quickActionTrigger: UUID? = nil

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
                    .padding(.bottom, 5)
                    
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
                                withAnimation {
                                    HapticsManager.shared.selection()
                                    if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                                        do {
                                            try colorManager.createPalette(name: "New Palette")
                                        } catch {
                                            toastManager.show(error: .paletteCreationFailed)
                                        }
                                    } else {
                                        isShowingPaywall = true
                                    }
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
                                .frame(height: 20)
                                .padding(8)
                                .multilineTextAlignment(.center)
                                .glassIfAvailable(
                                    GlassConfiguration(style: .clear)
                                        .tint(.blue)
                                        .interactive()
                                )
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
            .navigationTitle("Opalite")
            .toolbarBackground(.hidden)
            .task {
                swatchSize = isCompact ? .small : .medium
            }
            .onChange(of: quickActionManager.newColorTrigger) { _, newValue in
                guard let token = newValue else { return }
                quickActionTrigger = token
                pendingPaletteToAddTo = nil
                isShowingColorEditor = true
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
                            toastManager.show(error: .colorCreationFailed)
                        }

                        isShowingColorEditor.toggle()
                    }
                )
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.opaliteColor, .opalitePalette],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Error", isPresented: $isShowingImportError) {
                Button("OK", role: .cancel) {
                    HapticsManager.shared.selection()
                }
            } message: {
                Text(importError ?? "An unknown error occurred.")
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(featureContext: "This feature requires Onyx")
            }
            .toolbar {
                if isIPadOrMac && !colorManager.isSwatchBarOpen {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticsManager.shared.selection()
                            openWindow(id: "swatchBar")
                        } label: {
                            Label("Open SwatchBar", systemImage: "square.stack")
                        }
                    }

                    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                }
                
                if !isCompact {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            HapticsManager.shared.selection()
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
                            HapticsManager.shared.selection()
                            isShowingColorEditor.toggle()
                        }, label: {
                            Label {
                                Text("New Color")
                            } icon: {
                                Image(systemName: "paintpalette.fill")
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.blue)
                            }
                        })

                        Button(action: {
                            withAnimation {
                                HapticsManager.shared.selection()
                                if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                                    do {
                                        try colorManager.createPalette(name: "New Palette")
                                    } catch {
                                        toastManager.show(error: .paletteCreationFailed)
                                    }
                                } else {
                                    isShowingPaywall = true
                                }
                            }
                        }, label: {
                            Label {
                                HStack {
                                    Text("New Palette")
                                    if !subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                                        Image(systemName: "lock.fill")
                                            .font(.footnote)
                                    }
                                }
                            } icon: {
                                Image(systemName: "swatchpalette.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.purple, .orange, .red)
                            }
                        })

                        Divider()

                        Button(action: {
                            HapticsManager.shared.selection()
                            if subscriptionManager.hasOnyxEntitlement {
                                isShowingFileImporter = true
                            } else {
                                isShowingPaywall = true
                            }
                        }, label: {
                            Label {
                                HStack {
                                    Text("Import From File")
                                    if !subscriptionManager.hasOnyxEntitlement {
                                        Image(systemName: "lock.fill")
                                            .font(.footnote)
                                    }
                                }
                            } icon: {
                                Image(systemName: "square.and.arrow.down")
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
                ShareSheetPresenter(image: image, title: shareImageTitle, isPresented: $isShowingShareSheet)
            )
            .background(
                FileShareSheetPresenter(fileURL: shareFileURL, isPresented: $isShowingFileShareSheet)
            )
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Gain security-scoped access
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Unable to access the selected file."
                isShowingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let pathExtension = url.pathExtension.lowercased()

            do {
                if pathExtension == "opalitecolor" {
                    let preview = try SharingService.previewColorImport(
                        from: url,
                        existingColors: colorManager.colors
                    )
                    if preview.willSkip {
                        importError = "This color already exists in your portfolio."
                        isShowingImportError = true
                    } else {
                        _ = try colorManager.createColor(existing: preview.color)
                        Task { await colorManager.refreshAll() }
                    }
                } else if pathExtension == "opalitepalette" {
                    let preview = try SharingService.previewPaletteImport(
                        from: url,
                        existingPalettes: colorManager.palettes,
                        existingColors: colorManager.colors
                    )
                    if preview.willUpdate {
                        importError = "A palette with this ID already exists."
                        isShowingImportError = true
                    } else {
                        _ = try colorManager.createPalette(existing: preview.palette)
                        Task { await colorManager.refreshAll() }
                    }
                } else {
                    importError = "Unsupported file type."
                    isShowingImportError = true
                }
            } catch {
                importError = error.localizedDescription
                isShowingImportError = true
            }

        case .failure(let error):
            importError = error.localizedDescription
            isShowingImportError = true
        }
    }

    @ViewBuilder
    private func menuContent(color: OpaliteColor, palette: OpalitePalette? = nil) -> AnyView {
        AnyView(
            Group {
                Button {
                    HapticsManager.shared.selection()
                    copyHex(for: color)
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }
                  
                if palette == nil {
                    Button {
                        HapticsManager.shared.selection()
                        paletteSelectionColor = color
                    } label: {
                        Label("Add To Palette", systemImage: "swatchpalette.fill")
                    }
                }
                
                Divider()
                
                Button {
                    HapticsManager.shared.selection()
                    if let image = solidColorImage(from: color) {
                        shareImage = image
                        shareImageTitle = color.name ?? color.hexString
                        isShowingShareSheet = true
                    }
                } label: {
                    Label("Share As Image", systemImage: "photo.on.rectangle")
                }
                
                Button {
                    HapticsManager.shared.selection()
                    do {
                        shareFileURL = try SharingService.exportColor(color)
                        isShowingFileShareSheet = true
                    } catch {
                        // Export failed silently
                    }
                } label: {
                    Label("Share Color", systemImage: "square.and.arrow.up")
                }
                
                Divider()
                
                if let _ = palette {
                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        withAnimation {
                            colorManager.detachColorFromPalette(color)
                        }
                    } label: {
                        Label("Remove From Palette", systemImage: "swatchpalette")
                    }
                }
                
                Button(role: .destructive) {
                    HapticsManager.shared.selection()
                    withAnimation {
                        do {
                            try colorManager.deleteColor(color)
                        } catch {
                            toastManager.show(error: .colorDeletionFailed)
                        }
                    }
                } label: {
                    Label("Delete Color", systemImage: "trash.fill")
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
        .environment(ToastManager())
        .environment(SubscriptionManager())
        .modelContainer(container)
}
