//
//  SharedModelTests.swift
//  OpaliteFeatureSharedTests
//
//  The environment-injected models over the preview graph (in-memory repositories, the
//  fake Community service, fake defaults and pasteboard): every verb goes through its
//  use-case, refreshes the cache, toasts on failure, and routes tier limits to the paywall.
//

import Foundation
import Testing
import OpaliteCore
import OpaliteDesignSystem
@testable import OpaliteFeatureShared

// MARK: - Helpers

private extension PreviewEnvironment {
    var sample: OpalitePalette { portfolio.activePalettes.first { $0.name == "Sample Palette" }! }
    var moss: OpaliteColor { portfolio.looseColors.first { $0.name == "Moss" }! }
    var isShowingPaywall: Bool {
        if case .paywall? = router.pendingPresentation { return true }
        return false
    }
}

/// Waits (briefly) until `condition` holds — for writes that arrive over the change stream.
@MainActor
private func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<50 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}

private func makeTemporaryFile(_ data: Data, extension ext: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("opalite-shared-tests-\(UUID().uuidString)")
        .appendingPathExtension(ext)
    try data.write(to: url)
    return url
}

// MARK: - Portfolio

@Suite("PortfolioModel")
struct PortfolioModelTests {
    @Test func seededGraphLoadsLooseColorsAndPalettes() {
        let env = PreviewEnvironment()
        #expect(env.portfolio.palettes.count == 1)
        #expect(env.portfolio.looseColors.count == 3)
        #expect(env.portfolio.colors.count == 9)
        #expect(!env.portfolio.isEmpty)
        #expect(env.portfolio.colors(in: env.sample).count == 6)
    }

    @Test func emptyGraphIsEmpty() {
        let env = PreviewEnvironment(seeded: false)
        #expect(env.portfolio.isEmpty)
        #expect(env.portfolio.orderedPalettes.isEmpty)
    }

    @Test func createColorStampsAuthorshipAndRefreshes() {
        let env = PreviewEnvironment()
        env.portfolio.setAuthorName("Nick")
        let color = env.portfolio.createColor(RGBA(red: 0, green: 0.5, blue: 0.5), name: "Teal", notes: "Sea")
        #expect(color != nil)
        #expect(color?.createdByDisplayName == "Nick")
        #expect(color?.createdOnDeviceName == "Preview Device")
        #expect(color?.notes == "Sea")
        #expect(env.portfolio.looseColors.count == 4)
        #expect(env.portfolio.color(withID: color!.id) != nil)
    }

    @Test func createColorInsidePalette() {
        let env = PreviewEnvironment()
        let palette = env.sample
        let color = env.portfolio.createColor(RGBA(red: 1, green: 1, blue: 0), name: "Lemon", in: palette)
        #expect(color?.palette?.id == palette.id)
        #expect(env.portfolio.colors(in: palette).count == 7)
        #expect(env.portfolio.looseColors.count == 3)
    }

    @Test func renameTrimsAndBlankClears() {
        let env = PreviewEnvironment()
        let color = env.moss
        env.portfolio.rename(color, to: "  Deep Moss ")
        #expect(color.name == "Deep Moss")
        env.portfolio.rename(color, to: "   ")
        #expect(color.name == nil)
    }

    @Test func updateStampsDeviceAndBumpsChangeStamp() {
        let env = PreviewEnvironment()
        let color = env.moss
        let before = env.portfolio.changeStamp
        env.portfolio.update(color) { $0.notes = "Updated" }
        #expect(color.notes == "Updated")
        #expect(color.updatedOnDeviceName == "Preview Device")
        #expect(env.portfolio.changeStamp > before)
    }

    @Test func deleteColorClearsActiveSelection() {
        let env = PreviewEnvironment()
        let color = env.moss
        env.portfolio.activeColorID = color.id
        #expect(env.portfolio.activeColor?.id == color.id)
        env.portfolio.delete(color)
        #expect(env.portfolio.activeColorID == nil)
        #expect(!env.portfolio.colors.contains { $0.id == color.id })
        #expect(env.portfolio.colors.count == 8)
    }

