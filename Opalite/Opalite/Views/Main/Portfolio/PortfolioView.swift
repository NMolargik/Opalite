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
    @Environment(ReviewRequestManager.self) private var reviewRequestManager
    @Environment(ImportCoordinator.self) private var importCoordinator

    // MARK: - ViewModel
    @State private var viewModel = ViewModel()

    // MARK: - Intent Navigation
    private var intentNavigationManager = IntentNavigationManager.shared

    // MARK: - Tips
    private let createContentTip = CreateContentTip()
    private let dragAndDropTip = DragAndDropTip()
    private let colorDetailsTip = ColorDetailsTip()
    #if targetEnvironment(macCatalyst)
    private let screenSamplerTip = ScreenSamplerTip()
    #endif

    // MARK: - Persisted State
    @AppStorage(AppStorageKeys.swatchSize) private var swatchSizeRaw: String = SwatchSize.medium.rawValue
    @AppStorage(AppStorageKeys.paletteOrder) private var paletteOrderData: Data = Data()

    @Namespace private var namespace
    @Namespace private var swatchNS

    // MARK: - Computed Properties

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

    private var orderedPalettes: [OpalitePalette] {
        viewModel.orderedPalettes(
            palettes: colorManager.palettes,
            paletteOrderData: paletteOrderData,
            colorManager: colorManager
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            mainScrollContent
                .navigationTitle("Opalite")
                .toolbarBackground(.hidden)
                .toolbar { toolbarContent }
                .toolbarRole(isCompact ? .automatic : .editor)
                .navigationDestination(for: PortfolioNavigationNode.self) { node in
                    destinationView(for: node)
                }
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: viewModel.swatchSize) { _, newValue in
            swatchSizeRaw = newValue.rawValue
        }
        .onChange(of: hSizeClass) { _, newValue in
            handleSizeClassChange(newValue)
        }
        .onChange(of: quickActionManager.newColorTrigger) { _, newValue in
            handleQuickActionTrigger(newValue)
        }
        .onChange(of: intentNavigationManager.pendingColorID) { _, colorID in
            handlePendingColorNavigation(colorID)
        }
        .onChange(of: intentNavigationManager.pendingPaletteID) { _, paletteID in
            handlePendingPaletteNavigation(paletteID)
        }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.checkForSharedImage()
            }
        }
        .onAppear {
            viewModel.checkForSharedImage()
        }
        #endif
        .sheet(item: $viewModel.paletteSelectionColor) { color in
            PaletteSelectionSheet(color: color)
                .environment(colorManager)
        }
        .sheet(isPresented: $viewModel.isShowingBatchPaletteSelection) {
            batchPaletteSelectionSheet
        }
        .fullScreenCover(isPresented: showColorEditorBinding) {
            colorEditorCover
        }
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: [.opaliteColor, .opalitePalette],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importCoordinator.handleIncomingURL(url, colorManager: colorManager)
            case .failure(let error):
                viewModel.importError = error.localizedDescription
                viewModel.isShowingImportError = true
            }
        }
        .alert("Import Error", isPresented: $viewModel.isShowingImportError) {
            Button("OK", role: .cancel) { HapticsManager.shared.selection() }
        } message: {
            Text(viewModel.importError ?? "An unknown error occurred.")
        }
        .alert(
            "Delete \(viewModel.colorToDelete?.name ?? viewModel.colorToDelete?.hexString ?? "Color")?",
            isPresented: deleteColorAlertBinding
        ) {
            deleteColorAlertActions
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(viewModel.batchDeleteAlertTitle, isPresented: batchDeleteAlertBinding) {
            batchDeleteAlertActions
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Rename Color", isPresented: renameColorAlertBinding) {
            renameColorAlertContent
        } message: {
            Text("Enter a new name for this color.")
        }
        .sheet(isPresented: $viewModel.isShowingPaywall) {
            PaywallView(featureContext: "This feature requires Onyx")
        }
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .fullScreenCover(isPresented: $viewModel.isShowingPhotoColorPicker) {
            PhotoColorPickerSheet()
        }
        .fullScreenCover(item: $viewModel.droppedImageItem) { item in
            PhotoColorPickerSheet(initialImage: item.image)
        }
        #endif
        .sheet(item: $viewModel.colorToExport) { color in
            ColorExportSheet(color: color)
        }
        .sheet(isPresented: $viewModel.isShowingSwatchBarInfo) {
            SwatchBarInfoSheet()
        }
        .sheet(isPresented: $viewModel.isShowingQuickAddHex) {
            QuickAddHexSheet()
        }
        .sheet(isPresented: $viewModel.isShowingPaletteOrder) {
            PaletteOrderSheet(isForExport: false)
        }
    }
}

