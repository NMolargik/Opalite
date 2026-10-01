//
//  StorageTests.swift
//  OpaliteCoreTests
//
//  WidgetColorStorage, SharedImageStore, AppGroup/AppStorageKeys.
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("WidgetColorStorage")
struct WidgetColorStorageTests {
    let colors = [
        WidgetColor(id: UUID(), name: "Ocean", red: 0.2, green: 0.5, blue: 0.8, alpha: 1),
        WidgetColor(id: UUID(), name: nil, red: 0, green: 0, blue: 1, alpha: 0.5),
    ]

    @Test func emptyStoreLoadsNothing() {
        let storage = WidgetColorStorage(defaults: FakeKeyValueStore())
        #expect(storage.loadColors().isEmpty)
        #expect(storage.randomColor() == .placeholder)
    }

    @Test func saveThenLoadRoundTrips() {
        let store = FakeKeyValueStore()
        let storage = WidgetColorStorage(defaults: store)
        storage.saveColors(colors)
        #expect(store.data(forKey: WidgetColorStorage.colorsKey) != nil)
        #expect(storage.loadColors() == colors)
        #expect(colors.contains(storage.randomColor()))
    }

    @Test func savingReplacesThePreviousSnapshot() {
        let storage = WidgetColorStorage(defaults: FakeKeyValueStore())
        storage.saveColors(colors)
        storage.saveColors([])
        #expect(storage.loadColors().isEmpty)
    }

    @Test func corruptDataLoadsAsEmpty() {
        let store = FakeKeyValueStore()
        store.set(Data("nope".utf8), forKey: WidgetColorStorage.colorsKey)
        #expect(WidgetColorStorage(defaults: store).loadColors().isEmpty)
    }

    @Test func missingSuiteIsHarmless() {
        let storage = WidgetColorStorage(defaults: nil)
        storage.saveColors(colors)
        #expect(storage.loadColors().isEmpty)
        #expect(storage.randomColor() == .placeholder)
    }

    @Test func widgetColorHelpers() {
        #expect(colors[0].displayName == "Ocean")
        #expect(colors[1].displayName == "#0000FF")
        #expect(colors[0].hexString == "#3380CC")
        #expect(!colors[1].prefersDarkText)
        #expect(WidgetColor(id: UUID(), name: nil, red: 1, green: 1, blue: 1, alpha: 1).prefersDarkText)
        #expect(WidgetColor.placeholder.name == "No Colors Yet")
        #expect(WidgetKind.randomColor == "RandomColorWidget")
    }

    @Test func widgetColorCodable() throws {
        let data = try JSONEncoder().encode(colors)
        #expect(try JSONDecoder().decode([WidgetColor].self, from: data) == colors)
    }
}

@Suite("SharedImageStore")
struct SharedImageStoreTests {
    private func temporaryDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "opalite-shared-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func lifecycle() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SharedImageStore(containerURL: dir)
        #expect(store.fileURL == dir.appendingPathComponent(SharedImageStore.fileName))
        #expect(!store.hasSharedImage)
        #expect(store.load() == nil)

        let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
        #expect(store.save(pngData: png))
        #expect(store.hasSharedImage)
        #expect(store.load() == png)

        let replacement = Data([0x89, 0x50])
        #expect(store.save(pngData: replacement))
        #expect(store.load() == replacement)

        store.clear()
        #expect(!store.hasSharedImage)
        #expect(store.load() == nil)
        store.clear()
    }

    @Test func missingContainerFailsSoftly() {
        let store = SharedImageStore(containerURL: nil)
        #expect(store.fileURL == nil)
        #expect(!store.hasSharedImage)
        #expect(!store.save(pngData: Data([1])))
        #expect(store.load() == nil)
        store.clear()
    }

    @Test func unwritableContainerReportsFailure() {
        let store = SharedImageStore(containerURL: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/dir"))
        #expect(!store.save(pngData: Data([1])))
    }
}

@Suite("App group & storage keys")
struct AppGroupTests {
    @Test func shippingIdentifiersAreStable() {
        #expect(AppGroup.id == "group.com.molargiksoftware.Opalite")
        #expect(AppGroup.cloudKitContainerID == "iCloud.com.molargiksoftware.Opalite")
        #expect(AppGroup.bundleID == "com.molargiksoftware.Opalite")
    }

    @Test func storageKeysAreUniqueStrings() {
        let keys = [
            AppStorageKeys.isOnboardingComplete, AppStorageKeys.lastReviewRequestVersion, AppStorageKeys.hasPromptedForCommunityName,
            AppStorageKeys.userName, AppStorageKeys.appTheme, AppStorageKeys.appIcon, AppStorageKeys.colorBlindnessMode,
            AppStorageKeys.swatchSize, AppStorageKeys.paletteOrder, AppStorageKeys.includeHexPrefix, AppStorageKeys.hasAskedHexPreference,
            AppStorageKeys.hasSetHexPrefixDefault, AppStorageKeys.skipSwatchBarConfirmation, AppStorageKeys.lastWatchSyncTimestamp,
            AppStorageKeys.lastWatchSyncColorCount, AppStorageKeys.lastWatchSyncPaletteCount, AppStorageKeys.pendingWatchHexCopy,
            AppStorageKeys.watchHighContrastEnabled,
        ]
        #expect(Set(keys).count == keys.count)
        #expect(keys.allSatisfy { !$0.isEmpty })
        #expect(AppStorageKeys.paletteOrder == "paletteOrder")
        #expect(AppStorageKeys.userName == "userName")
    }

    @Test func userDefaultsConformsToTheSeam() {
        let suite = "opalite-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store: any KeyValueStoring = defaults
        store.set("v", forKey: "k")
        #expect(store.string(forKey: "k") == "v")
        store.removeObject(forKey: "k")
        #expect(store.object(forKey: "k") == nil)
    }
}