    @Test func moveIntoPaletteAndBackToLoose() {
        let env = PreviewEnvironment()
        let color = env.moss
        let palette = env.sample
        env.portfolio.move(color, to: palette)
        #expect(color.palette?.id == palette.id)
        #expect(env.portfolio.colors(in: palette).count == 7)
        env.portfolio.move(color, to: nil)
        #expect(color.palette == nil)
        #expect(env.portfolio.looseColors.contains { $0.id == color.id })
    }

    @Test func createPalettePrependsToTheUsersOrder() {
        let env = PreviewEnvironment()
        let palette = env.portfolio.createPalette(name: "Autumn", tags: ["warm"])
        #expect(palette != nil)
        #expect(env.portfolio.orderedPalettes.first?.id == palette?.id)
        #expect(env.portfolio.paletteOrder.ids.first == palette?.id)
        #expect(PaletteOrder.load(from: env.defaults).ids.first == palette?.id)
    }

    @Test func freeTierStopsAtTheLimitAndRoutesToThePaywall() {
        let env = PreviewEnvironment(hasOnyx: false)
        var created = 0
        for index in 0..<OnyxGate.freePaletteLimit {
            if env.portfolio.createPalette(name: "Palette \(index)") != nil { created += 1 }
        }
        // One sample palette was already there, so the limit is reached one short.
        #expect(created == OnyxGate.freePaletteLimit - 1)
        #expect(env.portfolio.palettes.count == OnyxGate.freePaletteLimit)
        #expect(env.toastManager.currentToast?.style == .error)
        #expect(env.toastManager.currentToast?.actionTitle == "Get Onyx")
        #expect(!env.isShowingPaywall)
        env.toastManager.currentToast?.action?()
        #expect(env.isShowingPaywall)
    }

    @Test func onyxLiftsThePaletteLimit() {
        let env = PreviewEnvironment(hasOnyx: true)
        for index in 0..<(OnyxGate.freePaletteLimit + 2) {
            #expect(env.portfolio.createPalette(name: "Palette \(index)") != nil)
        }
        #expect(env.portfolio.palettes.count == OnyxGate.freePaletteLimit + 3)
        #expect(env.toastManager.currentToast == nil)
    }

    @Test func movePalettesPersistsTheOrder() {
        let env = PreviewEnvironment()
        let a = env.portfolio.createPalette(name: "A")!
        let b = env.portfolio.createPalette(name: "B")!
        #expect(env.portfolio.orderedPalettes.map(\.id) == [b.id, a.id, env.sample.id])
        env.portfolio.movePalettes(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        #expect(env.portfolio.orderedPalettes.map(\.id) == [env.sample.id, b.id, a.id])
        #expect(PaletteOrder.load(from: env.defaults).ids == [env.sample.id, b.id, a.id])
        env.portfolio.reorderPalettes([a.id, b.id, env.sample.id])
        #expect(env.portfolio.orderedPalettes.map(\.id) == [a.id, b.id, env.sample.id])
    }

    @Test func archivingLeavesTheActiveOrder() {
        let env = PreviewEnvironment()
        let palette = env.sample
        env.portfolio.setArchived(palette, true)
        #expect(env.portfolio.activePalettes.isEmpty)
        #expect(env.portfolio.archivedPalettes.count == 1)
        #expect(env.portfolio.orderedPalettes.isEmpty)
        env.portfolio.setArchived(palette, false)
        #expect(env.portfolio.orderedPalettes.count == 1)
    }

    @Test func deletePaletteKeepsOrDeletesItsColors() {
        let keep = PreviewEnvironment()
        keep.portfolio.activePaletteID = keep.sample.id
        keep.portfolio.delete(keep.sample, deleteColors: false)
        #expect(keep.portfolio.palettes.isEmpty)
        #expect(keep.portfolio.activePaletteID == nil)
        #expect(keep.portfolio.looseColors.count == 9)
        #expect(keep.portfolio.paletteOrder.ids.isEmpty)

        let wipe = PreviewEnvironment()
        wipe.portfolio.delete(wipe.sample, deleteColors: true)
        #expect(wipe.portfolio.colors.count == 3)
    }

    @Test func linkAndUnlinkCanvas() {
        let env = PreviewEnvironment()
        let canvas = env.canvases.canvases.first!
        env.portfolio.link(canvas, to: env.sample)
        #expect(env.sample.canvasFile?.id == canvas.id)
        #expect(canvas.palette?.id == env.sample.id)
        env.portfolio.link(nil, to: env.sample)
        #expect(env.sample.canvasFile == nil)
    }

    @Test func authorNameFallsBackToAnonymousAndPersists() {
        let env = PreviewEnvironment()
        env.portfolio.setAuthorName("  Ada  ")
        #expect(env.portfolio.authorName == "Ada")
        #expect(env.defaults.string(forKey: AppStorageKeys.userName) == "Ada")
        #expect(env.portfolio.authorship.displayName == "Ada")
        #expect(env.portfolio.authorship.deviceName == "Preview Device")
        env.portfolio.setAuthorName("   ")
        #expect(env.portfolio.authorName == Authorship.anonymous.displayName)
    }

    @Test func externalWritesArriveOverTheChangeStream() async throws {
        let env = PreviewEnvironment(seeded: false)
        let color = OpaliteColor(name: "From iCloud", red: 0.1, green: 0.2, blue: 0.3)
        try env.colorRepository.insert(color, authorship: .anonymous)
        let arrived = await eventually { env.portfolio.colors.contains { $0.id == color.id } }
        #expect(arrived)
    }
}

// MARK: - Canvases

@Suite("CanvasModel")
struct CanvasModelTests {
    @Test func seededCanvasesAreAlphabetical() {
        let env = PreviewEnvironment()
        #expect(env.canvases.canvases.map(\.title) == ["Ideas", "Sketch"])
    }

