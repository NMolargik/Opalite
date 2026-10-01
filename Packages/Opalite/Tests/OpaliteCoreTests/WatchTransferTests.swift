//
//  WatchTransferTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("WatchColor codec")
struct WatchColorCodecTests {
    @Test func roundTripsWithEveryField() throws {
        let paletteID = UUID()
        let color = WatchColor(name: "Ocean", red: 0.2, green: 0.5, blue: 0.8, alpha: 0.75, paletteId: paletteID,
                               createdAt: Date(timeIntervalSince1970: 1000), updatedAt: Date(timeIntervalSince1970: 2000))
        let decoded = try #require(WatchColor(dictionary: color.dictionary))
        #expect(decoded == color)
        #expect(decoded.paletteId == paletteID)
    }

    @Test func nilStringsTravelAsEmptyStrings() throws {
        let color = WatchColor(name: nil, red: 0.1, green: 0.2, blue: 0.3)
        let dict = color.dictionary
        #expect(dict["name"] as? String == "")
        #expect(dict["paletteId"] as? String == "")
        #expect(!dict.values.contains { $0 is NSNull })
        let decoded = try #require(WatchColor(dictionary: dict))
        #expect(decoded.name == nil)
        #expect(decoded.paletteId == nil)
    }

    @Test func rejectsIncompleteDictionaries() {
        #expect(WatchColor(dictionary: [:]) == nil)
        #expect(WatchColor(dictionary: ["id": "nope", "red": 1.0, "green": 1.0, "blue": 1.0]) == nil)
        #expect(WatchColor(dictionary: ["id": UUID().uuidString, "red": 1.0, "green": 1.0]) == nil)
    }

    @Test func defaultsAlphaAndIgnoresBadPaletteID() throws {
        let decoded = try #require(WatchColor(dictionary: ["id": UUID().uuidString, "red": 1.0, "green": 0.0, "blue": 0.0, "paletteId": "garbage"]))
        #expect(decoded.alpha == 1)
        #expect(decoded.paletteId == nil)
    }

    @Test func displayHelpers() {
        let named = WatchColor(name: " Ocean Blue ", red: 0.2, green: 0.5, blue: 0.8)
        #expect(named.displayName == "Ocean Blue", "display name is trimmed")
        #expect(named.voiceOverDescription == "Ocean Blue, #3380CC")
        #expect(named.hexString == "#3380CC")
        let unnamed = WatchColor(name: "   ", red: 1, green: 1, blue: 1)
        #expect(unnamed.displayName == "#FFFFFF")
        #expect(unnamed.voiceOverDescription == "#FFFFFF")
        #expect(unnamed.prefersDarkText)
        #expect(!WatchColor(red: 0, green: 0, blue: 0).prefersDarkText)
    }

    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(WatchColor.samples)
        #expect(try JSONDecoder().decode([WatchColor].self, from: data) == WatchColor.samples)
    }
}

@Suite("WatchPalette codec")
struct WatchPaletteCodecTests {
    @Test func roundTrips() throws {
        let palette = WatchPalette(name: "Sunset", createdAt: Date(timeIntervalSince1970: 10), updatedAt: Date(timeIntervalSince1970: 20))
        #expect(try #require(WatchPalette(dictionary: palette.dictionary)) == palette)
    }

    @Test func rejectsMissingName() {
        #expect(WatchPalette(dictionary: ["id": UUID().uuidString]) == nil)
        #expect(WatchPalette(dictionary: ["name": "x"]) == nil)
    }
}

@Suite("WatchPortfolioSnapshot")
struct WatchSnapshotTests {
    private func makeSnapshot() -> (WatchPortfolioSnapshot, WatchPalette) {
        // Integral timestamps: Date ↔ timeIntervalSince1970 is lossy at sub-microsecond precision.
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let palette = WatchPalette(name: "Sunset", createdAt: stamp, updatedAt: stamp)
        let loose = WatchColor(name: "Loose", red: 0.1, green: 0.2, blue: 0.3, createdAt: stamp, updatedAt: stamp)
        let older = WatchColor(name: "Older", red: 1, green: 0, blue: 0, paletteId: palette.id, createdAt: Date(timeIntervalSince1970: 100), updatedAt: stamp)
        let newer = WatchColor(name: "Newer", red: 0, green: 1, blue: 0, paletteId: palette.id, createdAt: Date(timeIntervalSince1970: 200), updatedAt: stamp)
        return (WatchPortfolioSnapshot(colors: [loose, older, newer], palettes: [palette], timestamp: Date(timeIntervalSince1970: 5000)), palette)
    }

    @Test func payloadRoundTrips() throws {
        let (snapshot, _) = makeSnapshot()
        let payload = snapshot.payload
        #expect((payload[WatchMessageKey.colors] as? [[String: Any]])?.count == 3)
        #expect((payload[WatchMessageKey.palettes] as? [[String: Any]])?.count == 1)
        #expect(payload[WatchMessageKey.action] == nil)
        let decoded = try #require(WatchPortfolioSnapshot(payload: payload))
        #expect(decoded.colors == snapshot.colors)
        #expect(decoded.palettes == snapshot.palettes)
        #expect(decoded.timestamp.timeIntervalSince1970.isClose(to: 5000))
    }

    @Test func messagePayloadCarriesTheAction() {
        let (snapshot, _) = makeSnapshot()
        #expect(snapshot.messagePayload[WatchMessageKey.action] as? String == WatchAction.syncData.rawValue)
        #expect(WatchPortfolioSnapshot(payload: snapshot.messagePayload)?.colors.count == 3)
    }

