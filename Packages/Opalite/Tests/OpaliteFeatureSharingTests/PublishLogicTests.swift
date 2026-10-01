//
//  PublishLogicTests.swift
//  OpaliteFeatureSharingTests
//

import Foundation
import Testing
import OpaliteCore
import OpaliteFeatureShared
@testable import OpaliteFeatureSharing

@Suite("Publish draft")
struct PublishDraftTests {
    @Test func prefillsFromTheItem() {
        let draft = PublishDraft(notes: "Soft dusk", tags: ["warm", "sunset"])
        #expect(draft.notes == "Soft dusk")
        #expect(draft.tagsText == "warm, sunset")
        #expect(draft.tags == ["warm", "sunset"])
    }

    @Test func blankNotesPublishAsNil() {
        #expect(PublishDraft(notes: nil).trimmedNotes == nil)
        #expect(PublishDraft(notes: "   \n").trimmedNotes == nil)
        #expect(PublishDraft(notes: "  hello ").trimmedNotes == "hello")
    }

    @Test func notesAreCappedAndCounted() {
        var draft = PublishDraft()
        draft.notes = String(repeating: "a", count: PublishDraft.maxNotesLength + 5)
        #expect(draft.isNotesOverLimit)
        #expect(draft.notesRemaining == 0)
        #expect(draft.trimmedNotes?.count == PublishDraft.maxNotesLength)
        draft.notes = "short"
        #expect(draft.notesRemaining == PublishDraft.maxNotesLength - 5)
    }

    @Test func tagsAreCleanedAndDeduplicated() {
        var draft = PublishDraft()
        draft.tagsText = " #Warm, sunset ,, SUNSET\nwarm , #, beach"
        #expect(draft.tags == ["Warm", "sunset", "beach"])
        #expect(!draft.isTagsOverLimit)
    }

    @Test func tagsAreCappedInCountAndLength() {
        var draft = PublishDraft()
        draft.tagsText = (1...15).map { "tag\($0)" }.joined(separator: ",")
        #expect(draft.tags.count == PublishDraft.maxTags)
        #expect(draft.isTagsOverLimit)
        draft.tagsText = String(repeating: "x", count: PublishDraft.maxTagLength + 10)
        #expect(draft.tags == [String(repeating: "x", count: PublishDraft.maxTagLength)])
    }
}

@Suite("Publish blockers")
struct PublishBlockerTests {
    @Test func offlineWinsOverEverything() {
        #expect(PublishBlocker.evaluate(isConnected: false, isSignedIn: false, canPublish: false) == .offline)
    }

    @Test func signInComesBeforeRateLimit() {
        #expect(PublishBlocker.evaluate(isConnected: true, isSignedIn: false, canPublish: false) == .notSignedIn)
    }

    @Test func rateLimitedWhenOnlyTheLimiterBlocks() {
        #expect(PublishBlocker.evaluate(isConnected: true, isSignedIn: true, canPublish: false) == .rateLimited)
    }

    @Test func nothingBlocksAReadyPublish() {
        #expect(PublishBlocker.evaluate(isConnected: true, isSignedIn: true, canPublish: true) == nil)
    }

    @Test func rateLimitMessageQuotesTheLimit() {
        #expect(PublishBlocker.rateLimited.message.contains("\(PublishRateLimiter.maxPublishesPerHour)"))
    }
}

@Suite("Report draft")
struct ReportDraftTests {
    @Test func needsAReason() {
        var draft = ReportDraft()
        #expect(!draft.canSubmit)
        draft.reason = .spam
        #expect(draft.canSubmit)
    }

    @Test func blankDetailsSendNil() {
        var draft = ReportDraft(reason: .other, details: "  \n ")
        #expect(draft.trimmedDetails == nil)
        draft.details = " It copies a brand palette. "
        #expect(draft.trimmedDetails == "It copies a brand palette.")
    }

    @Test func overlongDetailsBlockSubmission() {
        let draft = ReportDraft(reason: .copyright, details: String(repeating: "x", count: ReportDraft.maxDetailsLength + 1))
        #expect(draft.isDetailsOverLimit)
        #expect(draft.detailsRemaining == 0)
        #expect(!draft.canSubmit)
    }
}

@Suite("Publish snapshots")
@MainActor
struct PublishSnapshotTests {
    @Test func colorSnapshotCarriesTheDraftNotesAndLeavesTheOriginalAlone() async throws {
        let environment = PreviewEnvironment()
        let color = try #require(environment.portfolio.colors.first { $0.name == "Moss" })
        let originalNotes = color.notes

        let snapshot = PublishSnapshot.color(color, notes: "Published note")
        #expect(snapshot.id == color.id)
        #expect(snapshot.name == color.name)
        #expect(snapshot.rgba == color.rgba)
        #expect(snapshot.notes == "Published note")
        #expect(snapshot.palette == nil)
        #expect(color.notes == originalNotes)

        #expect(await environment.community.publish(snapshot))
        let published = try #require(environment.communityService.publishedColors.last)
        #expect(published.originalColorID == color.id)
        #expect(published.notes == "Published note")
        #expect(published.rgba == color.rgba)
    }

    @Test func paletteSnapshotCopiesColorsInOrderAndPublishesTags() async throws {
        let environment = PreviewEnvironment()
        let palette = try #require(environment.portfolio.palettes.first)
        let originalTags = palette.tags
        let originalOwner = palette.sortedColors.first?.palette

        let snapshot = PublishSnapshot.palette(palette, notes: nil, tags: ["dusk", "sea"])
        #expect(snapshot.id == palette.id)
        #expect(snapshot.tags == ["dusk", "sea"])
        #expect(snapshot.notes == nil)
        #expect(snapshot.sortedColors.map(\.id) == palette.sortedColors.map(\.id))
        #expect(snapshot.previewBackgroundRaw == palette.previewBackgroundRaw)
        // The originals keep their palette; the copies belong to the snapshot only.
        #expect(palette.sortedColors.first?.palette === originalOwner)
        #expect(snapshot.sortedColors.allSatisfy { $0.palette === snapshot })
        #expect(palette.tags == originalTags)

        #expect(await environment.community.publish(snapshot, previewImagePNG: nil))
        let published = try #require(environment.communityService.publishedPalettes.last)
        #expect(published.originalPaletteID == palette.id)
        #expect(published.tags == ["dusk", "sea"])
        #expect(published.colors.map(\.originalColorID) == palette.sortedColors.map(\.id))
    }
}