    @Test func createStagesTheNewCanvasForOpening() {
        let env = PreviewEnvironment()
        let canvas = env.canvases.createCanvas(title: "Poster")
        #expect(canvas != nil)
        #expect(env.canvases.pendingCanvasID == canvas?.id)
        #expect(env.canvases.canvases.count == 3)
        #expect(canvas?.lastEditedDeviceName == "Preview Device")
    }

    @Test func freeTierAllowsOneCanvasThenRoutesToThePaywall() {
        let env = PreviewEnvironment(hasOnyx: false, seeded: false)
        #expect(env.canvases.canCreateCanvas)
        #expect(env.canvases.createCanvas(title: "First") != nil)
        #expect(!env.canvases.canCreateCanvas)
        #expect(env.canvases.createCanvas(title: "Second") == nil)
        #expect(env.canvases.canvases.count == 1)
        #expect(env.toastManager.currentToast?.actionTitle == "Get Onyx")
        env.toastManager.currentToast?.action?()
        #expect(env.isShowingPaywall)
    }

    @Test func freeTierOpensOnlyTheOldestCanvas() {
        let env = PreviewEnvironment(hasOnyx: false, seeded: false)
        let old = CanvasFile(title: "Old")
        old.createdAt = Date(timeIntervalSinceNow: -3_600)
        let new = CanvasFile(title: "New")
        env.canvasRepository.storage = [old, new]
        env.canvases.refresh()

        #expect(env.canvases.oldestCanvas?.id == old.id)
        #expect(env.canvases.canAccess(old))
        #expect(!env.canvases.canAccess(new))

        env.canvases.requestOpen(new)
        #expect(env.canvases.pendingCanvasID == nil)
        #expect(env.isShowingPaywall)

        env.canvases.requestOpen(old)
        #expect(env.canvases.pendingCanvasID == old.id)
    }

