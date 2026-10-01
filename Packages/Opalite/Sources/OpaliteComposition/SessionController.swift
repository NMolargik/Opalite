//
//  SessionController.swift
//  OpaliteComposition
//
//  The composition root. Builds the whole dependency graph once (container → change
//  center → repositories → use-cases → shared models → system-framework managers →
//  status sync) and owns app-wide policy: deep-link routing, Siri on-screen awareness,
//  the watch relay, and startup work. Screens read the shared @Observable models from
//  the environment (RootView injects them); App Intents reach persistence through the
//  use-case properties — never a repository directly.
//

import Foundation
import Observation
import SwiftData
import OpaliteCore
import OpaliteData
import OpaliteDesignSystem
import OpaliteFeatureShared
import OpaliteServices
import os

@MainActor
@Observable
public final class SessionController {

    // MARK: - Graph

    public let container: ModelContainer
    public let router = AppRouter()
    public let toastManager: ToastManager
    public let portfolio: PortfolioModel
    public let canvases: CanvasModel
    public let community: CommunityModel
    public let hexCopy: HexCopyModel
    public let importer: ImportModel
    public let cloudSync: CloudSyncManager
    public let subscriptions: SubscriptionManager
    public let colorNaming: ColorNameSuggestionService
    public let statusSync: PortfolioStatusSync
    #if os(iOS) && canImport(WatchConnectivity)
    public let phoneConnectivity: PhoneConnectivityManager
    #endif

    // Use-cases exposed for App Intents and Spotlight.
    public let loadColors: any LoadColors
    public let loadPalettes: any LoadPalettes
    public let findColor: any FindColor
    public let findPalette: any FindPalette
    public let createColor: any CreateColor
    public let createPalette: any CreatePalette
    public let observeChanges: any ObservePortfolioChanges

    @ObservationIgnored private let activityAnnotator: (any EntityActivityAnnotating)?
    @ObservationIgnored private let sharedDefaults: (any KeyValueStoring)?
    @ObservationIgnored private let sharedImages: SharedImageStore
    @ObservationIgnored private var started = false

    // MARK: - Init

