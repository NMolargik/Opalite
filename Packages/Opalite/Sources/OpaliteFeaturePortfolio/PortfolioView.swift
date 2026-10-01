//
//  PortfolioView.swift
//  OpaliteFeaturePortfolio
//
//  The Portfolio tab's root content: a large "Opalite" title with a count subtitle, the
//  loose colors row, and a section per palette (two columns on wide windows), each a
//  drop target. The toolbar carries the swatch-size toggle, an overflow menu (reorder,
//  archived, SwatchBar) and the + menu that creates content. The shell owns the
//  NavigationStack and the `PortfolioDestination` registration; taps on swatches route
//  through `AppRouter` so the shell pushes the detail.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import UniformTypeIdentifiers
import TipKit
import OpaliteCore
import OpaliteDesignSystem
import OpaliteServices
import OpaliteFeatureShared
import OpaliteFeatureColorEditor
import OpaliteFeatureSharing
import os

public struct PortfolioView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ToastManager.self) private var toasts

    public init() {}

    public var body: some View {
        PortfolioScreen(portfolio: portfolio, toasts: toasts)
    }
}

// MARK: - Screen

struct PortfolioScreen: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(AppRouter.self) private var router
    @Environment(ToastManager.self) private var toasts
    @Environment(ImportModel.self) private var importer
    @Environment(\.onyxEntitlement) private var entitlement
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(AppStorageKeys.swatchSize) private var swatchSizeRaw: String = SwatchSize.medium.rawValue

    @State private var model: PortfolioViewModel
    @State private var containerWidth: CGFloat = 0
    @State private var droppedImage: DroppedImage?
    @Namespace private var swatchNamespace

    private let createContentTip = CreateContentTip()
    private let colorDetailsTip = ColorDetailsTip()
    private let dragAndDropTip = DragAndDropTip()
    #if targetEnvironment(macCatalyst)
    private let screenSamplerTip = ScreenSamplerTip()
    #endif

    init(portfolio: PortfolioModel, toasts: ToastManager) {
        _model = State(initialValue: PortfolioViewModel(portfolio: portfolio, toasts: toasts))
    }

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var swatchSize: SwatchSize { SwatchSize(rawValue: swatchSizeRaw) ?? .medium }

    private var paletteColumns: Int {
        PortfolioLayout.paletteColumns(width: containerWidth, isRegularWidth: !isCompact, paletteCount: portfolio.orderedPalettes.count)
    }

    var body: some View {
        Group {
            if model.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .navigationTitle("Opalite")
        .navigationSubtitleIfAvailable(model.subtitle ?? "")
        .toolbar { toolbar }
        .toolbarRole(isCompact ? .automatic : .editor)
        .onChange(of: portfolio.changeStamp) { model.pruneSelection() }
        .modifier(PortfolioPresentations(model: model, droppedImage: $droppedImage))
        .background {
            #if targetEnvironment(macCatalyst)
            Button("Sample from Screen") { sampleFromScreen() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .hidden()
            #endif
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Brand.Space.xl) {
                tips
                LooseColorsSection(model: model, swatchSize: swatchSize, namespace: swatchNamespace)
                palettes
            }
            .padding(.vertical, Brand.Space.lg)
        }
        .scrollClipDisabled()
        .softScrollEdgesIfAvailable()
        .modifier(ImageDropTarget(droppedImage: $droppedImage))
    }

    @ContentBuilder
    private var tips: some View {
        TipView(createContentTip) { _ in ColorDetailsTip.hasSeenCreateTip = true }
            .tipCornerRadius(Brand.Radius.card)
            .padding(.horizontal, Brand.Space.lg)
        TipView(colorDetailsTip)
            .tipCornerRadius(Brand.Radius.card)
            .padding(.horizontal, Brand.Space.lg)
        #if targetEnvironment(macCatalyst)
        TipView(screenSamplerTip)
            .tipCornerRadius(Brand.Radius.card)
            .padding(.horizontal, Brand.Space.lg)
        #endif
    }

    @ContentBuilder
    private var palettes: some View {
        let ordered = portfolio.orderedPalettes
        if ordered.isEmpty {
            emptyPalettesPrompt
        } else {
            TipView(dragAndDropTip)
                .tipCornerRadius(Brand.Radius.card)
                .padding(.horizontal, Brand.Space.lg)

            if paletteColumns > 1 {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: PortfolioLayout.paletteCardMinimumWidth), spacing: Brand.Space.lg, alignment: .top)],
                    alignment: .leading,
                    spacing: Brand.Space.lg
                ) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, palette in
                        PaletteSection(palette: palette, model: model, swatchSize: swatchSize, namespace: swatchNamespace, showsTip: index == 0, asCard: true)
                    }
                }
                .padding(.horizontal, Brand.Space.lg)
            } else {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, palette in
                    PaletteSection(palette: palette, model: model, swatchSize: swatchSize, namespace: swatchNamespace, showsTip: index == 0, asCard: false)
                }
            }
        }
    }

    private var emptyPalettesPrompt: some View {
        HStack(spacing: Brand.Space.md) {
            Image(systemName: "arrow.turn.down.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Button {
                Haptics.selection()
                model.beginNamingNewPalette()
            } label: {
                Label("Create a Palette", systemImage: "swatchpalette")
                    .font(.subheadline.weight(.semibold))
            }
            .glassActionButton(tint: .opaliteBlue, prominent: false)
            .hoverHighlight()
            .accessibilityIdentifier("portfolio.createPalette")
            .accessibilityHint(Text("Creates an empty palette to organize your colors"))
            Spacer(minLength: 0)
        }
        .padding(.leading, Brand.Space.xxl)
        .padding(.horizontal, Brand.Space.lg)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Brand.Space.lg) {
            TipView(createContentTip) { _ in ColorDetailsTip.hasSeenCreateTip = true }
                .tipCornerRadius(Brand.Radius.card)
                .frame(maxWidth: Brand.readableWidth)
            EmptyStateView(
                "Your Portfolio Is Empty",
                systemImage: "paintpalette",
                description: String(localized: "Colors you create, sample, or import live here. Group them into palettes when you're ready.")
            ) {
                Button {
                    Haptics.selection()
                    model.requestEditor()
                } label: {
                    Label("Create a Color", systemImage: "plus")
                }
                .primaryActionButton()
                .accessibilityIdentifier("portfolio.createColor")
            }
        }
        .padding(Brand.Space.lg)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.selection()
                withAnimation(reduceMotion ? nil : .snappy) {
                    swatchSizeRaw = PortfolioLayout.nextSwatchSize(after: swatchSize, isCompactWidth: isCompact).rawValue
                }
            } label: {
                Label("Swatch Size", systemImage: PortfolioLayout.nextSwatchSizeGrows(after: swatchSize, isCompactWidth: isCompact) ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
            }
            .toolbarButtonTint()
            .disabled(model.isEmpty)
            .accessibilityIdentifier("portfolio.swatchSize")
            .accessibilityValue(Text(swatchSize.accessibilityName))
            .accessibilityHint(Text("Cycles the size of the swatches"))
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Haptics.selection()
                    model.activeSheet = .paletteOrder
                } label: {
                    Label("Reorder Palettes…", systemImage: "arrow.up.arrow.down")
                }
                .disabled(portfolio.activePalettes.count < 2)

                Button {
                    Haptics.selection()
                    model.activeSheet = .archivedPalettes
                } label: {
                    Label("Archived Palettes…", systemImage: "archivebox")
                }
                .disabled(portfolio.archivedPalettes.isEmpty)

                if !isCompact {
                    Divider()
                    Button {
                        Haptics.selection()
                        router.present(.swatchBarInfo)
                    } label: {
                        Label("SwatchBar…", systemImage: "square.stack")
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
            .toolbarButtonTint()
            .accessibilityIdentifier("portfolio.more")
        }

        ToolbarSpacerIfAvailable(.fixed, placement: .topBarTrailing)

        ToolbarItem(placement: .primaryAction) {
            createMenu
        }
    }

    private var createMenu: some View {
        Menu {
            Button {
                Haptics.selection()
                model.requestEditor()
            } label: {
                Label("New Color", systemImage: "paintpalette.fill")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button {
                Haptics.selection()
                model.beginNamingNewPalette()
            } label: {
                Label("New Palette", systemImage: "swatchpalette.fill")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button {
                Haptics.selection()
                model.activeSheet = .quickAddHex
            } label: {
                Label("Add by Hex…", systemImage: "number")
            }

            #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS)
            Button {
                Haptics.selection()
                model.isShowingPhotoSampler = true
            } label: {
                Label("Sample Photo…", systemImage: "eyedropper.halffull")
            }
            #endif

            #if targetEnvironment(macCatalyst)
            Button {
                Haptics.selection()
                sampleFromScreen()
            } label: {
                Label("Sample from Screen", systemImage: "macwindow.on.rectangle")
            }
            #endif

            Divider()

            Button {
                Haptics.selection()
                if entitlement.hasOnyx {
                    model.isShowingFileImporter = true
                } else {
                    router.requestPaywall(context: String(localized: "Importing files requires Onyx"))
                }
            } label: {
                Label {
                    Text("Import File…")
                } icon: {
                    Image(systemName: entitlement.hasOnyx ? "square.and.arrow.down" : "lock.fill")
                }
            }
        } label: {
            Label("Create", systemImage: "plus")
        }
        .accessibilityIdentifier("portfolio.createMenu")
        .accessibilityHint(Text("Creates a color or palette, or imports a file"))
    }

    // MARK: - Screen sampling

    #if targetEnvironment(macCatalyst)
    private func sampleFromScreen() {
        Task {
            guard let rgba = await SystemColorSampler.sample() else { return }
            model.saveSampledColor(rgba, source: String(localized: "screen"))
        }
    }
    #endif
}

// MARK: - Presentations

/// Every sheet, cover, alert, and dialog the root presents, kept out of the body.
private struct PortfolioPresentations: ViewModifier {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(ImportModel.self) private var importer
    @Bindable var model: PortfolioViewModel
    @Binding var droppedImage: DroppedImage?

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.activeSheet) { sheet in
                switch sheet {
                case .quickAddHex:
                    QuickAddHexSheet { model.saveQuickAdd($0) }
                case .paletteOrder:
                    PaletteOrderSheet()
                case .archivedPalettes:
                    ArchivedPalettesSheet()
                case .moveColor(let id):
                    if let color = portfolio.color(withID: id) {
                        PaletteSelectionSheet(colors: [color])
                    }
                case .moveSelection:
                    PaletteSelectionSheet(colors: model.selectedLooseColors) { model.selection.end() }
                case .exportColor(let id):
                    if let color = portfolio.color(withID: id) { ColorExportSheet(color: color) }
                case .publishColor(let id):
                    if let color = portfolio.color(withID: id) { PublishColorSheet(color: color) }
                }
            }
            .fullScreenCover(item: $model.editorRequest) { request in
                ColorEditorView(
                    mode: .create(palette: request.paletteID.flatMap { portfolio.palette(withID: $0) }, initial: request.initial),
                    onCancel: { model.editorRequest = nil },
                    onSave: { model.saveEditorResult($0) }
                )
            }
            #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS)
            .fullScreenCover(isPresented: $model.isShowingPhotoSampler) {
                PhotoSamplerSheet { rgba in
                    model.saveSampledColor(rgba, source: String(localized: "photo"))
                }
            }
            .fullScreenCover(item: $droppedImage) { item in
                PhotoSamplerSheet(image: item.image) { rgba in
                    model.saveSampledColor(rgba, source: String(localized: "photo"))
                }
            }
            #endif
            .fileImporter(isPresented: $model.isShowingFileImporter, allowedContentTypes: [.opaliteColor, .opalitePalette]) { result in
                switch result {
                case .success(let url):
                    importer.handleIncomingURL(url, portfolio: portfolio)
                case .failure(let error):
                    Log.portfolio.error("File import failed: \(error.localizedDescription)")
                }
            }
            .alert("New Palette", isPresented: $model.isNamingNewPalette) {
                TextField(String(localized: "Palette name"), text: $model.newPaletteName)
                Button("Cancel", role: .cancel) {
                    model.isNamingNewPalette = false
                    model.newPaletteName = ""
                }
                Button("Create") { model.createNamedPalette() }
            } message: {
                Text("Name your palette. You can rename it any time.")
            }
            .alert("Rename Color", isPresented: Binding(get: { model.renameTargetID != nil }, set: { if !$0 { model.cancelRenaming() } })) {
                TextField(String(localized: "Color name"), text: $model.renameDraft)
                Button("Cancel", role: .cancel) { model.cancelRenaming() }
                Button("Save") { model.commitRename() }
            } message: {
                Text("Leave the name blank to show the hex code instead.")
            }
            .confirmationDialog(
                "Delete \(model.colorPendingDeletionName)?",
                isPresented: Binding(get: { model.colorPendingDeletion != nil }, set: { if !$0 { model.colorPendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete Color", role: .destructive) { model.deletePendingColor() }
                Button("Cancel", role: .cancel) { model.colorPendingDeletion = nil }
            } message: {
                Text("This can't be undone.")
            }
            .confirmationDialog(
                PortfolioLayout.batchDeleteTitle(count: model.selection.count),
                isPresented: $model.isConfirmingBatchDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { model.deleteSelection() }
                Button("Cancel", role: .cancel) { model.isConfirmingBatchDelete = false }
            } message: {
                Text("This can't be undone.")
            }
    }
}

// MARK: - Image drop

/// An image dropped from another app or Photos (iPad/visionOS).
struct DroppedImage: Identifiable {
    let id = UUID()
    #if canImport(UIKit)
    let image: PlatformImage
    #endif
}

private struct ImageDropTarget: ViewModifier {
    @Binding var droppedImage: DroppedImage?

    func body(content: Content) -> some View {
        #if (os(iOS) && !targetEnvironment(macCatalyst)) || os(visionOS)
        content.onDrop(of: [.image], isTargeted: nil) { providers in
            guard let provider = providers.first(where: { $0.canLoadObject(ofClass: PlatformImage.self) }) else { return false }
            _ = provider.loadObject(ofClass: PlatformImage.self) { object, _ in
                let box = UncheckedSendableBox(value: object)
                Task { @MainActor in
                    guard let image = box.value as? PlatformImage else { return }
                    Haptics.mediumImpact()
                    droppedImage = DroppedImage(image: image)
                }
            }
            return true
        }
        #else
        content
        #endif
    }
}

#if DEBUG
#Preview("Portfolio") {
    NavigationStack {
        PortfolioView()
            .navigationDestination(for: PortfolioDestination.self) { PortfolioDestinationView(destination: $0) }
    }
    .portfolioPreviewEnvironment()
}

#Preview("Empty") {
    NavigationStack {
        PortfolioView()
    }
    .portfolioPreviewEnvironment(seeded: false)
}
#endif
#endif
