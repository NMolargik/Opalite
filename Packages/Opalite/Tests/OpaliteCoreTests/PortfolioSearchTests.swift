//
//  PortfolioSearchTests.swift
//  OpaliteCoreTests
//
//  PortfolioSearch, HexFormat, ReviewMilestone.
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("PortfolioSearch")
struct PortfolioSearchTests {
    let navy = RGBA(red: 0, green: 0, blue: 0.4)

    @Test func normalizesWhitespaceAndCase() {
        #expect(PortfolioSearch.normalized("  Dusty ROSE \n") == "dusty rose")
    }

    @Test func colorMatchesNameAndNotes() {
        #expect(PortfolioSearch.matches(name: "Dusty Rose", notes: nil, hex: "#AA6677", rgba: navy, query: "rose"))
        #expect(PortfolioSearch.matches(name: nil, notes: "for the hero banner", hex: "#AA6677", rgba: navy, query: "HERO"))
        #expect(!PortfolioSearch.matches(name: "Dusty Rose", notes: "banner", hex: "#AA6677", rgba: navy, query: "ocean"))
    }

    @Test func colorMatchesHexWithOrWithoutHash() {
        #expect(PortfolioSearch.matches(name: nil, notes: nil, hex: "#FF0000", rgba: navy, query: "ff0000"))
        #expect(PortfolioSearch.matches(name: nil, notes: nil, hex: "#FF0000", rgba: navy, query: "#FF0000"))
        #expect(PortfolioSearch.matches(name: nil, notes: nil, hex: "#FF0000", rgba: navy, query: "ff00"))
        #expect(!PortfolioSearch.matches(name: nil, notes: nil, hex: "#FF0000", rgba: navy, query: "00ff00"))
    }

    @Test func colorMatchesFamilyWords() {
        #expect(PortfolioSearch.matches(name: nil, notes: nil, hex: "#000066", rgba: navy, query: "dark blue"))
        #expect(PortfolioSearch.matches(name: nil, notes: nil, hex: "#000066", rgba: navy, query: "blue"))
        #expect(!PortfolioSearch.matches(name: nil, notes: nil, hex: "#000066", rgba: navy, query: "yellow"))
    }

    @Test func emptyQueriesNeverMatch() {
        #expect(!PortfolioSearch.matches(name: "Anything", notes: nil, hex: "#000000", rgba: navy, query: ""))
        #expect(!PortfolioSearch.matches(name: "Anything", notes: nil, hex: "#000000", rgba: navy, query: "   "))
        #expect(!PortfolioSearch.matches(paletteName: "Anything", notes: nil, tags: ["x"], query: ""))
    }

    @Test func paletteMatchesNameNotesAndTags() {
        #expect(PortfolioSearch.matches(paletteName: "Summer Sunset", notes: nil, tags: [], query: "sunset"))
        #expect(PortfolioSearch.matches(paletteName: "P", notes: "client work", tags: [], query: "Client"))
        #expect(PortfolioSearch.matches(paletteName: "P", notes: nil, tags: ["warm", "Brand"], query: "brand"))
        #expect(!PortfolioSearch.matches(paletteName: "P", notes: nil, tags: ["warm"], query: "cool"))
    }

    struct Item: Equatable { let name: String?; let hex: String? }
    let items = [
        Item(name: "Ocean", hex: "#001122"),
        Item(name: "Ocean Mist", hex: "#334455"),
        Item(name: "Deep Ocean", hex: "#000011"),
        Item(name: "ocean", hex: "#AABBCC"),
        Item(name: nil, hex: "#FF0000"),
        Item(name: "Oatmeal", hex: "#DDDDDD"),
    ]

    private func ranked(_ query: String, limit: Int = 5) -> [Item] {
        PortfolioSearch.rankedNameMatches(items, query: query, name: \.name, hex: \.hex, limit: limit)
    }

    @Test func rankedExactWinsOverEverything() {
        #expect(ranked("Ocean") == [items[0], items[3]])
    }

    @Test func rankedExactHexIsASingleResult() {
        #expect(ranked("ff0000") == [items[4]])
        #expect(ranked("#FF0000") == [items[4]])
    }

    @Test func rankedPrefixBeforeContains() {
        #expect(ranked("oce") == [items[0], items[1], items[3]], "prefix matches sort by name, uppercase first")
        #expect(ranked("ocean m") == [items[1]])
    }

    @Test func rankedContainsFallbackAndLimit() {
        #expect(ranked("ep oc") == [items[2]])
        #expect(ranked("o", limit: 2).count == 2)
        #expect(ranked("zzz").isEmpty)
        #expect(ranked("").isEmpty)
    }

    @Test func resultEmptiness() {
        #expect(PortfolioSearchResult().isEmpty)
        #expect(!PortfolioSearchResult(colorIDs: [UUID()]).isEmpty)
        #expect(!PortfolioSearchResult(paletteIDs: [UUID()]).isEmpty)
    }
}

@Suite("HexFormat")
struct HexFormatTests {
    @Test func defaultsToIncludingThePrefix() {
        let store = FakeKeyValueStore()
        #expect(HexFormat.stored(in: store).includesPrefix)
    }

    @Test func readsAStoredFalse() {
        let store = FakeKeyValueStore()
        store.set(false, forKey: AppStorageKeys.includeHexPrefix)
        #expect(!HexFormat.stored(in: store).includesPrefix)
    }

    @Test func saveWritesBothKeys() {
        let store = FakeKeyValueStore()
        HexFormat(includesPrefix: false).save(to: store)
        #expect(store.bool(forKey: AppStorageKeys.includeHexPrefix) == false)
        #expect(store.bool(forKey: AppStorageKeys.hasSetHexPrefixDefault))
        #expect(!HexFormat.stored(in: store).includesPrefix)
    }

    @Test("Formatting", arguments: [
        (true, "#FF5733", "#FF5733"),
        (true, "FF5733", "#FF5733"),
        (false, "#FF5733", "FF5733"),
        (false, "FF5733", "FF5733"),
    ])
    func formats(includesPrefix: Bool, input: String, expected: String) {
        #expect(HexFormat(includesPrefix: includesPrefix).format(input) == expected)
    }
}

@Suite("ReviewMilestone")
struct ReviewMilestoneTests {
    @Test func promptsAtTwoPalettes() {
        #expect(ReviewMilestone.shouldPrompt(colorCount: 0, paletteCount: 2, currentVersion: "1.2", lastPromptedVersion: ""))
    }

    @Test func promptsPastEightColors() {
        #expect(ReviewMilestone.shouldPrompt(colorCount: 9, paletteCount: 0, currentVersion: "1.2", lastPromptedVersion: "1.1"))
        #expect(!ReviewMilestone.shouldPrompt(colorCount: 8, paletteCount: 0, currentVersion: "1.2", lastPromptedVersion: "1.1"))
    }

    @Test func doesNotPromptTwicePerVersion() {
        #expect(!ReviewMilestone.shouldPrompt(colorCount: 20, paletteCount: 2, currentVersion: "1.2", lastPromptedVersion: "1.2"))
    }

    @Test func doesNotPromptWithoutAVersionOrMilestone() {
        #expect(!ReviewMilestone.shouldPrompt(colorCount: 20, paletteCount: 2, currentVersion: "", lastPromptedVersion: ""))
        #expect(!ReviewMilestone.shouldPrompt(colorCount: 2, paletteCount: 3, currentVersion: "1.2", lastPromptedVersion: ""))
        #expect(!ReviewMilestone.shouldPrompt(colorCount: 0, paletteCount: 1, currentVersion: "1.2", lastPromptedVersion: ""))
    }
}
