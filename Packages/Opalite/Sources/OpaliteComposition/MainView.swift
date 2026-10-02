//
//  MainView.swift
//  OpaliteComposition
//
//  The adaptive five-tab shell: a tab bar on iPhone and a sidebar on iPad/Mac/visionOS
//  through `.sidebarAdaptable`, one NavigationStack per tab with typed destinations, the
//  globally presented sheets (color editor, photo sampler, paywall, imports, hex-copy
//  preference), and every deep link / presentation request routed through `AppRouter`.
//

#if os(iOS) || os(visionOS)
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteFeaturePortfolio
import OpaliteFeatureCommunity
import OpaliteFeatureSearch
import OpaliteFeatureCanvas
import OpaliteFeatureSettings
import OpaliteFeatureColorEditor
import OpaliteFeatureSharing
import OpaliteFeatureSwatchBar

struct MainView: View {
    @Environment(PortfolioModel.self) private var portfolio
    @Environment(CanvasModel.self) private var canvases
    @Environment(ImportModel.self) private var importer
    @Environment(HexCopyModel.self) private var hexCopy
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    let session: SessionController

    @State private var navigation = NavigationModel()
    @AppStorage(AppStorageKeys.colorBlindnessMode) private var colorBlindnessModeRaw = ColorBlindnessMode.off.rawValue
    @AppStorage(AppStorageKeys.skipSwatchBarConfirmation) private var skipSwatchBarConfirmation = false

    private var router: AppRouter { session.router }
    private var settingsSymbol: String {
        (ColorBlindnessMode(rawValue: colorBlindnessModeRaw) ?? .off).isActive ? "eye.trianglebadge.exclamationmark" : AppTab.settings.systemImage
    }

