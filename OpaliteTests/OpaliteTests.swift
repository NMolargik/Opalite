//
//  OpaliteTests.swift
//  OpaliteTests
//
//  Hosted tests for the app target's glue only: quick-action relay, App Intent screens,
//  entities (Spotlight attributes and display), App Shortcuts, and the app-side seams.
//  Everything with logic lives in Packages/Opalite and is tested there on the host;
//  these tests never create a SwiftData container.
//

import AppIntents
import CoreSpotlight
import Foundation
import Testing
import OpaliteCore
@testable import Opalite

// MARK: - Quick actions

@Suite("Quick action relay")
struct QuickActionRelayTests {
    @Test func relayStartsEmptyAndHoldsOneURL() {
        let relay = QuickActionRelay()
        #expect(relay.url == nil)
        relay.url = URL(string: "opalite://createColor")
        #expect(relay.url?.scheme == DeepLink.scheme)
        relay.url = nil
        #expect(relay.url == nil)
    }

    @Test func staticQuickActionTypesAreDeepLinks() throws {
        let plist = try #require(Bundle.main.infoDictionary)
        let items = plist["UIApplicationShortcutItems"] as? [[String: Any]] ?? []
        #expect(!items.isEmpty)
        for item in items {
            let type = try #require(item["UIApplicationShortcutItemType"] as? String)
            let url = try #require(URL(string: type))
            #expect(DeepLink(url: url) != nil, "Quick action \(type) must parse as a deep link")
        }
    }
}

// MARK: - Intent screens

@Suite("Intent screens")
struct OpaliteScreenTests {
    @Test func everyScreenMapsToADeepLink() {
        #expect(OpaliteScreen.portfolio.deepLink == .portfolio)
        #expect(OpaliteScreen.community.deepLink == .community)
        #expect(OpaliteScreen.search.deepLink == .search)
        #expect(OpaliteScreen.canvases.deepLink == .canvases)
        #expect(OpaliteScreen.settings.deepLink == .settings)
        #expect(OpaliteScreen.onyx.deepLink == .onyx)
    }

    @Test func everyScreenHasADisplayName() {
        for screen in OpaliteScreen.allCases {
            #expect(OpaliteScreen.caseDisplayRepresentations[screen] != nil)
        }
    }

    @Test func intentErrorsReadWell() {
        #expect(String(localized: OpaliteIntentError.notFound.localizedStringResource) == "That item no longer exists.")
        #expect(String(localized: OpaliteError.paletteLimitReached.localizedStringResource) == OpaliteError.paletteLimitReached.errorDescription)
    }
}

// MARK: - Entities

@Suite("Color entity")
struct ColorEntityTests {
    private func makeColor(name: String? = "Dusty Rose", notes: String? = nil) -> OpaliteColor {
        OpaliteColor(name: name, notes: notes, red: 0.85, green: 0.6, blue: 0.65)
    }

    @Test func mirrorsTheModel() {
        let color = makeColor(notes: "Soft")
        let entity = ColorEntity(color)
        #expect(entity.id == color.id)
        #expect(entity.name == "Dusty Rose")
        #expect(entity.hexString == color.hexString)
        #expect(entity.notes == "Soft")
        #expect(entity.paletteName == nil)
        #expect(entity.rgba == color.rgba)
    }

    @Test func unnamedColorsFallBackToHexForDisplay() {
        let entity = ColorEntity(makeColor(name: nil))
        #expect(entity.name == nil)
        #expect(String(localized: entity.displayRepresentation.title) == entity.hexString)
        #expect(entity.displayRepresentation.subtitle == nil)
    }

    @Test func namedColorsShowHexAsSubtitle() {
        let entity = ColorEntity(makeColor())
        #expect(String(localized: entity.displayRepresentation.title) == "Dusty Rose")
        #expect(entity.displayRepresentation.subtitle.map { String(localized: $0) } == entity.hexString)
    }

    @Test func spotlightAttributesDescribeTheColor() {
        let palette = OpalitePalette(name: "Blush")
        let color = makeColor(notes: "Soft")
        color.palette = palette
        let set = ColorEntity(color).attributeSet
        #expect(set.title == "Dusty Rose")
        #expect(set.contentDescription?.contains(color.hexString) == true)
        #expect(set.contentDescription?.contains("Soft") == true)
        #expect(set.contentDescription?.contains("Blush") == true)
        #expect(set.keywords?.contains("color") == true)
        #expect(set.keywords?.contains(color.hexString) == true)
        #expect(set.keywords?.contains { ColorClassifier.searchTerms(for: color.rgba).contains($0) } == true)
    }
}

