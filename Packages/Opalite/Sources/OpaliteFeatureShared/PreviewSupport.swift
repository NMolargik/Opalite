//
//  PreviewSupport.swift
//  OpaliteFeatureShared
//
//  In-memory repositories and a fake Community service behind the production use-cases,
//  plus `.previewEnvironment()` — how feature previews (and feature tests) get a complete
//  environment without SwiftData or CloudKit.
//

import Foundation
import SwiftUI
import OpaliteCore
import OpaliteDesignSystem

// MARK: - In-memory repositories

public final class InMemoryColorRepository: ColorRepository {
    public var storage: [OpaliteColor] = []
    private let changeCenter: PortfolioChangeCenter

    public init(changeCenter: PortfolioChangeCenter, colors: [OpaliteColor] = []) {
        self.changeCenter = changeCenter
        self.storage = colors
    }

    public func colors() throws(PersistenceError) -> [OpaliteColor] {
        storage.sorted { ($0.updatedAt, $0.createdAt) > ($1.updatedAt, $1.createdAt) }
    }
    public func color(withID id: UUID) throws(PersistenceError) -> OpaliteColor? { storage.first { $0.id == id } }
    public func count() throws(PersistenceError) -> Int { storage.count }

    public func insert(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) {
        if color.createdByDisplayName?.isEmpty ?? true { color.createdByDisplayName = authorship.displayName }
        if color.createdOnDeviceName == nil { color.createdOnDeviceName = authorship.deviceName }
        if let palette = color.palette, palette.colors?.contains(where: { $0.id == color.id }) == false {
            palette.colors?.append(color)
        }
        storage.removeAll { $0.id == color.id }
        storage.append(color)
        changeCenter.notify(.colorCreated(color.id))
    }

    public func update(_ color: OpaliteColor, authorship: Authorship, configure: (OpaliteColor) -> Void) throws(PersistenceError) {
        configure(color)
        color.updatedAt = .now
        color.updatedOnDeviceName = authorship.deviceName
        changeCenter.notify(.colorUpdated(color.id))
    }

    public func delete(_ color: OpaliteColor) throws(PersistenceError) {
        color.palette?.colors?.removeAll { $0.id == color.id }
        storage.removeAll { $0.id == color.id }
        changeCenter.notify(.colorDeleted(color.id))
    }

    public func attach(_ color: OpaliteColor, to palette: OpalitePalette, authorship: Authorship) throws(PersistenceError) {
        color.palette?.colors?.removeAll { $0.id == color.id }
        color.palette = palette
        if palette.colors == nil { palette.colors = [] }
        palette.colors?.removeAll { $0.id == color.id }
        palette.colors?.append(color)
        color.updatedAt = .now
        palette.updatedAt = .now
        changeCenter.notify(.colorUpdated(color.id))
    }

    public func detach(_ color: OpaliteColor, authorship: Authorship) throws(PersistenceError) {
        guard let palette = color.palette else { return }
        palette.colors?.removeAll { $0.id == color.id }
        color.palette = nil
        color.updatedAt = .now
        changeCenter.notify(.colorUpdated(color.id))
    }
}

public final class InMemoryPaletteRepository: PaletteRepository {
    public var storage: [OpalitePalette] = []
    private let changeCenter: PortfolioChangeCenter
    private let colors: InMemoryColorRepository

    public init(changeCenter: PortfolioChangeCenter, colors: InMemoryColorRepository, palettes: [OpalitePalette] = []) {
        self.changeCenter = changeCenter
        self.colors = colors
        self.storage = palettes
    }

    public func palettes() throws(PersistenceError) -> [OpalitePalette] { storage.sorted { $0.createdAt > $1.createdAt } }
    public func palette(withID id: UUID) throws(PersistenceError) -> OpalitePalette? { storage.first { $0.id == id } }
    public func count() throws(PersistenceError) -> Int { storage.count }

    public func insert(_ palette: OpalitePalette, authorship: Authorship) throws(PersistenceError) {
        if palette.createdByDisplayName?.isEmpty ?? true { palette.createdByDisplayName = authorship.displayName }
        storage.removeAll { $0.id == palette.id }
        storage.append(palette)
        for color in palette.colors ?? [] {
            color.palette = palette
            if !colors.storage.contains(where: { $0.id == color.id }) { colors.storage.append(color) }
        }
        changeCenter.notify(.paletteCreated(palette.id))
    }

    public func update(_ palette: OpalitePalette, configure: (OpalitePalette) -> Void) throws(PersistenceError) {
        configure(palette)
        palette.updatedAt = .now
        changeCenter.notify(.paletteUpdated(palette.id))
    }