    @Test func emptyPayloadIsNotASnapshot() {
        #expect(WatchPortfolioSnapshot(payload: [:]) == nil)
        #expect(WatchPortfolioSnapshot(payload: [WatchMessageKey.action: "x"]) == nil)
        let bare = WatchPortfolioSnapshot(payload: [WatchMessageKey.colors: []])
        #expect(bare?.colors.isEmpty == true && bare?.palettes.isEmpty == true)
    }

    @Test func malformedEntriesAreDropped() throws {
        let payload: [String: Any] = [WatchMessageKey.colors: [["id": "bad"], WatchColor.sample.dictionary], WatchMessageKey.palettes: [["name": "no id"]]]
        let decoded = try #require(WatchPortfolioSnapshot(payload: payload))
        #expect(decoded.colors.count == 1 && decoded.palettes.isEmpty)
    }

    @Test func looseColorsAndPaletteColors() {
        let (snapshot, palette) = makeSnapshot()
        #expect(snapshot.looseColors.map(\.name) == ["Loose"])
        #expect(snapshot.colors(in: palette).map(\.name) == ["Newer", "Older"], "newest first")
    }

    @Test func builtFromModels() {
        let palette = OpalitePalette(name: "Models")
        let inPalette = OpaliteColor(name: "In", red: 1, green: 0, blue: 0, alpha: 0.5, palette: palette)
        let loose = OpaliteColor(name: nil, red: 0, green: 0, blue: 1)
        let snapshot = WatchPortfolioSnapshot(models: [inPalette, loose], palettes: [palette])
        #expect(snapshot.palettes.map(\.id) == [palette.id])
        #expect(snapshot.palettes.first?.name == "Models")
        #expect(snapshot.colors.map(\.id) == [inPalette.id, loose.id])
        #expect(snapshot.colors[0].paletteId == palette.id && snapshot.colors[0].alpha == 0.5)
        #expect(snapshot.colors[1].paletteId == nil && snapshot.colors[1].name == nil)
        #expect(snapshot.looseColors.map(\.id) == [loose.id])
    }

    @Test func emptySnapshotIsDistantPast() {
        #expect(WatchPortfolioSnapshot.empty.colors.isEmpty)
        #expect(WatchPortfolioSnapshot.empty.timestamp == .distantPast)
    }
}

@Suite("WatchReply")
struct WatchReplyTests {
    @Test func successWithoutQueueOmitsTheKey() {
        let dict = WatchReply.success(queued: false).dictionary
        #expect(dict[WatchMessageKey.success] as? Bool == true)
        #expect(dict[WatchMessageKey.queued] == nil)
        #expect(WatchReply(dictionary: dict) == .success(queued: false))
    }

    @Test func successQueued() {
        let dict = WatchReply.success(queued: true).dictionary
        #expect(dict[WatchMessageKey.queued] as? Bool == true)
        #expect(WatchReply(dictionary: dict) == .success(queued: true))
    }

    @Test func failureCarriesTheMessage() {
        let dict = WatchReply.failure("Nope").dictionary
        #expect(dict[WatchMessageKey.success] as? Bool == false)
        #expect(dict[WatchMessageKey.error] as? String == "Nope")
        #expect(WatchReply(dictionary: dict) == .failure("Nope"))
    }

    @Test func unknownDictionaryIsAFailure() {
        #expect(WatchReply(dictionary: [:]) == .failure("Unknown error"))
        #expect(WatchReply(dictionary: [WatchMessageKey.success: "yes"]) == .failure("Unknown error"))
    }

    @Test func actionsAndKeys() {
        #expect(WatchAction(rawValue: "requestSync") == .requestSync)
        #expect(WatchAction.copyColorFile.rawValue == "copyColorFile")
        #expect(WatchMessageKey.action == "action" && WatchMessageKey.syncTimestamp == "syncTimestamp")
    }
}

@Suite("WatchSnapshotCache")
struct WatchSnapshotCacheTests {
    @Test func loadIsNilWhenEmpty() {
        #expect(WatchSnapshotCache(defaults: FakeKeyValueStore()).load() == nil)
    }

    @Test func saveThenLoadRoundTrips() throws {
        let store = FakeKeyValueStore()
        let cache = WatchSnapshotCache(defaults: store)
        let snapshot = WatchPortfolioSnapshot(colors: WatchColor.samples, palettes: [.sample], timestamp: Date(timeIntervalSince1970: 123))
        cache.save(snapshot)
        #expect(store.data(forKey: WatchSnapshotCache.colorsKey) != nil)
        #expect(store.data(forKey: WatchSnapshotCache.palettesKey) != nil)
        #expect(store.double(forKey: WatchSnapshotCache.lastSyncKey) == 123)
        let loaded = try #require(cache.load())
        #expect(loaded.colors == snapshot.colors)
        #expect(loaded.palettes == snapshot.palettes)
        #expect(loaded.timestamp.timeIntervalSince1970 == 123)
    }

    @Test func palettesOnlyStillLoads() throws {
        let cache = WatchSnapshotCache(defaults: FakeKeyValueStore())
        cache.save(WatchPortfolioSnapshot(colors: [], palettes: [.sample]))
        let loaded = try #require(cache.load())
        #expect(loaded.colors.isEmpty && loaded.palettes.count == 1)
    }

    @Test func emptySnapshotLoadsAsNil() {
        let cache = WatchSnapshotCache(defaults: FakeKeyValueStore())
        cache.save(.empty)
        #expect(cache.load() == nil)
    }
}