@Suite("Palette entity")
struct PaletteEntityTests {
    @Test func mirrorsTheModelAndInflectsCounts() {
        let palette = OpalitePalette(name: "Harbor", notes: "Cool", tags: ["sea"], colors: [
            OpaliteColor(name: "Fog", red: 0.8, green: 0.8, blue: 0.85),
            OpaliteColor(name: nil, red: 0.1, green: 0.2, blue: 0.4),
        ])
        for color in palette.colors ?? [] { color.palette = palette }
        let entity = PaletteEntity(palette)
        #expect(entity.id == palette.id)
        #expect(entity.name == "Harbor")
        #expect(entity.colorCount == 2)
        #expect(entity.tags == ["sea"])
        #expect(entity.colorNames.count == 2)
        #expect(entity.colorNames.contains("Fog"))
        #expect(entity.displayRepresentation.subtitle.map { String(localized: $0) } == "2 colors")

        let single = PaletteEntity(OpalitePalette(name: "Solo", colors: [OpaliteColor(red: 0, green: 0, blue: 0)]))
        #expect(single.displayRepresentation.subtitle.map { String(localized: $0) } == "1 color")
    }

    @Test func spotlightAttributesIncludeTagsAndNames() {
        let palette = OpalitePalette(name: "Harbor", notes: "Cool", tags: ["sea", "calm"], colors: [OpaliteColor(name: "Fog", red: 0.8, green: 0.8, blue: 0.85)])
        let set = PaletteEntity(palette).attributeSet
        #expect(set.title == "Harbor")
        #expect(set.contentDescription?.contains("1 color") == true)
        #expect(set.contentDescription?.contains("Fog") == true)
        #expect(set.contentDescription?.contains("Cool") == true)
        #expect(set.keywords == ["palette", "colors", "sea", "calm"])
    }
}

// MARK: - Shortcuts

@Suite("App Shortcuts")
struct OpaliteShortcutsTests {
    @Test func everyShortcutHasPhrasesAndATitle() {
        let shortcuts = OpaliteShortcuts.appShortcuts
        #expect(shortcuts.count == 6)
        #expect(OpaliteShortcuts.shortcutTileColor == .purple)
    }

    @Test func navigationIntentsOpenTheApp() {
        #expect(OpenOpaliteIntent.openAppWhenRun)
        #expect(ShowColorIntent.openAppWhenRun)
        #expect(ShowPaletteIntent.openAppWhenRun)
        #expect(!CreateColorIntent.openAppWhenRun)
        #expect(!CopyColorHexIntent.openAppWhenRun)
        #expect(!RandomColorIntent.openAppWhenRun)
        #expect(!PortfolioSummaryIntent.openAppWhenRun)
    }
}

// MARK: - App-side seams

@Suite("App seams")
struct AppSeamTests {
    @Test func seamsAreUsableAsCoreProtocols() {
        let indexer: any PortfolioIndexing = SpotlightIndexer()
        let donor: any IntentDonating = IntentDonor()
        let annotator: any EntityActivityAnnotating = EntityActivityAnnotator()
        let vocabulary: any ShortcutVocabularyUpdating = ShortcutVocabularyUpdater()
        let reviewer: any ReviewRequesting = AppStoreReviewRequester()
        #expect(indexer is SpotlightIndexer)
        #expect(donor is IntentDonor)
        #expect(annotator is EntityActivityAnnotator)
        #expect(vocabulary is ShortcutVocabularyUpdater)
        #expect(reviewer is AppStoreReviewRequester)
    }

    @Test func activityAnnotatorTagsTheEntity() {
        let annotator = EntityActivityAnnotator()
        let activity = NSUserActivity(activityType: UserActivityType.viewingColor)
        let id = UUID()
        annotator.annotateColor(activity, colorID: id)
        if #available(iOS 18.2, *) {
            #expect(activity.appEntityIdentifier != nil)
        }
    }

    @Test func testHostDetectionIsOn() {
        #expect(OpaliteApp.isRunningTests)
    }
}