    public func delete(_ palette: OpalitePalette, deleteColors: Bool) throws(PersistenceError) {
        for color in palette.colors ?? [] {
            if deleteColors { colors.storage.removeAll { $0.id == color.id } } else { color.palette = nil }
        }
        palette.canvasFile?.palette = nil
        storage.removeAll { $0.id == palette.id }
        changeCenter.notify(.paletteDeleted(palette.id))
    }

    public func attach(_ canvas: CanvasFile, to palette: OpalitePalette) throws(PersistenceError) {
        canvas.palette?.canvasFile = nil
        palette.canvasFile?.palette = nil
        palette.canvasFile = canvas
        canvas.palette = palette
        changeCenter.notify(.paletteUpdated(palette.id))
    }

    public func detachCanvas(from palette: OpalitePalette) throws(PersistenceError) {
        palette.canvasFile?.palette = nil
        palette.canvasFile = nil
        changeCenter.notify(.paletteUpdated(palette.id))
    }
}

public final class InMemoryCanvasRepository: CanvasRepository {
    public var storage: [CanvasFile] = []
    private let changeCenter: PortfolioChangeCenter

    public init(changeCenter: PortfolioChangeCenter, canvases: [CanvasFile] = []) {
        self.changeCenter = changeCenter
        self.storage = canvases
    }

    public func canvases() throws(PersistenceError) -> [CanvasFile] {
        storage.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
    public func canvas(withID id: UUID) throws(PersistenceError) -> CanvasFile? { storage.first { $0.id == id } }
    public func count() throws(PersistenceError) -> Int { storage.count }

    public func insert(_ canvas: CanvasFile, deviceName: String?) throws(PersistenceError) {
        canvas.lastEditedDeviceName = deviceName
        storage.append(canvas)
        changeCenter.notify(.canvasCreated(canvas.id))
    }

    public func update(_ canvas: CanvasFile, deviceName: String?, configure: (CanvasFile) -> Void) throws(PersistenceError) {
        configure(canvas)
        canvas.updatedAt = .now
        changeCenter.notify(.canvasUpdated(canvas.id))
    }

    public func delete(_ canvas: CanvasFile) throws(PersistenceError) {
        canvas.palette?.canvasFile = nil
        storage.removeAll { $0.id == canvas.id }
        changeCenter.notify(.canvasDeleted(canvas.id))
    }
}

// MARK: - Fake Community service

public final class FakeCommunityService: CommunityService {
    public var colors: [CommunityColor]
    public var palettes: [CommunityPalette]
    public var userID: CommunityRecordID?
    public var failure: OpaliteError?
    public private(set) var publishedColors: [ColorPublication] = []
    public private(set) var publishedPalettes: [PalettePublication] = []
    public private(set) var reports: [(CommunityRecordID, ReportReason)] = []

    public init(colors: [CommunityColor] = [.sample, .sample2], palettes: [CommunityPalette] = [.sample], userID: CommunityRecordID? = CommunityRecordID(recordName: "sample-user-1")) {
        self.colors = colors
        self.palettes = palettes
        self.userID = userID
    }

    public func currentUserRecordID() async -> CommunityRecordID? { userID }

    public func fetchColors(sortBy: CommunitySortOption, cursor: CommunityCursor?, limit: Int) async throws(OpaliteError) -> CommunityPage<CommunityColor> {
        if let failure { throw failure }
        return CommunityPage(items: sortBy.sort(colors.filter { !$0.isHidden }), nextCursor: nil)
    }

    public func fetchPalettes(sortBy: CommunitySortOption, cursor: CommunityCursor?, limit: Int) async throws(OpaliteError) -> CommunityPage<CommunityPalette> {
        if let failure { throw failure }
        return CommunityPage(items: sortBy.sort(palettes.filter { !$0.isHidden }), nextCursor: nil)
    }

    public func fetchPaletteColors(paletteID: CommunityRecordID) async throws(OpaliteError) -> [CommunityColor] {
        palettes.first { $0.id == paletteID }?.colors ?? []
    }

    public func fetchPublisherContent(userRecordID: CommunityRecordID) async throws(OpaliteError) -> (colors: [CommunityColor], palettes: [CommunityPalette]) {
        (colors.filter { $0.publisherUserRecordID == userRecordID }, palettes.filter { $0.publisherUserRecordID == userRecordID })
    }

    public func publish(_ color: ColorPublication, publisherName: String) async throws(OpaliteError) -> CommunityColor {
        if let failure { throw failure }
        publishedColors.append(color)
        let published = CommunityColor(id: CommunityRecordID(recordName: UUID().uuidString), originalColorID: color.originalColorID, name: color.name, notes: color.notes, red: color.rgba.red, green: color.rgba.green, blue: color.rgba.blue, alpha: color.rgba.alpha, publisherName: publisherName, publisherUserRecordID: userID ?? .unknown, createdOnDeviceName: color.createdOnDeviceName, originalCreatedAt: color.originalCreatedAt, publishedAt: Date())
        colors.insert(published, at: 0)
        return published
    }