    @Test func onyxOpensAnyCanvas() {
        let env = PreviewEnvironment(hasOnyx: true)
        for canvas in env.canvases.canvases { #expect(env.canvases.canAccess(canvas)) }
    }

    @Test func renameTrimsAndIgnoresBlank() {
        let env = PreviewEnvironment()
        let canvas = env.canvases.canvases.first!
        env.canvases.rename(canvas, to: "  Mood Board ")
        #expect(canvas.title == "Mood Board")
        env.canvases.rename(canvas, to: "  ")
        #expect(canvas.title == "Mood Board")
    }

    @Test func deleteClearsThePendingCanvas() {
        let env = PreviewEnvironment()
        let canvas = env.canvases.canvases.first!
        env.canvases.pendingCanvasID = canvas.id
        env.canvases.delete(canvas)
        #expect(env.canvases.pendingCanvasID == nil)
        #expect(env.canvases.canvases.count == 1)
        #expect(env.canvases.canvas(withID: canvas.id) == nil)
    }
}

// MARK: - Hex copy

@Suite("HexCopyModel")
struct HexCopyModelTests {
    @Test func firstCopyAsksForThePrefixPreference() {
        let env = PreviewEnvironment()
        env.hexCopy.copy(hex: "#FF0000")
        #expect(env.hexCopy.isAskingPreference)
        #expect(env.hexCopy.pendingHex == "#FF0000")
        #expect(env.pasteboard.strings.isEmpty)

        env.hexCopy.choosePrefix(false)
        #expect(!env.hexCopy.isAskingPreference)
        #expect(env.hexCopy.pendingHex == nil)
        #expect(env.pasteboard.strings == ["FF0000"])
        #expect(env.toastManager.currentToast?.message == "Copied FF0000")
        #expect(env.defaults.bool(forKey: AppStorageKeys.hasAskedHexPreference))
        #expect(!env.hexCopy.includesPrefix)
    }

    @Test func laterCopiesUseTheStoredFormat() {
        let env = PreviewEnvironment()
        env.hexCopy.copy(hex: "#FF0000")
        env.hexCopy.choosePrefix(true)
        env.hexCopy.copy(hex: "00FF00")
        #expect(env.pasteboard.strings == ["#FF0000", "#00FF00"])
        #expect(env.hexCopy.formatted("ABCDEF") == "#ABCDEF")
        env.hexCopy.includesPrefix = false
        #expect(env.hexCopy.formatted("#ABCDEF") == "ABCDEF")
        #expect(env.hexCopy.formatted(env.moss) == String(env.moss.hexString.dropFirst()))
    }

    @Test func copyingTextToastsWithTheLabel() {
        let env = PreviewEnvironment()
        env.hexCopy.copy(text: "rgb(10, 20, 30)", label: "RGB")
        #expect(env.pasteboard.strings == ["rgb(10, 20, 30)"])
        #expect(env.toastManager.currentToast?.message == "Copied RGB")
        #expect(env.toastManager.currentToast?.style == .success)
    }

    @Test func copiesAreDonatedToSiri() {
        let donor = RecordingIntentDonor()
        let toasts = ToastManager()
        let defaults = FakeKeyValueStore()
        defaults.set(true, forKey: AppStorageKeys.hasAskedHexPreference)
        let model = HexCopyModel(defaults: defaults, pasteboard: FakePasteboard(), toastManager: toasts, donor: donor)
        model.copy(hex: "#123456")
        #expect(donor.donated == [.copyHex])
    }
}

// MARK: - Import

@Suite("ImportModel")
struct ImportModelTests {
    @Test func nonOpaliteURLsAreNotHandled() {
        let env = PreviewEnvironment()
        let handled = env.importer.handleIncomingURL(URL(fileURLWithPath: "/tmp/photo.png"), portfolio: env.portfolio)
        #expect(!handled)
        #expect(env.importer.pendingColorImport == nil)
    }

