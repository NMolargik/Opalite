//
//  SessionControllerTests.swift
//  OpaliteCompositionTests
//
//  The composition root over a temporary on-disk store with every app-side seam faked:
//  the graph builds, deep links and Opalite files route, intent hand-offs are consumed on
//  start, Siri's on-screen annotations are stamped, and the free tier is enforced through
//  the use-cases App Intents call.
//

import Foundation
import SwiftData
import Testing
import OpaliteCore
import OpaliteData
import OpaliteFeatureShared
@testable import OpaliteComposition

/// A session over a unique temporary store with fakes behind every seam.
@MainActor
private final class TestSession {
    let container: ModelContainer
    let defaults = FakeKeyValueStore()
    let sharedDefaults = FakeKeyValueStore()
    let pasteboard = FakePasteboard()
    let communityService = FakeCommunityService()
    let session: SessionController

    init() throws {
        container = try OpaliteStore.makeTemporaryContainer()
        session = SessionController(
            container: container,
            defaults: defaults,
            sharedDefaults: sharedDefaults,
            communityService: communityService,
            device: GenericDevice(deviceName: "Test Device"),
            pasteboard: pasteboard,
            widgetReloader: nil,
            statusSyncDebounce: .milliseconds(10)
        )
    }

    deinit {
        if let url = container.configurations.first?.url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private func makeTemporaryFile(_ data: Data, extension ext: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("opalite-composition-tests-\(UUID().uuidString)")
        .appendingPathExtension(ext)
    try data.write(to: url)
    return url
}

@Suite("SessionController", .serialized)
struct SessionControllerTests {
    @Test func graphBuildsOverAnEmptyStore() throws {
        let test = try TestSession()
        let session = test.session
        #expect(session.portfolio.isEmpty)
        #expect(session.canvases.canvases.isEmpty)
        #expect(session.router.selectedTab == .portfolio)
        #expect(session.toastManager.currentToast == nil)
        #expect(try session.loadColors().isEmpty)
        #expect(try session.loadPalettes().isEmpty)
    }

    @Test func intentUseCasesWriteThroughTheSameStoreAsTheModels() throws {
        let test = try TestSession()
        let session = test.session
        let color = try session.createColor(RGBA(red: 0.1, green: 0.2, blue: 0.3), name: "Intent Blue", notes: nil, palette: nil, authorship: session.portfolio.authorship)
        #expect(color.createdOnDeviceName == "Test Device")
        session.portfolio.refresh()
        #expect(session.portfolio.colors.map(\.id) == [color.id])
        #expect(try session.findColor(withID: color.id)?.name == "Intent Blue")
        #expect(session.portfolio.color(withID: color.id)?.name == "Intent Blue")
    }

    @Test func freeTierIsEnforcedForIntentsToo() throws {
        let test = try TestSession()
        let session = test.session
        guard !session.subscriptions.hasOnyx else { return }
        for index in 0..<OnyxGate.freePaletteLimit {
            _ = try session.createPalette(name: "Palette \(index)", notes: nil, tags: [], colors: [], authorship: session.portfolio.authorship)
        }
        #expect(throws: PaletteCreationError.limitReached) {
            try session.createPalette(name: "One too many", notes: nil, tags: [], colors: [], authorship: session.portfolio.authorship)
        }
        session.portfolio.refresh()
        #expect(session.portfolio.palettes.count == OnyxGate.freePaletteLimit)
    }

    @Test func deepLinkURLsRouteThroughTheRouter() throws {
        let test = try TestSession()
        let session = test.session
        #expect(session.handle(url: URL(string: "opalite://community")!))
        #expect(session.router.selectedTab == .community)
        #expect(session.router.takePendingDeepLink() == .community)

        let id = UUID()
        #expect(session.handle(url: DeepLink.color(id).url))
        #expect(session.router.selectedTab == .portfolio)
        #expect(session.router.takePendingDeepLink() == .color(id))

        #expect(!session.handle(url: URL(string: "https://example.com")!))
        #expect(!session.handle(url: URL(fileURLWithPath: "/tmp/photo.png")))
    }

    @Test func opaliteFilesRouteToTheImporter() throws {
        let test = try TestSession()
        let session = test.session
        let color = OpaliteColor(name: "Shared", red: 0.5, green: 0.4, blue: 0.3)
        let url = try makeTemporaryFile(try color.jsonRepresentation(), extension: OpaliteFileType.colorExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(session.handle(url: url))
        #expect(session.importer.pendingColorImport?.color.name == "Shared")
        #expect(session.router.pendingDeepLink == nil)

        session.importer.confirmColorImport(into: session.portfolio)
        #expect(session.portfolio.color(withID: color.id)?.name == "Shared")
    }

    @Test func pendingIntentDeepLinkIsConsumedOnStart() throws {
        let test = try TestSession()
        DeepLink.onyx.storePending(in: test.sharedDefaults)
        #expect(test.sharedDefaults.string(forKey: DeepLink.pendingDefaultsKey) != nil)

        test.session.start()
        #expect(test.session.router.pendingDeepLink == .onyx)
        #expect(test.session.router.selectedTab == .settings)
        #expect(test.sharedDefaults.string(forKey: DeepLink.pendingDefaultsKey) == nil)

        // Calling start again is harmless and consumes nothing new.
        _ = test.session.router.takePendingDeepLink()
        test.session.start()
        #expect(test.session.router.pendingDeepLink == nil)
    }

    @Test func publisherNameFollowsTheProfile() throws {
        let test = try TestSession()
        test.session.portfolio.setAuthorName("Ada")
        test.session.syncPublisherName()
        #expect(test.session.community.publisherName == "Ada")
        #expect(test.defaults.string(forKey: AppStorageKeys.userName) == "Ada")
    }

    @Test func hexCopiesLandOnTheInjectedPasteboard() throws {
        let test = try TestSession()
        test.defaults.set(true, forKey: AppStorageKeys.hasAskedHexPreference)
        HexFormat(includesPrefix: true).save(to: test.defaults)
        test.session.hexCopy.copy(hex: "#336699")
        #expect(test.pasteboard.strings == ["#336699"])
        #expect(test.session.toastManager.currentToast?.message == "Copied #336699")
    }

    @Test func viewingActivitiesCarryTheEntityIdentifiers() throws {
        let test = try TestSession()
        let colorID = UUID()
        let colorActivity = NSUserActivity(activityType: UserActivityType.viewingColor)
        test.session.annotateViewingColor(colorActivity, colorID: colorID)
        #expect(colorActivity.userInfo?["colorID"] as? String == colorID.uuidString)
        #expect(colorActivity.title == "Color")
        #expect(!colorActivity.isEligibleForHandoff)
        #expect(!colorActivity.isEligibleForSearch)

        let paletteID = UUID()
        let paletteActivity = NSUserActivity(activityType: UserActivityType.viewingPalette)
        test.session.annotateViewingPalette(paletteActivity, paletteID: paletteID)
        #expect(paletteActivity.userInfo?["paletteID"] as? String == paletteID.uuidString)
        #expect(paletteActivity.title == "Palette")
    }

    @Test func statusSyncPublishesTheWidgetSnapshotAfterWrites() async throws {
        let test = try TestSession()
        let session = test.session
        session.start()
        _ = session.portfolio.createColor(RGBA(red: 0.9, green: 0.1, blue: 0.1), name: "Widget Red")
        let storage = WidgetColorStorage(defaults: test.sharedDefaults)
        var published = false
        for _ in 0..<50 where !published {
            published = storage.loadColors().contains { $0.name == "Widget Red" }
            if !published { try await Task.sleep(for: .milliseconds(20)) }
        }
        #expect(published)
    }
}

#if os(iOS) || os(visionOS)
@Suite("SwatchBar scene")
struct SwatchBarSceneTests {
    @Test func windowIdentityIsStable() {
        #expect(SwatchBarScene.windowID == "swatchBar")
        #expect(SwatchBarScene.defaultSize.width > 0)
        #expect(SwatchBarScene.defaultSize.height > SwatchBarScene.defaultSize.width)
    }
}
#endif
