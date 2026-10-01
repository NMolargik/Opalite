//
//  PortfolioModel.swift
//  OpaliteFeatureShared
//
//  The environment-injected portfolio surface every feature shares (successor to
//  ColorManager): cached colors/palettes, the user's palette order, and verbs that each go
//  through a use-case, refresh the cache, and surface failures as toasts (never
//  `try?`-swallowed). Free-tier limits route to the paywall through the router. The change
//  stream refreshes it for writes made elsewhere (CloudKit, intents, watch).
//

import Foundation
import Observation
import OpaliteCore
import OpaliteDesignSystem
import os

/// Context-aware actions the menu bar asks the active detail screen to perform.
nonisolated public enum PortfolioCommand: Equatable, Sendable {
    case editActiveColor
    case moveActiveColorToPalette
    case removeActiveColorFromPalette
    case renameActivePalette
}

@MainActor
@Observable
public final class PortfolioModel {

    // MARK: - Dependencies

    @ObservationIgnored private let loadColors: any LoadColors
    @ObservationIgnored private let findColorUseCase: any FindColor
    @ObservationIgnored private let createColorUseCase: any CreateColor
    @ObservationIgnored private let insertColorUseCase: any InsertColor
    @ObservationIgnored private let updateColorUseCase: any UpdateColor
    @ObservationIgnored private let deleteColorUseCase: any DeleteColor
    @ObservationIgnored private let moveColorUseCase: any MoveColorToPalette
    @ObservationIgnored private let loadPalettes: any LoadPalettes
    @ObservationIgnored private let findPaletteUseCase: any FindPalette
    @ObservationIgnored private let createPaletteUseCase: any CreatePalette
    @ObservationIgnored private let insertPaletteUseCase: any InsertPalette
    @ObservationIgnored private let updatePaletteUseCase: any UpdatePalette
    @ObservationIgnored private let deletePaletteUseCase: any DeletePalette
    @ObservationIgnored private let linkCanvasUseCase: any LinkCanvasToPalette
    @ObservationIgnored private let observeChanges: any ObservePortfolioChanges
    @ObservationIgnored private let generateSampleDataUseCase: (any GenerateSampleData)?
    @ObservationIgnored private let reviewRequester: (any ReviewRequesting)?
    @ObservationIgnored private let device: any DeviceDescribing
    @ObservationIgnored private let defaults: any KeyValueStoring
    @ObservationIgnored private let toastManager: ToastManager
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let appVersion: String

    // MARK: - State

    /// Every color, most recently updated first.
    public private(set) var colors: [OpaliteColor] = []
    /// Every palette, newest first (see `orderedPalettes` for the user's order).
    public private(set) var palettes: [OpalitePalette] = []
    /// The user's manual palette order.
    public private(set) var paletteOrder = PaletteOrder()
    /// Bumped after every refresh so views computing from the cache re-evaluate.
    public private(set) var changeStamp = 0

    /// The display name stamped on new colors/palettes (Settings › Profile).
    public var authorName: String

    /// The color/palette currently open in a detail view (menu-bar context).
    public var activeColorID: UUID?
    public var activePaletteID: UUID?
    /// A menu-bar command for the active detail screen to perform.
    public var pendingCommand: PortfolioCommand?

    @ObservationIgnored private var observationTask: Task<Void, Never>?

    // MARK: - Derived

    public var looseColors: [OpaliteColor] { colors.filter { $0.palette == nil } }
    public var activePalettes: [OpalitePalette] { palettes.filter { !$0.isArchived } }
    public var archivedPalettes: [OpalitePalette] { palettes.filter { $0.isArchived } }
    /// Active palettes in the user's order.
    public var orderedPalettes: [OpalitePalette] { paletteOrder.apply(to: activePalettes) }
    public var activeColor: OpaliteColor? { activeColorID.flatMap { id in colors.first { $0.id == id } } }
    public var activePalette: OpalitePalette? { activePaletteID.flatMap { id in palettes.first { $0.id == id } } }
    public var isEmpty: Bool { colors.isEmpty && palettes.isEmpty }

    public var authorship: Authorship { Authorship(displayName: authorName, deviceName: device.deviceName) }

    // MARK: - Init