    @Test func colorFileStagesAPreviewAndConfirmInserts() throws {
        let env = PreviewEnvironment()
        let incoming = OpaliteColor(name: "Teal", notes: "Sea", red: 0, green: 0.5, blue: 0.5)
        let url = try makeTemporaryFile(try incoming.jsonRepresentation(), extension: OpaliteFileType.colorExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(env.importer.handleIncomingURL(url, portfolio: env.portfolio))
        #expect(env.importer.isShowingColorImport)
        #expect(env.importer.pendingColorImport?.willSkip == false)
        #expect(env.importer.pendingColorImport?.color.name == "Teal")

        env.importer.confirmColorImport(into: env.portfolio)
        #expect(!env.importer.isShowingColorImport)
        #expect(env.portfolio.color(withID: incoming.id)?.name == "Teal")
        #expect(env.toastManager.currentToast?.message == "Imported Teal")
    }

    @Test func duplicateColorIsSkippedWithAnInfoToast() throws {
        let env = PreviewEnvironment()
        let existing = env.moss
        let url = try makeTemporaryFile(try existing.jsonRepresentation(), extension: OpaliteFileType.colorExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        env.importer.handleIncomingURL(url, portfolio: env.portfolio)
        #expect(env.importer.pendingColorImport?.willSkip == true)
        let before = env.portfolio.colors.count
        env.importer.confirmColorImport(into: env.portfolio)
        #expect(env.portfolio.colors.count == before)
        #expect(env.toastManager.currentToast?.style == .info)
    }

    @Test func newPaletteFileInsertsPaletteAndColors() throws {
        let env = PreviewEnvironment()
        let palette = OpalitePalette(name: "Harbor", tags: ["cool"], colors: [
            OpaliteColor(name: "Fog", red: 0.8, green: 0.8, blue: 0.85),
            OpaliteColor(name: "Deep", red: 0.1, green: 0.2, blue: 0.4),
        ])
        let url = try makeTemporaryFile(try palette.jsonRepresentation(), extension: OpaliteFileType.paletteExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(env.importer.handleIncomingURL(url, portfolio: env.portfolio))
        #expect(env.importer.pendingPaletteImport?.willUpdate == false)
        #expect(env.importer.pendingPaletteImport?.newColors.count == 2)

        env.importer.confirmPaletteImport(into: env.portfolio)
        let imported = env.portfolio.palette(withID: palette.id)
        #expect(imported?.name == "Harbor")
        #expect(imported?.tags == ["cool"])
        #expect(env.portfolio.colors(in: imported!).count == 2)
        #expect(env.portfolio.orderedPalettes.first?.id == palette.id)
        #expect(env.toastManager.currentToast?.message == "Imported Harbor")
    }

    @Test func existingPaletteFileUpdatesMetadataAndAddsNewColors() throws {
        let env = PreviewEnvironment()
        let existing = env.sample
        var json = existing.dictionaryRepresentation
        json["name"] = "Sample Palette (Renamed)"
        var colors = json["colors"] as? [[String: Any]] ?? []
        colors.append(OpaliteColor(name: "Extra", red: 0.3, green: 0.3, blue: 0.3).dictionaryRepresentation)
        json["colors"] = colors
        let data = try JSONSerialization.data(withJSONObject: json)
        let url = try makeTemporaryFile(data, extension: OpaliteFileType.paletteExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        env.importer.handleIncomingURL(url, portfolio: env.portfolio)
        #expect(env.importer.pendingPaletteImport?.willUpdate == true)
        #expect(env.importer.pendingPaletteImport?.newColors.count == 1)
        #expect(env.importer.pendingPaletteImport?.existingColorIDs.count == 6)

        env.importer.confirmPaletteImport(into: env.portfolio)
        #expect(existing.name == "Sample Palette (Renamed)")
        #expect(env.portfolio.colors(in: existing).count == 7)
        #expect(env.portfolio.palettes.count == 1)
        #expect(env.toastManager.currentToast?.message == "Updated Sample Palette (Renamed)")
    }

    @Test func malformedFileSurfacesAnError() throws {
        let env = PreviewEnvironment()
        let url = try makeTemporaryFile(Data("not json".utf8), extension: OpaliteFileType.colorExtension)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(env.importer.handleIncomingURL(url, portfolio: env.portfolio))
        #expect(env.importer.isShowingError)
        #expect(env.importer.importError == .invalidFormat)
        env.importer.isShowingError = false
        #expect(env.importer.importError == nil)
    }
}

// MARK: - Community

@Suite("CommunityModel")
struct CommunityModelTests {
    @Test func loadsTheFeedFromTheService() async {
        let env = PreviewEnvironment()
        await env.community.loadColors()
        #expect(env.community.colors.count == 2)
        #expect(!env.community.hasMoreColors)
        await env.community.loadPalettes()
        #expect(env.community.palettes.count == 1)
        #expect(env.community.palettes.first?.hasLoadedColors == true)
        #expect(env.community.error == nil)
        #expect(!env.community.isLoading)
    }

    @Test func identityDistinguishesMineFromOthers() async {
        let env = PreviewEnvironment()
        await env.community.refreshIdentity()
        #expect(env.community.isUserSignedIn)
        #expect(env.community.isMine(CommunityColor.sample))
        #expect(!env.community.isMine(CommunityColor.sample2))
        #expect(env.community.isMine(CommunityPalette.sample))
    }

    @Test func fetchFailuresAreKeptNotToasted() async {
        let env = PreviewEnvironment()
        env.communityService.failure = .communityOffline
        await env.community.loadColors()
        #expect(env.community.error == .communityOffline)
        #expect(env.community.colors.isEmpty)
        #expect(env.toastManager.currentToast == nil)
    }

    @Test func searchFiltersLocallyAndClearsBack() async {
        let env = PreviewEnvironment()
        await env.community.search("ocean")
        #expect(env.community.isShowingSearchResults)
        #expect(env.community.colors.map(\.name) == ["Ocean Blue"])
        #expect(!env.community.hasMoreColors)

        await env.community.search("sunset")
        #expect(env.community.colors.map(\.name) == ["Sunset Orange"])
        #expect(env.community.palettes.map(\.name) == ["Sunset Vibes"])

        await env.community.search("   ")
        #expect(!env.community.isShowingSearchResults)
        #expect(env.community.colors.count == 2)
    }

    @Test func resortReordersTheCachedFeed() async {
        let env = PreviewEnvironment()
        await env.community.loadColors()
        env.community.resort(.oldest)
        #expect(env.community.sortOption == .oldest)
        #expect(env.community.colors == CommunitySortOption.oldest.sort(env.community.colors))
    }

    @Test func publishingAColorRecordsAndPrepends() async {
        let env = PreviewEnvironment()
        await env.community.loadColors()
        let color = OpaliteColor(name: "Teal", red: 0, green: 0.5, blue: 0.5)
        let ok = await env.community.publish(color)
        #expect(ok)
        #expect(env.communityService.publishedColors.map(\.originalColorID) == [color.id])
        #expect(env.community.colors.first?.name == "Teal")
        #expect(env.community.colors.first?.publisherName == "Preview User")
        #expect(env.toastManager.currentToast?.message == "Published to the Community")
    }

    @Test func publishingAPalettePublishesItsColors() async {
        let env = PreviewEnvironment()
        let ok = await env.community.publish(env.sample, previewImagePNG: nil)
        #expect(ok)
        #expect(env.communityService.publishedPalettes.count == 1)
        #expect(env.communityService.publishedPalettes.first?.colors.count == 6)
        #expect(env.community.palettes.first?.name == "Sample Palette")
        #expect(env.community.palettes.first?.colorCount == 6)
    }

    @Test func publishingNeedsAConnection() async {
        let env = PreviewEnvironment()
        let offline = CommunityModel(service: env.communityService, entitlements: env.entitlements, toastManager: env.toastManager, publisherName: "Preview User", isOnline: { false })
        #expect(!offline.isConnected)
        let ok = await offline.publish(env.moss)
        #expect(!ok)
        #expect(env.communityService.publishedColors.isEmpty)
        #expect(env.toastManager.currentToast?.message == OpaliteError.communityOffline.errorDescription)
    }

    @Test func publishingNeedsASignedInUser() async {
        let env = PreviewEnvironment()
        env.communityService.userID = nil
        let model = CommunityModel(service: env.communityService, entitlements: env.entitlements, toastManager: env.toastManager, publisherName: "Preview User")
        let ok = await model.publish(env.moss)
        #expect(!ok)
        #expect(!model.canPublish)
        #expect(env.toastManager.currentToast?.message == OpaliteError.communityNotSignedIn.errorDescription)
    }

    @Test func publishingIsRateLimitedPerHour() async {
        let env = PreviewEnvironment()
        for _ in 0..<PublishRateLimiter.maxPublishesPerHour {
            #expect(await env.community.publish(env.moss))
        }
        #expect(!env.community.canPublish)
        let ok = await env.community.publish(env.moss)
        #expect(!ok)
        #expect(env.toastManager.currentToast?.message == OpaliteError.communityRateLimited.errorDescription)
    }

    @Test func unpublishRemovesFromTheFeed() async {
        let env = PreviewEnvironment()
        await env.community.loadColors()
        await env.community.unpublish(CommunityColor.sample)
        #expect(!env.community.colors.contains { $0.id == CommunityColor.sample.id })
        #expect(!env.communityService.colors.contains { $0.id == CommunityColor.sample.id })
        #expect(env.toastManager.currentToast?.style == .success)
    }

    @Test func reportsCountUpAndHideAtTheThreshold() async {
        let env = PreviewEnvironment()
        await env.community.loadColors()
        let id = CommunityColor.sample.id
        for _ in 0..<Int(CommunityModeration.autoHideThreshold - 1) {
            #expect(await env.community.report(id: id, type: .color, reason: .spam, details: nil))
        }
        #expect(env.community.colors.first { $0.id == id }?.reportCount == CommunityModeration.autoHideThreshold - 1)
        #expect(await env.community.report(id: id, type: .color, reason: .spam, details: "Final"))
        #expect(!env.community.colors.contains { $0.id == id })
        #expect(env.communityService.reports.count == Int(CommunityModeration.autoHideThreshold))
    }

    @Test func savingAColorRequiresOnyx() {
        let env = PreviewEnvironment(hasOnyx: false)
        let saved = env.community.save(.sample, into: env.portfolio, router: env.router)
        #expect(!saved)
        #expect(env.toastManager.currentToast?.actionTitle == "Get Onyx")
        env.toastManager.currentToast?.action?()
        #expect(env.isShowingPaywall)
        #expect(!env.portfolio.colors.contains { $0.id == CommunityColor.sample.originalColorID })
    }

    @Test func savingAColorKeepsItsOriginalIDAndRejectsDuplicates() {
        let env = PreviewEnvironment(hasOnyx: true)
        #expect(env.community.save(.sample, into: env.portfolio, router: env.router))
        let saved = env.portfolio.color(withID: CommunityColor.sample.originalColorID)
        #expect(saved?.name == "Ocean Blue")
        #expect(saved?.createdByDisplayName == "Sample User")
        #expect(env.toastManager.currentToast?.message == "Saved to your Portfolio")

        #expect(!env.community.save(.sample, into: env.portfolio, router: env.router))
        #expect(env.toastManager.currentToast?.message == OpaliteError.communityColorAlreadyExists.errorDescription)
        #expect(env.portfolio.colors.filter { $0.id == CommunityColor.sample.originalColorID }.count == 1)
    }

    @Test func savingAPaletteBringsItsColors() async {
        let env = PreviewEnvironment(hasOnyx: true)
        let saved = await env.community.save(CommunityPalette.sample, into: env.portfolio, router: env.router)
        #expect(saved)
        let palette = env.portfolio.palette(withID: CommunityPalette.sample.originalPaletteID)
        #expect(palette?.name == "Sunset Vibes")
        #expect(palette?.tags == ["warm", "sunset", "summer"])
        #expect(env.portfolio.colors(in: palette!).count == 2)
        let again = await env.community.save(CommunityPalette.sample, into: env.portfolio, router: env.router)
        #expect(!again)
        #expect(env.toastManager.currentToast?.message == OpaliteError.communityPaletteAlreadyExists.errorDescription)
    }

    @Test func moderationRemovesAndClears() async {
        let env = PreviewEnvironment()
        await env.community.loadColors()
        let id = CommunityColor.sample2.id
        _ = await env.community.report(id: id, type: .color, reason: .other, details: nil)
        let reported = await env.community.reportedContent()
        #expect(reported.colors.map(\.id) == [id])
        #expect(await env.community.clearReports(id: id))
        #expect(await env.community.reportedContent().colors.isEmpty)
        #expect(await env.community.removeEntity(id: id, type: .color))
        #expect(!env.community.colors.contains { $0.id == id })
        #expect(!env.communityService.colors.contains { $0.id == id })
    }
}
