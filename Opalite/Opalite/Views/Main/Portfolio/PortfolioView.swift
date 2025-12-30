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
import TipKit

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
    @Environment(HexCopyManager.self) private var hexCopyManager

    // MARK: - Tips
    private let createContentTip = CreateContentTip()
    private let dragAndDropTip = DragAndDropTip()
    private let colorDetailsTip = ColorDetailsTip()
    #if targetEnvironment(macCatalyst)
    private let screenSamplerTip = ScreenSamplerTip()
    #endif

    @State private var paletteSelectionColor: OpaliteColor?
    @State private var isShowingPaywall: Bool = false
    @State private var shareImage: UIImage?
    @State private var shareImageTitle: String = "Shared from Opalite"
    @State private var isShowingShareSheet = false
    @State private var isShowingColorEditor = false
    @State private var pendingPaletteToAddTo: OpalitePalette? = nil
    @AppStorage(AppStorageKeys.swatchSize) private var swatchSizeRaw: String = SwatchSize.medium.rawValue
    @State private var swatchSize: SwatchSize = .medium
    @State private var navigationPath = [PortfolioNavigationNode]()
    @State private var shareFileURL: URL?
    @State private var isShowingFileShareSheet = false
    @State private var isShowingFileImporter = false
    @State private var colorToExport: OpaliteColor?
    @State private var importError: String?
    @State private var isShowingImportError = false
    @State private var quickActionTrigger: UUID? = nil
    @State private var copiedColorID: UUID? = nil
    @State private var isShowingPhotoColorPicker = false
    @State private var droppedImageItem: DroppedImageItem? = nil
    @State private var colorToDelete: OpaliteColor?
    @State private var isShowingSwatchBarInfo = false
    @State private var isShowingQuickAddHex = false
    @State private var isShowingPaletteOrder = false
    @AppStorage(AppStorageKeys.paletteOrder) private var paletteOrderData: Data = Data()
    @State private var colorToRename: OpaliteColor?
    @State private var renameText: String = ""

    @Namespace private var namespace
    @Namespace private var swatchNS
    
    var isCompact: Bool { hSizeClass == .compact }

    /// Palettes ordered according to user's custom order
    private var orderedPalettes: [OpalitePalette] {
        guard !paletteOrderData.isEmpty,
              let savedOrder = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) else {
            return colorManager.palettes
        }

        let paletteDict = Dictionary(uniqueKeysWithValues: colorManager.palettes.map { ($0.id, $0) })
        var result: [OpalitePalette] = []

        // Add palettes in saved order
        for id in savedOrder {
            if let palette = paletteDict[id] {
                result.append(palette)
            }
        }

        // Add any new palettes not in the saved order (at the end)
        for palette in colorManager.palettes {
            if !savedOrder.contains(palette.id) {
                result.append(palette)
            }
        }

        return result
    }

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

                    // MARK: - Create Content Tip (shown first to new users)
                    TipView(createContentTip) { action in
                        // When user dismisses tip, enable the next tip
                        ColorDetailsTip.hasSeenCreateTip = true
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    #if targetEnvironment(macCatalyst)
                    // MARK: - Screen Sampler Tip (Mac only)
                    TipView(screenSamplerTip)
                        .padding(.horizontal, 20)
                    #endif

                    // MARK: - Colors Row
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(.blue.gradient)
                            .accessibilityHidden(true)

                        Text("Colors")
                    }
                    .font(.title)
                    .bold()
                    .padding(.leading, 20)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Colors, \(colorManager.looseColors.count) items")

                    // Color details tip - shown after create content tip is dismissed
                    TipView(colorDetailsTip)
                        .padding(.horizontal, 20)

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
                            // Always provide context menu for right-click support
                            return menuContent(color: color)
                        },
                        matchedNamespace: swatchNS,
                        copiedColorID: $copiedColorID
                    )
                    .zIndex(1)
                    .padding(.bottom, 5)
                    
                    // MARK: - Palette Rows
                    HStack {
                        Image(systemName: "swatchpalette.fill")
                            .foregroundStyle(.purple.gradient, .orange.gradient, .red.gradient)
                            .accessibilityHidden(true)

                        Text("Palettes")
                    }
                    .font(.title)
                    .bold()
                    .padding(.leading, 20)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Palettes, \(colorManager.palettes.count) items")
                    
                    if (colorManager.palettes.isEmpty) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.turn.down.right")
                                .bold()
                                .accessibilityHidden(true)

                            Button {
                                withAnimation {
                                    HapticsManager.shared.selection()
                                    if subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                                        do {
                                            let newPalette = try colorManager.createPalette(name: "New Palette")
                                            prependPaletteToOrder(newPalette.id)
                                            // User created content, advance tips
                                            createContentTip.invalidate(reason: .actionPerformed)
                                            ColorDetailsTip.hasSeenCreateTip = true
                                            DragAndDropTip.hasCreatedPalette = true
                                            PaletteMenuTip.hasCreatedPalette = true
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
                            .accessibilityLabel("Create A New Palette")
                            .accessibilityHint("Creates a new empty palette to organize your colors")

                            Spacer()
                        }
                        .padding(.leading, 35)
                    } else {
                        // Drag and drop tip - shown after first palette
                        TipView(dragAndDropTip)
                            .padding(.horizontal, 20)

                        // Palettes ordered by user's custom order (or default order)
                        ForEach(orderedPalettes) { palette in
                            VStack(alignment: .leading, spacing: 5) {
                                PaletteRowHeaderView(palette: palette)
                                    .zIndex(0)

                                SwatchRowView(
                                    // Colors sorted by createdAt (newest first)
                                    colors: palette.sortedColors,
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
                                        // Always provide context menu for right-click support
                                        return menuContent(color: color, palette: palette)
                                    },
                                    matchedNamespace: swatchNS,
                                    copiedColorID: $copiedColorID
                                )
                                .zIndex(1)
                            }
                        }
                    }
                }
            }
            .padding(.bottom)
            .scrollClipDisabled()
            #if canImport(UIKit)
            .onDrop(of: [.image], isTargeted: nil) { providers in
                handleImageDrop(providers: providers)
            }
            #endif
            #if targetEnvironment(macCatalyst)
            .background {
                Button("") {
                    sampleFromScreen()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .hidden()
            }
            #endif
            .navigationTitle("Opalite")
            .toolbarBackground(.hidden)
            .onAppear {
                // Load persisted swatch size
                if let stored = SwatchSize(rawValue: swatchSizeRaw) {
                    swatchSize = stored
                }
            }
            .onChange(of: swatchSize) { _, newValue in
                // Persist swatch size changes
                swatchSizeRaw = newValue.rawValue
            }
            .onChange(of: hSizeClass) { _, newValue in
                // Large swatches aren't available on compact screens
                if newValue == .compact && swatchSize == .large {
                    withAnimation(.bouncy) {
                        swatchSize = .medium
                    }
                }
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
                            createContentTip.invalidate(reason: .actionPerformed)
                            OpaliteTipActions.advanceTipsAfterContentCreation()
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
            .alert(
                "Delete \(colorToDelete?.name ?? colorToDelete?.hexString ?? "Color")?",
                isPresented: Binding(
                    get: { colorToDelete != nil },
                    set: { if !$0 { colorToDelete = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    HapticsManager.shared.selection()
                    colorToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    HapticsManager.shared.selection()
                    if let color = colorToDelete {
                        withAnimation {
                            do {
                                try colorManager.deleteColor(color)
                            } catch {
                                toastManager.show(error: .colorDeletionFailed)
                            }
                        }
                    }
                    colorToDelete = nil
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert(
                "Rename Color",
                isPresented: Binding(
                    get: { colorToRename != nil },
                    set: { if !$0 { colorToRename = nil } }
                )
            ) {
                TextField("Color name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    HapticsManager.shared.selection()
                    colorToRename = nil
                    renameText = ""
                }
                Button("Save") {
                    HapticsManager.shared.selection()
                    if let color = colorToRename {
                        do {
                            try colorManager.renameColor(color, to: renameText.isEmpty ? nil : renameText)
                        } catch {
                            toastManager.show(error: .colorUpdateFailed)
                        }
                    }
                    colorToRename = nil
                    renameText = ""
                }
            } message: {
                Text("Enter a new name for this color.")
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(featureContext: "This feature requires Onyx")
            }
            #if canImport(UIKit)
            .sheet(isPresented: $isShowingPhotoColorPicker) {
                PhotoColorPickerSheet()
            }
            .sheet(item: $droppedImageItem) { item in
                PhotoColorPickerSheet(initialImage: item.image)
            }
            #endif
            .sheet(item: $colorToExport) { color in
                ColorExportSheet(color: color)
            }
            .sheet(isPresented: $isShowingSwatchBarInfo) {
                SwatchBarInfoSheet()
            }
            .sheet(isPresented: $isShowingQuickAddHex) {
                QuickAddHexSheet()
            }
            .sheet(isPresented: $isShowingPaletteOrder) {
                PaletteOrderSheet(isForExport: false)
            }
            .toolbar {
                if isIPadOrMac {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticsManager.shared.selection()
                            isShowingSwatchBarInfo = true
                        } label: {
                            Label("SwatchBar", systemImage: "square.stack")
                        }
                    }
                }
                
                if !colorManager.palettes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticsManager.shared.selection()
                            isShowingPaletteOrder = true
                        } label: {
                            Label("Reorder Palettes", systemImage: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel("Reorder palettes")
                        .accessibilityHint("Opens a sheet to reorder your palettes")
                    }
                }

                if !colorManager.colors.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            HapticsManager.shared.selection()
                            withAnimation(.bouncy) {
                                swatchSize = isCompact ? swatchSize.nextCompact : swatchSize.next
                            }
                        }) {
                            Image(systemName: "square.arrowtriangle.4.outward")
                        }
                        .accessibilityLabel("Change swatch size")
                        .accessibilityHint(isCompact ? "Cycles between small and medium swatch sizes" : "Cycles through small, medium, and large swatch sizes")
                        .accessibilityValue(swatchSize.accessibilityName)
                    }
                }
                
                if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 2.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
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
                                        let newPalette = try colorManager.createPalette(name: "New Palette")
                                        prependPaletteToOrder(newPalette.id)
                                        createContentTip.invalidate(reason: .actionPerformed)
                                        OpaliteTipActions.advanceTipsAfterContentCreation()
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
                            }
                        })

                        Divider()

                        #if canImport(UIKit)
                        Button(action: {
                            HapticsManager.shared.selection()
                            isShowingPhotoColorPicker = true
                        }, label: {
                            Label {
                                Text("Sample from Photo")
                            } icon: {
                                Image(systemName: "eyedropper.halffull")
                            }
                        })
                        #endif

                        #if targetEnvironment(macCatalyst)
                        Button(action: {
                            HapticsManager.shared.selection()
                            sampleFromScreen()
                        }, label: {
                            Label {
                                Text("Sample from Screen")
                            } icon: {
                                Image(systemName: "macwindow.on.rectangle")
                            }
                        })
                        #endif

                        Button(action: {
                            HapticsManager.shared.selection()
                            isShowingQuickAddHex = true
                        }, label: {
                            Label {
                                Text("Quick Add Hex")
                            } icon: {
                                Image(systemName: "number")
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
                        let importedPalette = try colorManager.createPalette(existing: preview.palette)
                        prependPaletteToOrder(importedPalette.id)
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
                    hexCopyManager.copyHex(for: color)
                    copiedColorID = color.id
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }

                Button {
                    HapticsManager.shared.selection()
                    renameText = color.name ?? ""
                    colorToRename = color
                } label: {
                    Label("Rename Color", systemImage: "pencil")
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
                    colorToExport = color
                } label: {
                    Label("Export...", systemImage: "square.and.arrow.up")
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
                    colorToDelete = color
                } label: {
                    Label("Delete Color", systemImage: "trash.fill")
                }
            }
        )
    }

    // MARK: - Palette Order Helper

    /// Prepends a new palette ID to the saved order so it appears at the top.
    private func prependPaletteToOrder(_ paletteID: UUID) {
        var currentOrder: [UUID] = []
        if !paletteOrderData.isEmpty,
           let decoded = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) {
            currentOrder = decoded
        }

        // Remove if already exists (shouldn't happen for new palettes, but safe)
        currentOrder.removeAll { $0 == paletteID }

        // Prepend to front
        currentOrder.insert(paletteID, at: 0)

        // Save
        if let encoded = try? JSONEncoder().encode(currentOrder) {
            paletteOrderData = encoded
        }
    }

    // MARK: - Image Drop Handler

    #if canImport(UIKit)
    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: UIImage.self) }) else {
            return false
        }

        provider.loadObject(ofClass: UIImage.self) { image, error in
            Task { @MainActor in
                if let uiImage = image as? UIImage {
                    HapticsManager.shared.impact()
                    droppedImageItem = DroppedImageItem(image: uiImage)
                }
            }
        }

        return true
    }
    #endif

    // MARK: - System Color Sampler (Mac Catalyst)

    #if targetEnvironment(macCatalyst)
    private func sampleFromScreen() {
        SystemColorSampler.sample { uiColor in
            guard let uiColor else {
                // User cancelled or sampling failed
                return
            }

            // Extract RGB components
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            // Create and save the color
            let newColor = OpaliteColor(
                name: nil,
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                alpha: Double(alpha)
            )

            do {
                _ = try colorManager.createColor(existing: newColor)
                HapticsManager.shared.impact()
                toastManager.showSuccess("Color sampled from screen")
                OpaliteTipActions.advanceTipsAfterContentCreation()
            } catch {
                toastManager.show(error: .colorCreationFailed)
            }
        }
    }
    #endif
}

// MARK: - Identifiable wrapper for dropped images

#if canImport(UIKit)
private struct DroppedImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif

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
        .environment(QuickActionManager())
        .environment(HexCopyManager())
        .modelContainer(container)
}