    public func publish(_ palette: PalettePublication, publisherName: String) async throws(OpaliteError) -> CommunityPalette {
        if let failure { throw failure }
        publishedPalettes.append(palette)
        var publishedColors: [CommunityColor] = []
        for color in palette.colors { publishedColors.append(try await publish(color, publisherName: publisherName)) }
        let published = CommunityPalette(id: CommunityRecordID(recordName: UUID().uuidString), originalPaletteID: palette.originalPaletteID, name: palette.name, notes: palette.notes, tags: palette.tags, colorCount: palette.colors.count, previewImageData: palette.previewImagePNG, publisherName: publisherName, publisherUserRecordID: userID ?? .unknown, originalCreatedAt: palette.originalCreatedAt, publishedAt: Date(), colors: publishedColors)
        palettes.insert(published, at: 0)
        return published
    }

    public func unpublishColor(id: CommunityRecordID) async throws(OpaliteError) {
        if let failure { throw failure }
        colors.removeAll { $0.id == id }
    }

    public func unpublishPalette(id: CommunityRecordID) async throws(OpaliteError) {
        if let failure { throw failure }
        palettes.removeAll { $0.id == id }
    }

    public func report(id: CommunityRecordID, type: CommunityItemType, reason: ReportReason, details: String?) async throws(OpaliteError) -> Int64 {
        if let failure { throw failure }
        reports.append((id, reason))
        if let index = colors.firstIndex(where: { $0.id == id }) {
            colors[index].reportCount += 1
            colors[index].isHidden = CommunityModeration.isHidden(afterReports: colors[index].reportCount)
            return colors[index].reportCount
        }
        if let index = palettes.firstIndex(where: { $0.id == id }) {
            palettes[index].reportCount += 1
            palettes[index].isHidden = CommunityModeration.isHidden(afterReports: palettes[index].reportCount)
            return palettes[index].reportCount
        }
        return 1
    }

    public func fetchReportedColors() async throws(OpaliteError) -> [CommunityColor] { colors.filter { $0.reportCount > 0 } }
    public func fetchReportedPalettes() async throws(OpaliteError) -> [CommunityPalette] { palettes.filter { $0.reportCount > 0 } }

    public func clearReports(id: CommunityRecordID) async throws(OpaliteError) {
        if let index = colors.firstIndex(where: { $0.id == id }) { colors[index].reportCount = 0; colors[index].isHidden = false }
        if let index = palettes.firstIndex(where: { $0.id == id }) { palettes[index].reportCount = 0; palettes[index].isHidden = false }
    }
}

// MARK: - Fake seams

public final class FakeKeyValueStore: KeyValueStoring, @unchecked Sendable {
    private var values: [String: Any] = [:]
    public init() {}
    public func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    public func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    public func integer(forKey key: String) -> Int { values[key] as? Int ?? 0 }
    public func string(forKey key: String) -> String? { values[key] as? String }
    public func data(forKey key: String) -> Data? { values[key] as? Data }
    public func object(forKey key: String) -> Any? { values[key] }
    public func set(_ value: Any?, forKey key: String) { values[key] = value }
    public func removeObject(forKey key: String) { values.removeValue(forKey: key) }
}

public final class FakePasteboard: Pasteboarding {
    public private(set) var strings: [String] = []
    public private(set) var dataItems: [(Data, String)] = []
    public init() {}
    public func copy(string: String) { strings.append(string) }
    public func copy(data: Data, type: String, fallbackString: String?) {
        dataItems.append((data, type))
        if let fallbackString { strings.append(fallbackString) }
    }
}

public final class RecordingIntentDonor: IntentDonating {
    public private(set) var donated: [DonatableAction] = []
    public init() {}
    public func donate(_ action: DonatableAction) { donated.append(action) }
}

// MARK: - Preview environment

/// A fully wired, in-memory object graph for previews and feature tests.
@MainActor
public final class PreviewEnvironment {
    public let changeCenter = PortfolioChangeCenter()
    public let router = AppRouter()
    public let toastManager = ToastManager()
    public let entitlements: FixedEntitlement
    public let defaults = FakeKeyValueStore()
    public let pasteboard = FakePasteboard()
    public let colorRepository: InMemoryColorRepository
    public let paletteRepository: InMemoryPaletteRepository
    public let canvasRepository: InMemoryCanvasRepository
    public let communityService = FakeCommunityService()
    public let portfolio: PortfolioModel
    public let canvases: CanvasModel
    public let community: CommunityModel
    public let hexCopy: HexCopyModel
    public let importer: ImportModel