// MARK: - Main Content

private extension PortfolioView {
    var mainScrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: isCompact ? 16 : 20) {
                tipsSection
                colorsSection
                palettesSection
            }
        }
        .padding(.bottom)
        .scrollClipDisabled()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        .onDrop(of: [.image], isTargeted: nil) { providers in
            viewModel.handleImageDrop(providers: providers)
        }
        #endif
        .background {
            Button("") {
                viewModel.sampleFromScreen(colorManager: colorManager, toastManager: toastManager)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .hidden()
        }
        .refreshable {
            Task { await colorManager.refreshAll() }
        }
    }

    @ViewBuilder
    var tipsSection: some View {
        TipView(createContentTip) { _ in
            ColorDetailsTip.hasSeenCreateTip = true
        }
        .tipCornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.top, 8)

        #if targetEnvironment(macCatalyst)
        TipView(screenSamplerTip)
            .tipCornerRadius(16)
            .padding(.horizontal, 20)
        #endif
    }

    var colorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ColorRowHeaderView(
                isEditingColors: $viewModel.isEditingColors,
                selectedColorIDs: $viewModel.selectedColorIDs
            )

            TipView(colorDetailsTip)
                .tipCornerRadius(16)
                .padding(.horizontal, 20)

            if viewModel.isEditingColors {
                editModeToolbar
            }

            looseColorsRow
                .zIndex(1)
                .padding(.bottom, 5)
        }
    }

    var looseColorsRow: some View {
        SwatchRowView(
            colors: colorManager.looseColors,
            palette: viewModel.pendingPaletteToAddTo,
            swatchWidth: viewModel.swatchSize.size,
            swatchHeight: viewModel.swatchSize.size,
            swatchCornerRadius: viewModel.swatchSize.cornerRadius,
            showOverlays: viewModel.looseColorShowOverlays(swatchShowsOverlays: viewModel.swatchSize.showOverlays),
            showsNavigation: viewModel.looseColorShowsNavigation,
            onTap: viewModel.isEditingColors ? { color in viewModel.handleColorTap(color) } : nil,
            menuContent: { color in looseColorMenuContent(color) },
            contextMenuContent: { color in looseColorContextMenuContent(color) },
            matchedNamespace: swatchNS,
            selectedIDs: viewModel.selectedColorIDs,
            copiedColorID: $viewModel.copiedColorID
        )
    }

    var palettesSection: some View {
        VStack(alignment: .leading) {
            palettesSectionHeader

            if colorManager.palettes.isEmpty {
                emptyPalettesPrompt
            } else {
                palettesContent
            }
        }
    }

    var palettesSectionHeader: some View {
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
    }

    var emptyPalettesPrompt: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .bold()
                .accessibilityHidden(true)

            Button {
                viewModel.createNewPalette(
                    colorManager: colorManager,
                    subscriptionManager: subscriptionManager,
                    toastManager: toastManager,
                    paletteOrderData: &paletteOrderData
                )
                createContentTip.invalidate(reason: .actionPerformed)
                ColorDetailsTip.hasSeenCreateTip = true
                DragAndDropTip.hasCreatedPalette = true
                PaletteMenuTip.hasCreatedPalette = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "swatchpalette")
                        .font(.title2)

                    Text("Create A Palette")
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
            .buttonStyle(.plain)
            .accessibilityLabel("Create A Palette")
            .accessibilityHint("Creates a new empty palette to organize your colors")

            Spacer()
        }
        .padding(.leading, 35)
    }

    var palettesContent: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            TipView(dragAndDropTip)
                .tipCornerRadius(16)
                .padding(.horizontal, 20)

            ForEach(Array(orderedPalettes.enumerated()), id: \.element.id) { index, palette in
                paletteRow(for: palette, isFirst: index == 0)
            }
        }
    }

    func paletteRow(for palette: OpalitePalette, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            PaletteRowHeaderView(palette: palette, showTip: isFirst)
                .zIndex(0)

            SwatchRowView(
                colors: palette.sortedColors,
                palette: palette,
                swatchWidth: viewModel.swatchSize.size,
                swatchHeight: viewModel.swatchSize.size,
                swatchCornerRadius: viewModel.swatchSize.cornerRadius,
                showOverlays: viewModel.swatchSize.showOverlays,
                menuContent: { color in
                    if viewModel.swatchSize.showOverlays {
                        return menuContent(color: color, palette: palette)
                    } else {
                        return AnyView(EmptyView())
                    }
                },
                contextMenuContent: { color in
                    return menuContent(color: color, palette: palette)
                },
                matchedNamespace: swatchNS,
                copiedColorID: $viewModel.copiedColorID
            )
            .zIndex(1)
        }
    }
}

