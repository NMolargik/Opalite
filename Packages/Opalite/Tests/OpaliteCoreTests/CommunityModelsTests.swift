//
//  CommunityModelsTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

private func color(_ name: String?, publishedAt: TimeInterval, record: String = UUID().uuidString) -> CommunityColor {
    CommunityColor(id: CommunityRecordID(recordName: record), originalColorID: UUID(), name: name, notes: nil, red: 0.5, green: 0.2, blue: 0.9, alpha: 1,
                   publisherName: "P", publisherUserRecordID: CommunityRecordID(recordName: "u"), originalCreatedAt: Date(timeIntervalSince1970: 0),
                   publishedAt: Date(timeIntervalSince1970: publishedAt))
}

private func palette(_ name: String, publishedAt: TimeInterval, colors: [CommunityColor] = [], colorCount: Int? = nil) -> CommunityPalette {
    CommunityPalette(id: CommunityRecordID(recordName: UUID().uuidString), originalPaletteID: UUID(), name: name, notes: nil, tags: [],
                     colorCount: colorCount ?? colors.count, publisherName: "P", publisherUserRecordID: CommunityRecordID(recordName: "u"),
                     originalCreatedAt: Date(timeIntervalSince1970: 0), publishedAt: Date(timeIntervalSince1970: publishedAt), colors: colors)
}

@Suite("CommunitySortOption")
struct CommunitySortOptionTests {
    let colors = [color("banana", publishedAt: 10), color("Apple", publishedAt: 30), color(nil, publishedAt: 20)]
    let palettes = [palette("zebra", publishedAt: 1), palette("Alpha", publishedAt: 3), palette("mango", publishedAt: 2)]

    @Test func newestFirst() {
        #expect(CommunitySortOption.newest.sort(colors).map(\.publishedAt.timeIntervalSince1970) == [30, 20, 10])
        #expect(CommunitySortOption.newest.sort(palettes).map(\.name) == ["Alpha", "mango", "zebra"])
    }

    @Test func oldestFirst() {
        #expect(CommunitySortOption.oldest.sort(colors).map(\.publishedAt.timeIntervalSince1970) == [10, 20, 30])
        #expect(CommunitySortOption.oldest.sort(palettes).map(\.name) == ["zebra", "mango", "Alpha"])
    }

    @Test func alphabeticalIsCaseInsensitiveAndUsesDisplayName() {
        #expect(CommunitySortOption.alphabetical.sort(colors).map(\.displayName) == ["#8033E6", "Apple", "banana"])
        #expect(CommunitySortOption.alphabetical.sort(palettes).map(\.name) == ["Alpha", "mango", "zebra"])
    }

    @Test func serverSortDescriptors() {
        #expect(CommunitySortOption.newest.sortField == "publishedAt" && !CommunitySortOption.newest.ascending)
        #expect(CommunitySortOption.oldest.sortField == "publishedAt" && CommunitySortOption.oldest.ascending)
        #expect(CommunitySortOption.alphabetical.sortField == "name" && CommunitySortOption.alphabetical.ascending)
        #expect(CommunitySortOption.allCases.count == 3)
        #expect(CommunitySortOption.allCases.allSatisfy { !$0.systemImage.isEmpty && $0.id == $0.rawValue })
    }
}

@Suite("PublishRateLimiter")
struct PublishRateLimiterTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func allowsUpToTheCap() {
        var limiter = PublishRateLimiter()
        for _ in 0..<PublishRateLimiter.maxPublishesPerHour - 1 {
            #expect(limiter.canPublish(now: now))
            limiter.record(now: now)
        }
        #expect(limiter.canPublish(now: now))
        limiter.record(now: now)
        #expect(!limiter.canPublish(now: now))
        #expect(limiter.recentPublishes.count == PublishRateLimiter.maxPublishesPerHour)
    }

    @Test func oldPublishesExpireAfterAnHour() {
        let stale = (0..<PublishRateLimiter.maxPublishesPerHour).map { _ in now.addingTimeInterval(-3601) }
        let limiter = PublishRateLimiter(recentPublishes: stale)
        #expect(limiter.canPublish(now: now))
        #expect(!limiter.canPublish(now: now.addingTimeInterval(-3600)), "a second earlier they are still within the window")
    }

    @Test func recordingPrunesStaleEntries() {
        var limiter = PublishRateLimiter(recentPublishes: [now.addingTimeInterval(-7200), now.addingTimeInterval(-10)])
        limiter.record(now: now)
        #expect(limiter.recentPublishes == [now.addingTimeInterval(-10), now])
    }

    @Test func exactlyOneHourOldStillCounts() {
        let limiter = PublishRateLimiter(recentPublishes: Array(repeating: now.addingTimeInterval(-3600), count: PublishRateLimiter.maxPublishesPerHour))
        #expect(!limiter.canPublish(now: now))
    }
}