    var body: some View {
        @Bindable var router = router
        @Bindable var importer = importer
        @Bindable var hexCopy = hexCopy

        TabView(selection: $router.selectedTab) {
            portfolioTab
            communityTab
            canvasTab
            settingsTab
            searchTab
        }
        .tabViewStyle(.sidebarAdaptable)
        .minimizeTabBarOnScrollIfAvailable()
        .tint(router.selectedTab.color)
        // MARK: Global presentations
        .sharedSheet(item: $navigation.presentation) { presentation in
            presentationSheet(presentation)
        }
        .sharedSheet(isPresented: $importer.isShowingColorImport) {
            if let preview = importer.pendingColorImport { ColorImportConfirmationSheet(preview: preview) }
        }
        .sharedSheet(isPresented: $importer.isShowingPaletteImport) {
            if let preview = importer.pendingPaletteImport { PaletteImportConfirmationSheet(preview: preview) }
        }
        .alert("Couldn't Import", isPresented: $importer.isShowingError, presenting: importer.importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "")
        }
        .alert("Copy Hex Codes With a # Prefix?", isPresented: $hexCopy.isAskingPreference) {
            Button("Include #") { hexCopy.choosePrefix(true) }
            Button("No Prefix") { hexCopy.choosePrefix(false) }
        } message: {
            Text("You can change this later in Settings.")
        }
        // MARK: Routing
        .onChange(of: router.pendingDeepLink) { _, link in handleDeepLink(link) }
        .onChange(of: router.pendingPresentation) { _, presentation in handlePresentation(presentation) }
        .onChange(of: canvases.pendingCanvasID) { _, id in openCanvas(id) }
        .onChange(of: portfolio.authorName) { session.syncPublisherName() }
        .onAppear {
            handleDeepLink(router.pendingDeepLink)
            handlePresentation(router.pendingPresentation)
            openCanvas(canvases.pendingCanvasID)
        }
    }

    // MARK: - Tabs

    private var portfolioTab: some TabContent<AppTab> {
        Tab(AppTab.portfolio.title, systemImage: AppTab.portfolio.systemImage, value: .portfolio) {
            NavigationStack(path: $navigation.portfolioPath) {
                PortfolioView()
                    .navigationDestination(for: PortfolioDestination.self, destination: portfolioDestination)
            }
        }
    }

    private var communityTab: some TabContent<AppTab> {
        Tab(AppTab.community.title, systemImage: AppTab.community.systemImage, value: .community) {
            NavigationStack(path: $navigation.communityPath) {
                CommunityView()
                    .navigationDestination(for: CommunityDestination.self) { CommunityDestinationView(destination: $0) }
            }
        }
    }

    private var canvasTab: some TabContent<AppTab> {
        Tab(AppTab.canvas.title, systemImage: AppTab.canvas.systemImage, value: .canvas) {
            NavigationStack(path: $navigation.canvasPath) {
                CanvasListView()
                    .navigationDestination(for: CanvasDestination.self) { CanvasDestinationView(destination: $0) }
            }
        }
    }

    private var settingsTab: some TabContent<AppTab> {
        Tab(AppTab.settings.title, systemImage: settingsSymbol, value: .settings) {
            NavigationStack(path: $navigation.settingsPath) {
                SettingsView()
                    .navigationDestination(for: SettingsDestination.self) { SettingsDestinationView(destination: $0) }
            }
        }
    }

    private var searchTab: some TabContent<AppTab> {
        Tab(AppTab.search.title, systemImage: AppTab.search.systemImage, value: .search, role: .search) {
            NavigationStack(path: $navigation.searchPath) {
                SearchView()
                    .navigationDestination(for: PortfolioDestination.self, destination: portfolioDestination)
            }
        }
    }

    // MARK: - Destinations

    @ContentBuilder
    private func portfolioDestination(_ destination: PortfolioDestination) -> some View {
        switch destination {
        case .canvas(let id):
            CanvasView(canvasID: id)
        case .color(let id):
            PortfolioDestinationView(destination: destination)
                .userActivity(UserActivityType.viewingColor) { session.annotateViewingColor($0, colorID: id) }
        case .palette(let id):
            PortfolioDestinationView(destination: destination)
                .userActivity(UserActivityType.viewingPalette) { session.annotateViewingPalette($0, paletteID: id) }
        }
    }

    @ContentBuilder
    private func presentationSheet(_ presentation: PresentationItem) -> some View {
        switch presentation.kind {
        case .paywall(let context):
            PaywallView(context: context)
        case .colorEditor:
            ColorEditorView(mode: .create(), onCancel: { navigation.presentation = nil }) { result in
                navigation.presentation = nil
                if let color = portfolio.createColor(result.rgba, name: result.name, notes: result.notes) {
                    navigateToColor(color.id)
                }
            }
            .interactiveDismissDisabled()
        case .photoSampler:
            PhotoSamplerSheet { rgba in
                navigation.presentation = nil
                navigation.presentation = PresentationItem(kind: .editorWithColor(rgba))
            }
        case .sharedImage:
            PhotoSamplerSheet(image: session.takeSharedImageData().flatMap(PlatformImage.init(data:))) { rgba in
                navigation.presentation = nil
                navigation.presentation = PresentationItem(kind: .editorWithColor(rgba))
            }
        case .editorWithColor(let rgba):
            ColorEditorView(mode: .create(initial: rgba), onCancel: { navigation.presentation = nil }) { result in
                navigation.presentation = nil
                if let color = portfolio.createColor(result.rgba, name: result.name, notes: result.notes) {
                    navigateToColor(color.id)
                }
            }
            .interactiveDismissDisabled()
        case .swatchBarInfo:
            SwatchBarInfoSheet(onOpen: supportsMultipleWindows ? { openWindow(id: SwatchBarScene.windowID) } : nil)
        }
    }

    // MARK: - Routing

    private func handleDeepLink(_ link: DeepLink?) {
        guard let link else { return }
        defer { router.pendingDeepLink = nil }
        switch link {
        case .portfolio, .community, .search, .canvases, .settings:
            break // the router already selected the tab
        case .color(let id):
            navigateToColor(id)
        case .palette(let id):
            router.select(.portfolio)
            navigation.portfolioPath = NavigationPath([PortfolioDestination.palette(id)])
        case .canvas(let id):
            router.select(.canvas)
            navigation.canvasPath = NavigationPath([CanvasDestination.canvas(id)])
        case .createColor:
            router.present(.colorEditor)
        case .createPalette:
            router.select(.portfolio)
            _ = portfolio.createPalette(name: String(localized: "New Palette"))
        case .samplePhoto:
            router.present(.photoSampler)
        case .sharedImage:
            router.present(.sharedImage)
        case .swatchBar:
            openSwatchBar()
        case .onyx:
            router.select(.settings)
            navigation.settingsPath = NavigationPath([SettingsDestination.onyx])
        }
    }

    private func handlePresentation(_ presentation: PendingPresentation?) {
        guard let presentation else { return }
        defer { router.pendingPresentation = nil }
        switch presentation {
        case .paywall(let context): navigation.presentation = PresentationItem(kind: .paywall(context))
        case .colorEditor: navigation.presentation = PresentationItem(kind: .colorEditor)
        case .photoSampler: navigation.presentation = PresentationItem(kind: .photoSampler)
        case .sharedImage: navigation.presentation = PresentationItem(kind: .sharedImage)
        case .swatchBarInfo: navigation.presentation = PresentationItem(kind: .swatchBarInfo)
        }
    }

    private func navigateToColor(_ id: UUID) {
        router.select(.portfolio)
        navigation.portfolioPath = NavigationPath([PortfolioDestination.color(id)])
    }

    private func openCanvas(_ id: UUID?) {
        guard let id else { return }
        canvases.pendingCanvasID = nil
        router.select(.canvas)
        navigation.canvasPath = NavigationPath([CanvasDestination.canvas(id)])
    }

    private func openSwatchBar() {
        guard supportsMultipleWindows else {
            navigation.presentation = PresentationItem(kind: .swatchBarInfo)
            return
        }
        if skipSwatchBarConfirmation {
            openWindow(id: SwatchBarScene.windowID)
        } else {
            navigation.presentation = PresentationItem(kind: .swatchBarInfo)
        }
    }
}

// MARK: - Accessory

// MARK: - Navigation model

@MainActor
@Observable
final class NavigationModel {
    var portfolioPath = NavigationPath()
    var communityPath = NavigationPath()
    var canvasPath = NavigationPath()
    var settingsPath = NavigationPath()
    var searchPath = NavigationPath()
    var presentation: PresentationItem?
}

struct PresentationItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case paywall(String)
        case colorEditor
        case editorWithColor(RGBA)
        case photoSampler
        case sharedImage
        case swatchBarInfo
    }

    let id = UUID()
    let kind: Kind
}
#endif