// MARK: - Edit Mode Toolbar

private extension PortfolioView {
    var editModeToolbar: some View {
        HStack {
            Button(viewModel.allColorsSelected(looseColorCount: colorManager.looseColors.count) ? "Deselect All" : "Select All") {
                viewModel.selectAllColors(looseColors: colorManager.looseColors)
            }
            .tint(.blue)

            Spacer()

            Button {
                HapticsManager.shared.selection()
                viewModel.isShowingBatchPaletteSelection = true
            } label: {
                Label("Move To Palette", systemImage: "swatchpalette")
            }
            .tint(.blue)
            .disabled(viewModel.selectedColorIDs.isEmpty)

            Button(role: .destructive) {
                viewModel.confirmBatchDelete(looseColors: colorManager.looseColors)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(viewModel.selectedColorIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .font(.subheadline)
    }
}

// MARK: - Menu Content

private extension PortfolioView {
    func looseColorMenuContent(_ color: OpaliteColor) -> AnyView {
        if viewModel.swatchSize.showOverlays && !viewModel.isEditingColors {
            return menuContent(color: color)
        } else {
            return AnyView(EmptyView())
        }
    }

    func looseColorContextMenuContent(_ color: OpaliteColor) -> AnyView {
        if !viewModel.isEditingColors {
            return menuContent(color: color)
        } else {
            return AnyView(EmptyView())
        }
    }

    func menuContent(color: OpaliteColor, palette: OpalitePalette? = nil) -> AnyView {
        AnyView(
            Group {
                Button {
                    HapticsManager.shared.selection()
                    hexCopyManager.copyHex(for: color)
                    viewModel.copiedColorID = color.id
                } label: {
                    Label("Copy Hex", systemImage: "number")
                }

                Button {
                    HapticsManager.shared.selection()
                    viewModel.renameText = color.name ?? ""
                    viewModel.colorToRename = color
                } label: {
                    Label("Rename Color", systemImage: "pencil")
                }

                if palette == nil {
                    Button {
                        HapticsManager.shared.selection()
                        viewModel.paletteSelectionColor = color
                    } label: {
                        Label("Move To Palette", systemImage: "swatchpalette.fill")
                    }
                }

                Divider()

                Button {
                    HapticsManager.shared.selection()
                    viewModel.colorToExport = color
                } label: {
                    Label("Share Color", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)

                Divider()

                if palette != nil {
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
                    viewModel.colorToDelete = color
                } label: {
                    Label("Delete Color", systemImage: "trash.fill")
                }
            }
        )
    }
}

// MARK: - Toolbar

private extension PortfolioView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        if isIPadOrMac {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    viewModel.isShowingSwatchBarInfo = true
                } label: {
                    Label("SwatchBar", systemImage: "square.stack")
                }
                .toolbarButtonTint()
            }
            
            #if !os(visionOS)
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            #endif
        }

        if !colorManager.colors.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    HapticsManager.shared.selection()
                    withAnimation(.bouncy) {
                        viewModel.swatchSize = isCompact ? viewModel.swatchSize.nextCompact : viewModel.swatchSize.next
                    }
                }) {
                    Image(systemName: viewModel.nextSwatchSizeWillIncrease(isCompact: isCompact)
                          ? "arrow.down.left.and.arrow.up.right.square"
                          : "arrow.up.right.and.arrow.down.left.square")
                }
                .toolbarButtonTint()
                .accessibilityLabel("Change swatch size")
                .accessibilityHint(isCompact ? "Cycles between small and medium swatch sizes" : "Cycles through small, medium, and large swatch sizes")
                .accessibilityValue(viewModel.swatchSize.accessibilityName)
            }
        }
        
        if colorManager.palettes.count >= 3 {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticsManager.shared.selection()
                    viewModel.isShowingPaletteOrder = true
                } label: {
                    Label("Reorder Palettes", systemImage: "arrow.up.arrow.down")
                }
                .toolbarButtonTint()
                .accessibilityLabel("Reorder palettes")
                .accessibilityHint("Opens a sheet to reorder your palettes")
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            createMenu
        }
    }

    var createMenu: some View {
        Menu {
            Button(action: {
                HapticsManager.shared.selection()
                viewModel.isShowingColorEditor.toggle()
            }, label: {
                Label {
                    Text("Create A Color")
                } icon: {
                    Image(systemName: "paintpalette.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.blue)
                }
            })

            Button(action: {
                viewModel.createNewPalette(
                    colorManager: colorManager,
                    subscriptionManager: subscriptionManager,
                    toastManager: toastManager,
                    paletteOrderData: &paletteOrderData
                )
                createContentTip.invalidate(reason: .actionPerformed)
                OpaliteTipActions.advanceTipsAfterContentCreation()
            }, label: {
                Label {
                    HStack {
                        Text("Create A Palette")
                        if !subscriptionManager.canCreatePalette(currentCount: colorManager.palettes.count) {
                            Image(systemName: "lock.fill")
                                .font(.footnote)
                        }
                    }
                } icon: {
                    Image(systemName: "swatchpalette.fill")
                }
                .tint(.orange)

            })

            Divider()

            #if os(iOS) && !targetEnvironment(macCatalyst)
            Button(action: {
                HapticsManager.shared.selection()
                viewModel.isShowingPhotoColorPicker = true
            }, label: {
                Label {
                    Text("Sample Photo")
                } icon: {
                    Image(systemName: "eyedropper.halffull")
                }
                .tint(.cyan)
            })
            #endif

            #if targetEnvironment(macCatalyst)
            Button(action: {
                HapticsManager.shared.selection()
                viewModel.sampleFromScreen(colorManager: colorManager, toastManager: toastManager)
            }, label: {
                Label {
                    Text("Sample from Screen")
                } icon: {
                    Image(systemName: "macwindow.on.rectangle")
                }
                .tint(.white)
            })
            #endif

            Button(action: {
                HapticsManager.shared.selection()
                viewModel.isShowingQuickAddHex = true
            }, label: {
                Label {
                    Text("Add By Hex")
                } icon: {
                    Image(systemName: "number")
                }
                .tint(.red)
            })

            Divider()

            Button(action: {
                HapticsManager.shared.selection()
                if subscriptionManager.hasOnyxEntitlement {
                    viewModel.isShowingFileImporter = true
                } else {
                    viewModel.isShowingPaywall = true
                }
            }, label: {
                Label {
                    HStack {
                        Text("Import")
                        if !subscriptionManager.hasOnyxEntitlement {
                            Image(systemName: "lock.fill")
                                .font(.footnote)
                        }
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
                .tint(.indigo)
            })
        } label: {
            Label("Create", systemImage: "plus")
                .imageScale(.large)
                .bold()
        }
        .tint(.blue)
        .labelStyle(.titleAndIcon)
    }
}

// MARK: - Sheets & Covers

private extension PortfolioView {
    var batchPaletteSelectionSheet: some View {
        PaletteSelectionSheet(colors: colorManager.looseColors.filter { viewModel.selectedColorIDs.contains($0.id) })
            .environment(colorManager)
            .onDisappear {
                viewModel.selectedColorIDs.removeAll()
                viewModel.isEditingColors = false
            }
    }

    var colorEditorCover: some View {
        ColorEditorView(
            color: nil,
            palette: viewModel.pendingPaletteToAddTo,
            onCancel: {
                viewModel.pendingPaletteToAddTo = nil
                viewModel.isShowingColorEditor = false
                intentNavigationManager.shouldShowColorEditor = false
            },
            onApprove: { newColor in
                do {
                    _ = try colorManager.createColor(existing: newColor)
                    createContentTip.invalidate(reason: .actionPerformed)
                    OpaliteTipActions.advanceTipsAfterContentCreation()
                    reviewRequestManager.evaluateReviewRequest(
                        colorCount: colorManager.colors.count,
                        paletteCount: colorManager.palettes.count
                    )
                } catch {
                    toastManager.show(error: .colorCreationFailed)
                }

                viewModel.isShowingColorEditor = false
                intentNavigationManager.shouldShowColorEditor = false
            }
        )
    }
}

// MARK: - Bindings

private extension PortfolioView {
    var showColorEditorBinding: Binding<Bool> {
        Binding(
            get: {
                if intentNavigationManager.shouldShowColorEditor {
                    return true
                }
                return viewModel.isShowingColorEditor
            },
            set: { newValue in
                viewModel.isShowingColorEditor = newValue
                if !newValue {
                    intentNavigationManager.shouldShowColorEditor = false
                }
            }
        )
    }

    var deleteColorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.colorToDelete != nil },
            set: { if !$0 { viewModel.colorToDelete = nil } }
        )
    }

    var batchDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { !viewModel.colorsToDelete.isEmpty },
            set: { if !$0 { viewModel.colorsToDelete = [] } }
        )
    }

    var renameColorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.colorToRename != nil },
            set: { if !$0 { viewModel.colorToRename = nil } }
        )
    }
}

