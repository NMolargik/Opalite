//
//  PortfolioStatusSyncTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("PortfolioStatusSync")
struct PortfolioStatusSyncTests {
    @MainActor
    final class Harness {
        let center = PortfolioChangeCenter()
        let colors: FakeColorRepository
        let palettes: FakePaletteRepository
        let defaults = FakeKeyValueStore()
        let widgets = FakeWidgetReloader()
        let watch = FakeWatchPusher()
        let indexer = FakeIndexer()
        let vocabulary = FakeVocabulary()
        let sync: PortfolioStatusSync

        init(debounce: Duration = .milliseconds(60)) {
            colors = FakeColorRepository(changeCenter: center, colors: [OpaliteColor(name: "One", red: 1, green: 0, blue: 0)])
            palettes = FakePaletteRepository(changeCenter: center, palettes: [OpalitePalette(name: "P")])
            sync = PortfolioStatusSync(
                loadColors: LoadColorsUseCase(repository: colors),
                loadPalettes: LoadPalettesUseCase(repository: palettes),
                observeChanges: ObservePortfolioChangesUseCase(center: center),
                widgetStorage: WidgetColorStorage(defaults: defaults),
                widgets: widgets,
                watch: watch,
                indexer: indexer,
                vocabulary: vocabulary,
                debounce: debounce
            )
        }

        /// Starts observing and waits for the subscription to be live.
        func start() async {
            sync.start()
            _ = await waitUntil { self.center.subscriberCount == 1 }
        }
    }

    @Test func startPushesToEveryMirrorImmediately() async {
        let h = Harness()
        await h.start()
        #expect(h.widgets.reloadAllCount == 1)
        #expect(h.watch.snapshots.count == 1)
        #expect(h.watch.snapshots.first?.colors.map(\.name) == ["One"])
        #expect(h.watch.snapshots.first?.palettes.map(\.name) == ["P"])
        #expect(h.indexer.reindexCount == 1 && h.indexer.lastColorCount == 1 && h.indexer.lastPaletteCount == 1)
        #expect(h.vocabulary.updateCount == 1)
        #expect(WidgetColorStorage(defaults: h.defaults).loadColors().map(\.name) == ["One"])
    }

    @Test func startTwiceOnlySubscribesOnce() async {
        let h = Harness()
        await h.start()
        h.sync.start()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(h.center.subscriberCount == 1)
        #expect(h.watch.snapshots.count == 2, "each start pushes, but only one observer")
    }

    @Test func burstOfChangesCoalescesIntoOnePush() async throws {
        let h = Harness()
        await h.start()
        let repoColors = h.colors
        let authorship = Authorship(displayName: "T")
        try repoColors.insert(OpaliteColor(name: "Two", red: 0, green: 1, blue: 0), authorship: authorship)
        try repoColors.insert(OpaliteColor(name: "Three", red: 0, green: 0, blue: 1), authorship: authorship)
        try repoColors.insert(OpaliteColor(name: "Four", red: 0, green: 0, blue: 0), authorship: authorship)
        #expect(h.watch.snapshots.count == 1, "nothing pushes before the debounce elapses")
        #expect(await waitUntil { h.watch.snapshots.count == 2 })
        try? await Task.sleep(for: .milliseconds(150))
        #expect(h.watch.snapshots.count == 2)
        #expect(h.watch.snapshots.last?.colors.count == 4)
        #expect(h.widgets.reloadAllCount == 2)
        #expect(WidgetColorStorage(defaults: h.defaults).loadColors().count == 4)
    }

    @Test func unchangedDataIsNotPushedAgain() async {
        let h = Harness()
        await h.start()
        h.center.notify(.colorUpdated(UUID()))
        h.center.notify(.bulk)
        try? await Task.sleep(for: .milliseconds(200))
        #expect(h.watch.snapshots.count == 1)
        #expect(h.indexer.reindexCount == 1)
    }

    @Test func canvasChangesDoNotTriggerAPush() async throws {
        let h = Harness()
        await h.start()
        h.center.notify(.canvasCreated(UUID()))
        try h.colors.insert(OpaliteColor(name: "Hidden", red: 0.5, green: 0.5, blue: 0.5), authorship: .anonymous)
        h.colors.storage.removeAll { $0.name == "Hidden" }
        // The color insert notified, but by the time the debounce fires the data is back to the original.
        try? await Task.sleep(for: .milliseconds(200))
        #expect(h.watch.snapshots.count == 1)
    }

    @Test func renamingAColorChangesTheFingerprint() async throws {
        let h = Harness()
        await h.start()
        let color = h.colors.storage[0]
        try h.colors.update(color, authorship: .anonymous) { $0.name = "Renamed" }
        #expect(await waitUntil { h.watch.snapshots.count == 2 })
        #expect(h.watch.snapshots.last?.colors.first?.name == "Renamed")
    }

    @Test func pushNowIsUnconditional() async {
        let h = Harness()
        await h.start()
        h.sync.pushNow()
        h.sync.pushNow()
        #expect(h.watch.snapshots.count == 3)
        #expect(h.vocabulary.updateCount == 3)
    }

    @Test func currentSnapshotReflectsTheStore() {
        let h = Harness()
        let snapshot = h.sync.currentSnapshot()
        #expect(snapshot.colors.count == 1 && snapshot.palettes.count == 1)
        h.colors.failure = .fetchFailed("x")
        #expect(h.sync.currentSnapshot() == .empty)
    }

    @Test func loadFailuresDoNotPush() {
        let h = Harness()
        h.palettes.failure = .fetchFailed("x")
        h.sync.pushNow()
        #expect(h.watch.snapshots.isEmpty)
        #expect(h.widgets.reloadAllCount == 0)
    }

    @Test func fingerprintCoversTheMirroredFields() {
        let palette = OpalitePalette(name: "P")
        let color = OpaliteColor(name: "C", red: 1, green: 0, blue: 0)
        let base = PortfolioStatusSync.fingerprint(colors: [color], palettes: [palette])
        #expect(base.count == 2)
        color.name = "D"
        #expect(PortfolioStatusSync.fingerprint(colors: [color], palettes: [palette]) != base)
        let archived = PortfolioStatusSync.fingerprint(colors: [], palettes: [palette])
        palette.isArchived = true
        #expect(PortfolioStatusSync.fingerprint(colors: [], palettes: [palette]) != archived)
        #expect(PortfolioStatusSync.fingerprint(colors: [], palettes: []).isEmpty)
    }
}