    public init(
        loadColors: any LoadColors,
        findColor: any FindColor,
        createColor: any CreateColor,
        insertColor: any InsertColor,
        updateColor: any UpdateColor,
        deleteColor: any DeleteColor,
        moveColor: any MoveColorToPalette,
        loadPalettes: any LoadPalettes,
        findPalette: any FindPalette,
        createPalette: any CreatePalette,
        insertPalette: any InsertPalette,
        updatePalette: any UpdatePalette,
        deletePalette: any DeletePalette,
        linkCanvas: any LinkCanvasToPalette,
        observeChanges: any ObservePortfolioChanges,
        generateSampleData: (any GenerateSampleData)? = nil,
        reviewRequester: (any ReviewRequesting)? = nil,
        device: any DeviceDescribing = GenericDevice(),
        defaults: any KeyValueStoring = UserDefaults.standard,
        toastManager: ToastManager,
        router: AppRouter,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    ) {
        self.loadColors = loadColors
        self.findColorUseCase = findColor
        self.createColorUseCase = createColor
        self.insertColorUseCase = insertColor
        self.updateColorUseCase = updateColor
        self.deleteColorUseCase = deleteColor
        self.moveColorUseCase = moveColor
        self.loadPalettes = loadPalettes
        self.findPaletteUseCase = findPalette
        self.createPaletteUseCase = createPalette
        self.insertPaletteUseCase = insertPalette
        self.updatePaletteUseCase = updatePalette
        self.deletePaletteUseCase = deletePalette
        self.linkCanvasUseCase = linkCanvas
        self.observeChanges = observeChanges
        self.generateSampleDataUseCase = generateSampleData
        self.reviewRequester = reviewRequester
        self.device = device
        self.defaults = defaults
        self.toastManager = toastManager
        self.router = router
        self.appVersion = appVersion
        let storedName = defaults.string(forKey: AppStorageKeys.userName) ?? ""
        self.authorName = storedName.isEmpty ? Authorship.anonymous.displayName : storedName
        self.paletteOrder = PaletteOrder.load(from: defaults)
        refresh()
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let stream = self?.observeChanges() else { return }
            for await change in stream {
                guard let self else { return }
                if change.affectsPortfolio { self.refresh() }
            }
        }
    }

    // MARK: - Reads

    /// Reloads the cache from the store. Failures toast and leave the last good list.
    public func refresh() {
        do {
            colors = try loadColors()
            palettes = try loadPalettes()
            reconcileOrder()
            changeStamp &+= 1
        } catch {
            Log.portfolio.error("Portfolio refresh failed: \(error.localizedDescription)")
            toastManager.show(error: error)
        }
    }

    public func color(withID id: UUID) -> OpaliteColor? {
        if let cached = colors.first(where: { $0.id == id }) { return cached }
        return (try? findColorUseCase(withID: id)) ?? nil
    }

    public func palette(withID id: UUID) -> OpalitePalette? {
        if let cached = palettes.first(where: { $0.id == id }) { return cached }
        return (try? findPaletteUseCase(withID: id)) ?? nil
    }

    /// The colors of a palette, newest-updated first.
    public func colors(in palette: OpalitePalette) -> [OpaliteColor] {
        colors.filter { $0.palette?.id == palette.id }
    }

    // MARK: - Colors

    /// Creates a color; nil on failure (already toasted).
    @discardableResult
    public func createColor(_ rgba: RGBA, name: String? = nil, notes: String? = nil, in palette: OpalitePalette? = nil) -> OpaliteColor? {
        let created = surfacing(fallback: nil) { try createColorUseCase(rgba, name: name, notes: notes, palette: palette, authorship: authorship) }
        if created != nil { maybeRequestReview() }
        return created
    }

    /// Inserts a prebuilt color (import, Community save); nil on failure.
    @discardableResult
    public func insert(_ color: OpaliteColor) -> OpaliteColor? {
        surfacing(fallback: nil) { try insertColorUseCase(color, authorship: authorship) }
    }

    public func update(_ color: OpaliteColor, configure: (OpaliteColor) -> Void) {
        surfacing(fallback: ()) { try updateColorUseCase(color, authorship: authorship, configure: configure) }
    }

    public func rename(_ color: OpaliteColor, to name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        update(color) { $0.name = trimmed?.isEmpty == true ? nil : trimmed }
    }

    public func delete(_ color: OpaliteColor) {
        if activeColorID == color.id { activeColorID = nil }
        surfacing(fallback: ()) { try deleteColorUseCase(color) }
    }

    /// Moves a color into a palette, or makes it loose when `palette` is nil.
    public func move(_ color: OpaliteColor, to palette: OpalitePalette?) {
        surfacing(fallback: ()) { try moveColorUseCase(color, to: palette, authorship: authorship) }
    }

    // MARK: - Palettes

    /// Creates a palette; nil when the free tier's limit was hit (paywall shown) or on failure.
    @discardableResult
    public func createPalette(name: String, notes: String? = nil, tags: [String] = [], colors: [OpaliteColor] = []) -> OpalitePalette? {
        do {
            let palette = try createPaletteUseCase(name: name, notes: notes, tags: tags, colors: colors, authorship: authorship)
            paletteOrder.prepend(palette.id)
            paletteOrder.save(to: defaults)
            refresh()
            maybeRequestReview()
            return palette
        } catch {
            handle(error)
            return nil
        }
    }

    /// Inserts a prebuilt palette (import, Community save); nil on failure or limit.
    @discardableResult
    public func insert(_ palette: OpalitePalette) -> OpalitePalette? {
        do {
            let inserted = try insertPaletteUseCase(palette, authorship: authorship)
            paletteOrder.prepend(inserted.id)
            paletteOrder.save(to: defaults)
            refresh()
            return inserted
        } catch {
            handle(error)
            return nil
        }
    }

    public func update(_ palette: OpalitePalette, configure: (OpalitePalette) -> Void) {
        surfacing(fallback: ()) { try updatePaletteUseCase(palette, configure: configure) }
    }

    public func rename(_ palette: OpalitePalette, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(palette) { $0.name = trimmed }
    }

    public func setArchived(_ palette: OpalitePalette, _ archived: Bool) {
        update(palette) { $0.isArchived = archived }
    }

    public func delete(_ palette: OpalitePalette, deleteColors: Bool) {
        if activePaletteID == palette.id { activePaletteID = nil }
        paletteOrder.remove(palette.id)
        paletteOrder.save(to: defaults)
        surfacing(fallback: ()) { try deletePaletteUseCase(palette, deleteColors: deleteColors) }
    }

    /// Links a canvas to a palette, or unlinks when `canvas` is nil.
    public func link(_ canvas: CanvasFile?, to palette: OpalitePalette) {
        surfacing(fallback: ()) { try linkCanvasUseCase(canvas, to: palette) }
    }

    // MARK: - Palette order

    public func movePalettes(fromOffsets source: IndexSet, toOffset destination: Int) {
        var order = PaletteOrder(ids: orderedPalettes.map(\.id))
        order.move(fromOffsets: source, toOffset: destination)
        paletteOrder = order
        paletteOrder.save(to: defaults)
        changeStamp &+= 1
    }

    public func reorderPalettes(_ ids: [UUID]) {
        paletteOrder.replace(with: ids)
        paletteOrder.save(to: defaults)
        changeStamp &+= 1
    }

    private func reconcileOrder() {
        let reconciled = paletteOrder.reconciled(with: activePalettes)
        if reconciled != paletteOrder {
            paletteOrder = reconciled
            paletteOrder.save(to: defaults)
        }
    }

    // MARK: - Profile

    /// Updates the author name (persisted; stamped on future records).
    public func setAuthorName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        authorName = trimmed.isEmpty ? Authorship.anonymous.displayName : trimmed
        defaults.set(authorName, forKey: AppStorageKeys.userName)
    }

    // MARK: - Sample data

    #if DEBUG
    public func generateSampleData() {
        guard let generateSampleDataUseCase else { return }
        surfacing(fallback: ()) { try generateSampleDataUseCase() }
    }
    #endif

    // MARK: - Review prompt

    private func maybeRequestReview() {
        guard let reviewRequester else { return }
        let last = defaults.string(forKey: AppStorageKeys.lastReviewRequestVersion) ?? ""
        guard ReviewMilestone.shouldPrompt(colorCount: colors.count, paletteCount: palettes.count, currentVersion: appVersion, lastPromptedVersion: last) else { return }
        defaults.set(appVersion, forKey: AppStorageKeys.lastReviewRequestVersion)
        reviewRequester.requestReview()
    }

    // MARK: - Error surfacing

    private func surfacing<T>(fallback: T, _ operation: () throws -> T) -> T {
        do {
            let result = try operation()
            refresh()
            return result
        } catch {
            handle(error)
            return fallback
        }
    }

    private func handle(_ error: any Error) {
        Log.portfolio.error("\(error.localizedDescription)")
        switch error {
        case PaletteCreationError.limitReached:
            toastManager.show(error: OpaliteError.paletteLimitReached, actionTitle: String(localized: "Get Onyx")) { [router] in
                router.requestPaywall(context: OpaliteError.paletteLimitReached.errorDescription ?? "")
            }
        case PaletteCreationError.persistence(let inner):
            toastManager.show(error: inner)
        default:
            toastManager.show(error: error)
        }
    }
}
