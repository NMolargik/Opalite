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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @Environment(ColorManager.self) private var colorManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(QuickActionManager.self) private var quickActionManager
    @Environment(HexCopyManager.self) private var hexCopyManager

    // MARK: - Intent Navigation
    private var intentNavigationManager = IntentNavigationManager.shared

    // MARK: - Tips
    private let createContentTip = CreateContentTip()
    private let dragAndDropTip = DragAndDropTip()
    private let colorDetailsTip = ColorDetailsTip()
    #if targetEnvironment(macCatalyst)
    private let screenSamplerTip = ScreenSamplerTip()
    #endif

    @State private var paletteSelectionColor: OpaliteColor?
    @State private var isShowingPaywall: Bool = false
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
#if os(iOS) && !targetEnvironment(macCatalyst)
    @State private var droppedImageItem: DroppedImageItem? = nil
#endif
    @State private var colorToDelete: OpaliteColor?
    @State private var isEditingColors: Bool = false
    @State private var selectedColorIDs: Set<UUID> = []
    @State private var colorsToDelete: [OpaliteColor] = []
    @State private var isShowingSwatchBarInfo = false
    @State private var isShowingQuickAddHex = false
    @State private var isShowingPaletteOrder = false
    @AppStorage(AppStorageKeys.paletteOrder) private var paletteOrderData: Data = Data()
    @State private var colorToRename: OpaliteColor?
    @State private var renameText: String = ""

    @Namespace private var namespace
    @Namespace private var swatchNS
    
    var isCompact: Bool { hSizeClass == .compact }

    /// Title for batch delete confirmation alert
    private var batchDeleteAlertTitle: String {
        let count = colorsToDelete.count
        return "Delete \(count) Color\(count == 1 ? "" : "s")?"
    }

    /// Whether all loose colors are selected
    private var allColorsSelected: Bool {
        selectedColorIDs.count == colorManager.looseColors.count
    }

    /// Palettes ordered according to user's custom order
    private var orderedPalettes: [OpalitePalette] {
        guard !paletteOrderData.isEmpty,
              let savedOrder = try? JSONDecoder().decode([UUID].self, from: paletteOrderData) else {
            return colorManager.palettes
        }

        // Remove duplicate palettes (keep most recently updated)
        var seenIDs: [UUID: OpalitePalette] = [:]
        for palette in colorManager.palettes {
            if let existing = seenIDs[palette.id] {
                let older = palette.updatedAt > existing.updatedAt ? existing : palette
                try? colorManager.deletePalette(older)
                seenIDs[palette.id] = palette.updatedAt > existing.updatedAt ? palette : existing
            } else {
                seenIDs[palette.id] = palette
            }
        }
        let paletteDict = seenIDs
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
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 20) {

                    // MARK: - Create Content Tip (shown first to new users)
                    TipView(createContentTip) { action in
                        // When user dismisses tip, enable the next tip
                        ColorDetailsTip.hasSeenCreateTip = true
                    }
                    .tipCornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    #if targetEnvironment(macCatalyst)
                    // MARK: - Screen Sampler Tip (Mac only)
                    TipView(screenSamplerTip)
                        .tipCornerRadius(16)
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
                        .tipCornerRadius(16)
                        .padding(.horizontal, 20)

                    // Edit mode toolbar
                    if isEditingColors {
                        editModeToolbar
                    }

                    SwatchRowView(
                        colors: colorManager.looseColors,
                        palette: pendingPaletteToAddTo,
                        swatchWidth: swatchSize.size,
                        swatchHeight: swatchSize.size,
                        showOverlays: looseColorShowOverlays,
                        showsNavigation: looseColorShowsNavigation,
                        onTap: looseColorOnTap,
                        menuContent: looseColorMenuContent,
                        contextMenuContent: looseColorContextMenuContent,
                        matchedNamespace: swatchNS,
                        selectedIDs: selectedColorIDs,
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
                                .background(.blue, in: RoundedRectangle(cornerRadius: 16))
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
                            .tipCornerRadius(16)
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
#if os(iOS) && !targetEnvironment(macCatalyst)
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
#if os(iOS) && !targetEnvironment(macCatalyst)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkForSharedImage()
                }
            }
            .onAppear {
                checkForSharedImage()
            }