@Suite("CommunityModeration & models")
struct CommunityModelValueTests {
    @Test func autoHideThreshold() {
        #expect(CommunityModeration.autoHideThreshold == 5)
        #expect(!CommunityModeration.isHidden(afterReports: 0))
        #expect(!CommunityModeration.isHidden(afterReports: 4))
        #expect(CommunityModeration.isHidden(afterReports: 5))
        #expect(CommunityModeration.isHidden(afterReports: 50))
    }

    @Test func colorDerivesHexAndDisplayName() {
        let c = color(nil, publishedAt: 0)
        #expect(c.hexString == "#8033E6")
        #expect(c.displayName == "#8033E6")
        #expect(color("  ", publishedAt: 0).displayName == "#8033E6")
        #expect(color("Name", publishedAt: 0).displayName == "Name")
        #expect(c.rgba == RGBA(red: 0.5, green: 0.2, blue: 0.9))
        #expect(c.rgbString == "rgb(128, 51, 230)")
        #expect(!c.prefersDarkText)
    }

    @Test func explicitHexOverridesTheDerivedOne() {
        let c = CommunityColor(id: .unknown, originalColorID: UUID(), name: nil, notes: nil, red: 0, green: 0, blue: 0, alpha: 1, hexString: "#ABCDEF",
                               publisherName: "P", publisherUserRecordID: .unknown, originalCreatedAt: Date(), publishedAt: Date())
        #expect(c.hexString == "#ABCDEF")
    }

    @Test func colorsAreEqualByRecordID() {
        let a = color("A", publishedAt: 1, record: "same")
        let b = color("B", publishedAt: 2, record: "same")
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
        #expect(a != color("A", publishedAt: 1))
    }

    @Test func palettesCompareByIDAndLoadedColorCount() {
        var a = palette("P", publishedAt: 0, colorCount: 2)
        let same = a
        #expect(a == same)
        #expect(!a.hasLoadedColors)
        a.colors = [.sample, .sample2]
        #expect(a.hasLoadedColors)
        #expect(a != same, "loading colors changes equality so SwiftUI re-renders")
        #expect(palette("Empty", publishedAt: 0).hasLoadedColors, "zero-color palettes have nothing to load")
    }

    @Test func publisherEqualityAndSamples() {
        let a = CommunityPublisher(id: CommunityRecordID(recordName: "u"), displayName: "A", colorCount: 1)
        let b = CommunityPublisher(id: CommunityRecordID(recordName: "u"), displayName: "B", colorCount: 9)
        #expect(a == b && Set([a, b]).count == 1)
        #expect(CommunityPublisher.sample.displayName == "Sample User")
        #expect(CommunityColor.sample.id != CommunityColor.sample2.id)
        #expect(CommunityPalette.sample.colors.count == 2 && CommunityPalette.sample.hasLoadedColors)
    }

    @Test func recordTypesAndReasons() {
        #expect(CommunityColor.recordType == "PublishedColor")
        #expect(CommunityPalette.recordType == "PublishedPalette")
        #expect(CommunityPalette.junctionRecordType == "PublishedPaletteColor")
        #expect(CommunityPalette.reportRecordType == "CommunityReport")
        #expect(ReportReason.allCases.count == 4)
        #expect(ReportReason.spam.rawValue == "Spam")
        #expect(ReportReason.allCases.allSatisfy { !$0.systemImage.isEmpty && $0.id == $0.rawValue })
        #expect(CommunitySegment.allCases.map(\.rawValue) == ["colors", "palettes"])
        #expect(CommunityItemType.color.rawValue == "color")
        #expect(CommunityRecordID.unknown.recordName == "unknown")
    }

    @Test func recordIDIsCodable() throws {
        let id = CommunityRecordID(recordName: "abc")
        let data = try JSONEncoder().encode(id)
        #expect(try JSONDecoder().decode(CommunityRecordID.self, from: data) == id)
    }

    @Test func publicationsAreValueTypes() {
        let pub = ColorPublication(originalColorID: UUID(), name: "N", notes: nil, rgba: .black, createdOnDeviceName: nil, originalCreatedAt: Date(timeIntervalSince1970: 1))
        #expect(pub == pub)
        let pal = PalettePublication(originalPaletteID: UUID(), name: "P", notes: nil, tags: ["t"], originalCreatedAt: Date(), colors: [pub], previewImagePNG: Data([1]))
        #expect(pal.colors == [pub] && pal.previewImagePNG == Data([1]))
        let page = CommunityPage(items: [1, 2], nextCursor: CommunityCursor(token: "t"))
        #expect(page.items == [1, 2] && page.nextCursor?.token == "t")
    }
}