    /// - Parameters:
    ///   - container: The SwiftData container (defaults to the CloudKit-backed store).
    ///   - defaults: Standard defaults (preferences).
    ///   - sharedDefaults: The App Group suite (widgets, intent hand-off).
    ///   - indexer/reviewRequester/intentDonor/activityAnnotator/vocabulary: App-target seams (nil in tests/previews).
    public init(
        container: ModelContainer? = nil,
        defaults: any KeyValueStoring = UserDefaults.standard,
        sharedDefaults: (any KeyValueStoring)? = AppGroup.defaults,
        communityService: (any CommunityService)? = nil,
        entitlements: SubscriptionManager? = nil,
        device: any DeviceDescribing = DeviceInfo(),
        pasteboard: any Pasteboarding = SystemPasteboard(),
        indexer: (any PortfolioIndexing)? = nil,
        reviewRequester: (any ReviewRequesting)? = nil,
        intentDonor: (any IntentDonating)? = nil,
        activityAnnotator: (any EntityActivityAnnotating)? = nil,
        vocabulary: (any ShortcutVocabularyUpdating)? = nil,
        widgetReloader: (any WidgetTimelineReloading)? = WidgetCenterReloader(),
        statusSyncDebounce: Duration = .milliseconds(750)
    ) {
        let container = container ?? OpaliteStore.makeContainer()
        self.container = container
        self.activityAnnotator = activityAnnotator
        self.sharedDefaults = sharedDefaults
        self.sharedImages = SharedImageStore()

        let toastManager = ToastManager()
        self.toastManager = toastManager

        let subscriptions = entitlements ?? SubscriptionManager()
        self.subscriptions = subscriptions

        let changeCenter = PortfolioChangeCenter()
        let colorRepository = DefaultColorRepository(container: container, changeCenter: changeCenter)
        let paletteRepository = DefaultPaletteRepository(container: container, changeCenter: changeCenter)
        let canvasRepository = DefaultCanvasRepository(container: container, changeCenter: changeCenter)

        let observe = ObservePortfolioChangesUseCase(center: changeCenter)
        let loadColors = LoadColorsUseCase(repository: colorRepository)
        let loadPalettes = LoadPalettesUseCase(repository: paletteRepository)
        let findColor = FindColorUseCase(repository: colorRepository)
        let findPalette = FindPaletteUseCase(repository: paletteRepository)
        let createColor = CreateColorUseCase(repository: colorRepository, donor: intentDonor)
        let createPalette = CreatePaletteUseCase(repository: paletteRepository, entitlements: subscriptions, donor: intentDonor)
        self.observeChanges = observe
        self.loadColors = loadColors
        self.loadPalettes = loadPalettes
        self.findColor = findColor
        self.findPalette = findPalette
        self.createColor = createColor
        self.createPalette = createPalette

        #if DEBUG
        let sampleData: (any GenerateSampleData)? = SamplePortfolioData(colors: colorRepository, palettes: paletteRepository, canvases: canvasRepository)
        #else
        let sampleData: (any GenerateSampleData)? = nil
        #endif

        portfolio = PortfolioModel(
            loadColors: loadColors,
            findColor: findColor,
            createColor: createColor,
            insertColor: InsertColorUseCase(repository: colorRepository),
            updateColor: UpdateColorUseCase(repository: colorRepository),
            deleteColor: DeleteColorUseCase(repository: colorRepository),
            moveColor: MoveColorToPaletteUseCase(repository: colorRepository),
            loadPalettes: loadPalettes,
            findPalette: findPalette,
            createPalette: createPalette,
            insertPalette: InsertPaletteUseCase(repository: paletteRepository, entitlements: subscriptions),
            updatePalette: UpdatePaletteUseCase(repository: paletteRepository),
            deletePalette: DeletePaletteUseCase(repository: paletteRepository),
            linkCanvas: LinkCanvasToPaletteUseCase(repository: paletteRepository),
            observeChanges: observe,
            generateSampleData: sampleData,
            reviewRequester: reviewRequester,
            device: device,
            defaults: defaults,
            toastManager: toastManager,
            router: router
        )

        canvases = CanvasModel(
            loadCanvases: LoadCanvasesUseCase(repository: canvasRepository),
            findCanvas: FindCanvasUseCase(repository: canvasRepository),
            createCanvas: CreateCanvasUseCase(repository: canvasRepository, entitlements: subscriptions),
            updateCanvas: UpdateCanvasUseCase(repository: canvasRepository),
            deleteCanvas: DeleteCanvasUseCase(repository: canvasRepository),
            observeChanges: observe,
            entitlements: subscriptions,
            device: device,
            toastManager: toastManager,
            router: router,
            thumbnailRenderer: Self.makeThumbnailRenderer()
        )

        let cloud = CloudSyncManager(changeCenter: changeCenter)
        cloud.configure(with: container.mainContext)
        cloudSync = cloud

        community = CommunityModel(
            service: communityService ?? CloudKitCommunityService(),
            entitlements: subscriptions,
            toastManager: toastManager,
            publisherName: portfolio.authorName,
            isOnline: { [cloud] in cloud.isOnline }
        )

        hexCopy = HexCopyModel(defaults: defaults, pasteboard: pasteboard, toastManager: toastManager, donor: intentDonor)
        importer = ImportModel(toastManager: toastManager)
        colorNaming = ColorNameSuggestionService()

        #if os(iOS) && canImport(WatchConnectivity)
        let phone = PhoneConnectivityManager(defaults: defaults)
        phoneConnectivity = phone
        let watch: (any WatchPortfolioPushing)? = phone
        #else
        let watch: (any WatchPortfolioPushing)? = nil
        #endif

        let statusSync = PortfolioStatusSync(
            loadColors: loadColors,
            loadPalettes: loadPalettes,
            observeChanges: observe,
            widgetStorage: WidgetColorStorage(defaults: sharedDefaults),
            widgets: widgetReloader,
            watch: watch,
            indexer: indexer,
            vocabulary: vocabulary,
            debounce: statusSyncDebounce
        )
        self.statusSync = statusSync

        #if os(iOS) && canImport(WatchConnectivity)
        phone.configure(snapshotProvider: { [statusSync] in statusSync.currentSnapshot() }, pasteboard: pasteboard)
        #endif
    }