#endif
            .refreshable {
                Task { await colorManager.refreshAll() }
            }
            .sheet(item: $paletteSelectionColor) { color in
                PaletteSelectionSheet(color: color)
                    .environment(colorManager)
            }
            .fullScreenCover(isPresented: showColorEditorBinding) {
                ColorEditorView(
                    color: nil,
                    palette: pendingPaletteToAddTo,
                    onCancel: {
                        pendingPaletteToAddTo = nil
                        isShowingColorEditor = false
                        intentNavigationManager.shouldShowColorEditor = false
                    },
                    onApprove: { newColor in
                        do {
                            _ = try colorManager.createColor(existing: newColor)
                            createContentTip.invalidate(reason: .actionPerformed)
                            OpaliteTipActions.advanceTipsAfterContentCreation()
                        } catch {
                            toastManager.show(error: .colorCreationFailed)
                        }

                        isShowingColorEditor = false
                        intentNavigationManager.shouldShowColorEditor = false
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
                batchDeleteAlertTitle,
                isPresented: Binding(
                    get: { !colorsToDelete.isEmpty },
                    set: { if !$0 { colorsToDelete = [] } }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    HapticsManager.shared.selection()
                    colorsToDelete = []
                }
                Button("Delete", role: .destructive) {
                    HapticsManager.shared.selection()
                    withAnimation {
                        for color in colorsToDelete {
                            try? colorManager.deleteColor(color)
                        }
                    }
                    colorsToDelete = []
                    selectedColorIDs.removeAll()
                    isEditingColors = false
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
#if os(iOS) && !targetEnvironment(macCatalyst)
            .fullScreenCover(isPresented: $isShowingPhotoColorPicker) {
                PhotoColorPickerSheet()
            }
            .fullScreenCover(item: $droppedImageItem) { item in
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
                // Edit/Done button for multi-select color deletion (show when 5+ colors)
                if colorManager.looseColors.count >= 5 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticsManager.shared.selection()
                            withAnimation {
                                isEditingColors.toggle()
                                if !isEditingColors {
                                    selectedColorIDs.removeAll()
                                }
                            }
                        } label: {
                            Image(systemName: isEditingColors ? "checkmark" : "pencil")
                        }
                        .toolbarButtonTint()
                    }
                }

                if isIPadOrMac {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticsManager.shared.selection()
                            isShowingSwatchBarInfo = true
                        } label: {
                            Label("SwatchBar", systemImage: "square.stack")
                        }
                        .toolbarButtonTint()
                    }
                }
                
                if colorManager.palettes.count >= 3 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticsManager.shared.selection()
                            isShowingPaletteOrder = true
                        } label: {
                            Label("Reorder Palettes", systemImage: "arrow.up.arrow.down")
                        }
                        .toolbarButtonTint()
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
                        .toolbarButtonTint()
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