// MARK: - Alert Content

private extension PortfolioView {
    @ViewBuilder
    var deleteColorAlertActions: some View {
        Button("Cancel", role: .cancel) {
            HapticsManager.shared.selection()
            viewModel.colorToDelete = nil
        }
        Button("Delete", role: .destructive) {
            if let color = viewModel.colorToDelete {
                viewModel.deleteColor(color, colorManager: colorManager, toastManager: toastManager)
            }
        }
    }

    @ViewBuilder
    var batchDeleteAlertActions: some View {
        Button("Cancel", role: .cancel) {
            HapticsManager.shared.selection()
            viewModel.colorsToDelete = []
        }
        Button("Delete", role: .destructive) {
            viewModel.executeBatchDelete(colorManager: colorManager)
        }
    }

    @ViewBuilder
    var renameColorAlertContent: some View {
        TextField("Color name", text: $viewModel.renameText)
        Button("Cancel", role: .cancel) {
            HapticsManager.shared.selection()
            viewModel.colorToRename = nil
            viewModel.renameText = ""
        }
        Button("Save") {
            viewModel.renameColor(colorManager: colorManager, toastManager: toastManager)
        }
    }
}

// MARK: - Navigation

private extension PortfolioView {
    @ViewBuilder
    func destinationView(for node: PortfolioNavigationNode) -> some View {
        switch node {
        case .color(let color):
            ColorDetailView(color: color)
                .tint(.none)
        case .palette(let palette):
            PaletteDetailView(palette: palette)
                .tint(.none)
        }
    }
}