    /// - Parameters:
    ///   - hasOnyx: The entitlement to simulate.
    ///   - seeded: Whether to start with sample palettes, loose colors, and canvases.
    public init(hasOnyx: Bool = true, seeded: Bool = true) {
        entitlements = FixedEntitlement(hasOnyx: hasOnyx)
        colorRepository = InMemoryColorRepository(changeCenter: changeCenter)
        paletteRepository = InMemoryPaletteRepository(changeCenter: changeCenter, colors: colorRepository)
        canvasRepository = InMemoryCanvasRepository(changeCenter: changeCenter)

        if seeded {
            let sample = OpalitePalette.sample
            for color in sample.colors ?? [] { color.palette = sample }
            paletteRepository.storage = [sample]
            colorRepository.storage = (sample.colors ?? []) + [
                OpaliteColor(name: "Moss", red: 0.35, green: 0.55, blue: 0.30),
                OpaliteColor(name: "Bark", red: 0.45, green: 0.30, blue: 0.20),
                OpaliteColor(name: nil, red: 0.9, green: 0.3, blue: 0.5, alpha: 0.6),
            ]
            canvasRepository.storage = [CanvasFile(title: "Sketch"), CanvasFile(title: "Ideas")]
        }

        let observe = ObservePortfolioChangesUseCase(center: changeCenter)
        portfolio = PortfolioModel(
            loadColors: LoadColorsUseCase(repository: colorRepository),
            findColor: FindColorUseCase(repository: colorRepository),
            createColor: CreateColorUseCase(repository: colorRepository),
            insertColor: InsertColorUseCase(repository: colorRepository),
            updateColor: UpdateColorUseCase(repository: colorRepository),
            deleteColor: DeleteColorUseCase(repository: colorRepository),
            moveColor: MoveColorToPaletteUseCase(repository: colorRepository),
            loadPalettes: LoadPalettesUseCase(repository: paletteRepository),
            findPalette: FindPaletteUseCase(repository: paletteRepository),
            createPalette: CreatePaletteUseCase(repository: paletteRepository, entitlements: entitlements),
            insertPalette: InsertPaletteUseCase(repository: paletteRepository, entitlements: entitlements),
            updatePalette: UpdatePaletteUseCase(repository: paletteRepository),
            deletePalette: DeletePaletteUseCase(repository: paletteRepository),
            linkCanvas: LinkCanvasToPaletteUseCase(repository: paletteRepository),
            observeChanges: observe,
            device: GenericDevice(deviceName: "Preview Device"),
            defaults: defaults,
            toastManager: toastManager,
            router: router,
            appVersion: "1.0"
        )
        canvases = CanvasModel(
            loadCanvases: LoadCanvasesUseCase(repository: canvasRepository),
            findCanvas: FindCanvasUseCase(repository: canvasRepository),
            createCanvas: CreateCanvasUseCase(repository: canvasRepository, entitlements: entitlements),
            updateCanvas: UpdateCanvasUseCase(repository: canvasRepository),
            deleteCanvas: DeleteCanvasUseCase(repository: canvasRepository),
            observeChanges: observe,
            entitlements: entitlements,
            device: GenericDevice(deviceName: "Preview Device"),
            toastManager: toastManager,
            router: router
        )
        community = CommunityModel(service: communityService, entitlements: entitlements, toastManager: toastManager, publisherName: "Preview User")
        hexCopy = HexCopyModel(defaults: defaults, pasteboard: pasteboard, toastManager: toastManager)
        importer = ImportModel(toastManager: toastManager)
    }
}

extension View {
    /// Injects a complete preview graph into the environment.
    public func previewEnvironment(_ environment: PreviewEnvironment) -> some View {
        self
            .environment(environment.router)
            .environment(environment.toastManager)
            .environment(environment.portfolio)
            .environment(environment.canvases)
            .environment(environment.community)
            .environment(environment.hexCopy)
            .environment(environment.importer)
            .environment(\.onyxEntitlement, environment.entitlements)
    }

    /// Injects a fresh, seeded preview graph.
    public func previewEnvironment(hasOnyx: Bool = true, seeded: Bool = true) -> some View {
        previewEnvironment(PreviewEnvironment(hasOnyx: hasOnyx, seeded: seeded))
    }
}

// MARK: - Entitlement environment key

private struct OnyxEntitlementKey: EnvironmentKey {
    static let defaultValue: any EntitlementProviding = FixedEntitlement(hasOnyx: false)
}

extension EnvironmentValues {
    /// The Onyx entitlement provider; features read `hasOnyx` from it.
    public var onyxEntitlement: any EntitlementProviding {
        get { self[OnyxEntitlementKey.self] }
        set { self[OnyxEntitlementKey.self] = newValue }
    }
}