#if os(iOS) && !targetEnvironment(macCatalyst)
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
            .toolbarRole(isCompact ? .automatic : .editor)
            .navigationDestination(for: PortfolioNavigationNode.self) { node in
                switch node {
                case .color(let color):
                    ColorDetailView(color: color)
                        .tint(.none)
                case .palette(let palette):
                    PaletteDetailView(palette: palette)
                        .tint(.none)
                }
            }
            .onChange(of: intentNavigationManager.pendingColorID) { _, colorID in
                guard let colorID else { return }
                // Find the color and navigate to it
                if let color = colorManager.colors.first(where: { $0.id == colorID }) {
                    navigationPath = [.color(color)]
                    intentNavigationManager.clearNavigation()
                }
            }
            .onChange(of: intentNavigationManager.pendingPaletteID) { _, paletteID in
                guard let paletteID else { return }
                // Find the palette and navigate to it
                if let palette = colorManager.palettes.first(where: { $0.id == paletteID }) {
                    navigationPath = [.palette(palette)]
                    intentNavigationManager.clearNavigation()
                }
            }
        }
    }

    /// Binding that shows the color editor (from user action OR deep link)
    private var showColorEditorBinding: Binding<Bool> {
        Binding(
            get: {
                // Check both local state and intent navigation trigger
                if intentNavigationManager.shouldShowColorEditor {
                    return true
                }
                return isShowingColorEditor
            },
            set: { newValue in
                isShowingColorEditor = newValue
                // Clear the intent trigger when dismissing
                if !newValue {
                    intentNavigationManager.shouldShowColorEditor = false
                }
            }
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

    // MARK: - Edit Mode Helpers

    /// Whether to show overlays on loose colors (hide when editing)
    private var looseColorShowOverlays: Bool {
        swatchSize.showOverlays && !isEditingColors
    }

    /// Whether loose colors should show navigation (disable when editing)
    private var looseColorShowsNavigation: Bool {
        !isEditingColors
    }

    /// Handler for tapping a color swatch in edit mode (nil when not editing)
    private var looseColorOnTap: ((OpaliteColor) -> Void)? {
        guard isEditingColors else { return nil }
        return { [self] color in
            HapticsManager.shared.selection()
            if selectedColorIDs.contains(color.id) {
                selectedColorIDs.remove(color.id)
            } else {
                selectedColorIDs.insert(color.id)
            }
        }
    }

    /// Menu content for loose colors (respects edit mode)
    private func looseColorMenuContent(_ color: OpaliteColor) -> AnyView {
        if swatchSize.showOverlays && !isEditingColors {
            return menuContent(color: color)
        } else {
            return AnyView(EmptyView())
        }
    }

    /// Context menu content for loose colors (respects edit mode)
    private func looseColorContextMenuContent(_ color: OpaliteColor) -> AnyView {
        if !isEditingColors {
            return menuContent(color: color)
        } else {
            return AnyView(EmptyView())
        }
    }

    // MARK: - Edit Mode Toolbar

    @ViewBuilder
    private var editModeToolbar: some View {
        HStack {
            Button(allColorsSelected ? "Deselect All" : "Select All") {
                HapticsManager.shared.selection()
                if allColorsSelected {
                    selectedColorIDs.removeAll()
                } else {
                    selectedColorIDs = Set(colorManager.looseColors.map(\.id))
                }
            }

            Spacer()

            Button(role: .destructive) {
                HapticsManager.shared.notification(.warning)
                colorsToDelete = colorManager.looseColors.filter { selectedColorIDs.contains($0.id) }
            } label: {
                Label("Delete (\(selectedColorIDs.count))", systemImage: "trash")
            }
            .disabled(selectedColorIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .font(.subheadline)
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
                        Label("Move To Palette", systemImage: "swatchpalette.fill")
                    }
                }

                Divider()

                Button {
                    HapticsManager.shared.selection()
                    colorToExport = color
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Divider()
                
                if let _ = palette {
                    Button(role: .destructive) {
                        HapticsManager.shared.selection()
                        withAnimation {
                            colorManager.detachColorFromPalette(color)
                        }
                    } label: {
                        Label("Remove From Palette", systemImage: "minus.circle")
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

#if os(iOS) && !targetEnvironment(macCatalyst)
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

    /// Checks for a shared image from the Share Extension and opens the photo picker if found.
    private func checkForSharedImage() {
        guard SharedImageManager.shared.hasSharedImage(),
              let image = SharedImageManager.shared.loadSharedImage() else {
            return
        }

        // Clear the shared image so we don't re-open it
        SharedImageManager.shared.clearSharedImage()

        // Open the photo color picker with the shared image
        HapticsManager.shared.impact()
        droppedImageItem = DroppedImageItem(image: image)
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

#if os(iOS) && !targetEnvironment(macCatalyst)
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