    private static func makeThumbnailRenderer() -> (@MainActor (CanvasFile) -> Data?)? {
        #if canImport(PencilKit) && canImport(UIKit) && !os(watchOS) && !os(tvOS)
        return { canvas in CanvasThumbnailRenderer.thumbnailPNG(for: canvas.loadDrawing(), canvasSize: canvas.canvasSize) }
        #else
        return nil
        #endif
    }

    // MARK: - Startup

    /// One-time launch work: status sync, watch connectivity, and the intent hand-off
    /// check. Safe to call more than once.
    public func start() {
        if !started {
            started = true
            statusSync.start()
            #if os(iOS) && canImport(WatchConnectivity)
            phoneConnectivity.activate()
            #endif
        }
        consumePendingDeepLinkFromIntents()
        consumePendingSharedImage()
    }

    /// Foreground work: entitlements and the queued watch hex copy.
    public func becameActive() async {
        await subscriptions.processUnfinishedTransactions()
        await subscriptions.updatePurchasedProducts()
        consumePendingDeepLinkFromIntents()
        consumePendingSharedImage()
        #if os(iOS) && canImport(WatchConnectivity)
        if let hex = phoneConnectivity.processPendingHexCopy() {
            toastManager.showSuccess(String(localized: "Copied \(hex) from Apple Watch"), systemImage: "applewatch")
        }
        #endif
    }

    /// Keeps the Community publisher name in step with the profile.
    public func syncPublisherName() {
        community.publisherName = portfolio.authorName
    }

    // MARK: - Deep links

    /// Routes an external URL: `opalite://` links through the router; Opalite files
    /// through the importer. Returns whether it was recognized.
    @discardableResult
    public func handle(url: URL) -> Bool {
        if router.open(url: url) { return true }
        return importer.handleIncomingURL(url, portfolio: portfolio)
    }

    /// Picks up a deep link stashed by an `openAppWhenRun` App Intent.
    public func consumePendingDeepLinkFromIntents() {
        if let link = DeepLink.takePending(from: sharedDefaults) {
            router.open(link)
        }
    }

    /// If the Share Extension dropped an image, ask the shell to open the sampler.
    public func consumePendingSharedImage() {
        guard sharedImages.hasSharedImage else { return }
        router.present(.sharedImage)
    }

    /// The image the Share Extension handed off, consumed once.
    public func takeSharedImageData() -> Data? {
        defer { sharedImages.clear() }
        return sharedImages.load()
    }

    // MARK: - Siri on-screen awareness

    public func annotateViewingColor(_ activity: NSUserActivity, colorID: UUID) {
        activity.title = String(localized: "Color")
        activity.isEligibleForHandoff = false
        activity.isEligibleForSearch = false
        activity.userInfo = ["colorID": colorID.uuidString]
        activityAnnotator?.annotateColor(activity, colorID: colorID)
    }

    public func annotateViewingPalette(_ activity: NSUserActivity, paletteID: UUID) {
        activity.title = String(localized: "Palette")
        activity.isEligibleForHandoff = false
        activity.isEligibleForSearch = false
        activity.userInfo = ["paletteID": paletteID.uuidString]
        activityAnnotator?.annotatePalette(activity, paletteID: paletteID)
    }
}