// MARK: - Event Handlers

private extension PortfolioView {
    func handleOnAppear() {
        if let stored = SwatchSize(rawValue: swatchSizeRaw) {
            viewModel.swatchSize = stored
        }
    }

    func handleSizeClassChange(_ newValue: UserInterfaceSizeClass?) {
        if newValue == .compact && viewModel.swatchSize == .large {
            withAnimation(.bouncy) {
                viewModel.swatchSize = .medium
            }
        }
    }

    func handleQuickActionTrigger(_ newValue: UUID?) {
        guard let token = newValue else { return }
        viewModel.quickActionTrigger = token
        viewModel.pendingPaletteToAddTo = nil
        viewModel.isShowingColorEditor = true
    }

    func handlePendingColorNavigation(_ colorID: UUID?) {
        guard let colorID else { return }
        if let color = colorManager.colors.first(where: { $0.id == colorID }) {
            viewModel.navigationPath = [.color(color)]
            intentNavigationManager.clearNavigation()
        }
    }

    func handlePendingPaletteNavigation(_ paletteID: UUID?) {
        guard let paletteID else { return }
        if let palette = colorManager.palettes.first(where: { $0.id == paletteID }) {
            viewModel.navigationPath = [.palette(palette)]
            intentNavigationManager.clearNavigation()
        }
    }
}

// MARK: - Preview

#Preview("Portfolio") {
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
        .environment(ReviewRequestManager())
        .environment(QuickActionManager())
        .environment(HexCopyManager())
        .environment(ImportCoordinator())
        .modelContainer(container)
}
