//
//  RepositoryTests.swift
//  OpaliteDataTests
//
//  The SwiftData-backed repositories over a unique on-disk temporary store per test.
//

import Foundation
import SwiftData
import Testing
import OpaliteCore
@testable import OpaliteData

/// One temporary container with the three repositories and the change center they notify.
@MainActor
final class TestStore {
    let container: ModelContainer
    let changeCenter = PortfolioChangeCenter()
    let colors: DefaultColorRepository
    let palettes: DefaultPaletteRepository
    let canvases: DefaultCanvasRepository
    let authorship = Authorship(displayName: "Nick", deviceName: "iPhone 17 Pro")

    init() throws {
        container = try OpaliteStore.makeTemporaryContainer()
        colors = DefaultColorRepository(container: container, changeCenter: changeCenter)
        palettes = DefaultPaletteRepository(container: container, changeCenter: changeCenter)
        canvases = DefaultCanvasRepository(container: container, changeCenter: changeCenter)
    }

    var context: ModelContext { container.mainContext }

    deinit {
        if let url = container.configurations.first?.url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

@Suite("OpaliteStore", .serialized)
struct OpaliteStoreTests {
    @Test func temporaryContainersAreIsolatedAndOnDisk() throws {
        let a = try TestStore()
        let b = try TestStore()
        #expect(a.container.configurations.first?.url != b.container.configurations.first?.url)
        #expect(a.container.configurations.first?.isStoredInMemoryOnly == false)
        try a.colors.insert(OpaliteColor(red: 1, green: 0, blue: 0), authorship: a.authorship)
        #expect(try a.colors.count() == 1)
        #expect(try b.colors.count() == 0)
    }

    @Test func schemaCoversTheThreeModels() {
        let names = Set(OpaliteStore.schema.entities.map(\.name))
        #expect(names == ["OpaliteColor", "OpalitePalette", "CanvasFile"])
    }

    @Test func inMemoryContainerBuilds() throws {
        let container = OpaliteStore.makeContainer(inMemory: true)
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        let repo = DefaultColorRepository(container: container, changeCenter: PortfolioChangeCenter())
        try repo.insert(OpaliteColor(red: 0, green: 0, blue: 0), authorship: .anonymous)
        #expect(try repo.count() == 1)
    }
}

@Suite("DefaultColorRepository", .serialized)
struct DefaultColorRepositoryTests {
    @Test func insertStampsAuthorshipOnlyWhereMissing() throws {
        let store = try TestStore()
        let fresh = OpaliteColor(name: "Fresh", red: 1, green: 0, blue: 0)
        try store.colors.insert(fresh, authorship: store.authorship)
        #expect(fresh.createdByDisplayName == "Nick")
        #expect(fresh.createdOnDeviceName == "iPhone 17 Pro")
        #expect(fresh.updatedOnDeviceName == "iPhone 17 Pro")

        let imported = OpaliteColor(name: "Imported", createdByDisplayName: "Someone", createdOnDeviceName: "iPad", red: 0, green: 1, blue: 0)
        try store.colors.insert(imported, authorship: store.authorship)
        #expect(imported.createdByDisplayName == "Someone")
        #expect(imported.createdOnDeviceName == "iPad")
        #expect(imported.updatedOnDeviceName == "iPhone 17 Pro", "only the gap is filled")

        let blank = OpaliteColor(createdByDisplayName: "   ", red: 0, green: 0, blue: 1)
        try store.colors.insert(blank, authorship: store.authorship)
        #expect(blank.createdByDisplayName == "Nick", "whitespace counts as missing")
        #expect(try store.colors.count() == 3)
    }

    @Test func colorsAreSortedByMostRecentUpdate() throws {
        let store = try TestStore()
        let now = Date()
        let oldest = OpaliteColor(name: "Oldest", createdAt: now.addingTimeInterval(-30), updatedAt: now.addingTimeInterval(-30), red: 0, green: 0, blue: 0)
        let middle = OpaliteColor(name: "Middle", createdAt: now.addingTimeInterval(-20), updatedAt: now.addingTimeInterval(-20), red: 0, green: 0, blue: 0)
        let newest = OpaliteColor(name: "Newest", createdAt: now.addingTimeInterval(-10), updatedAt: now.addingTimeInterval(-10), red: 0, green: 0, blue: 0)
        for color in [middle, newest, oldest] { try store.colors.insert(color, authorship: store.authorship) }
        #expect(try store.colors.colors().map(\.name) == ["Newest", "Middle", "Oldest"])

        try store.colors.update(oldest, authorship: store.authorship) { $0.name = "Touched" }
        #expect(try store.colors.colors().map(\.name) == ["Touched", "Newest", "Middle"], "updating moves a color to the front")
    }

    @Test func findByIDAndCount() throws {
        let store = try TestStore()
        let color = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)
        try store.colors.insert(color, authorship: store.authorship)
        #expect(try store.colors.color(withID: color.id)?.id == color.id)
        #expect(try store.colors.color(withID: UUID()) == nil)
        #expect(try store.colors.count() == 1)
    }

    @Test func updateStampsDeviceAndTimestamp() throws {
        let store = try TestStore()
        let color = OpaliteColor(red: 0, green: 0, blue: 0, alpha: 1)
        try store.colors.insert(color, authorship: Authorship(displayName: "A", deviceName: "Phone"))
        let before = color.updatedAt
        try store.colors.update(color, authorship: Authorship(displayName: "A", deviceName: "Mac")) { $0.name = "Named"; $0.alpha = 0.5 }
        #expect(color.name == "Named" && color.alpha == 0.5)
        #expect(color.updatedOnDeviceName == "Mac")
        #expect(color.updatedAt >= before)
        #expect(try store.colors.color(withID: color.id)?.name == "Named")
    }

    @Test func deleteRemovesTheColorAndItsPaletteMembership() throws {
        let store = try TestStore()
        let palette = OpalitePalette(name: "P")
        try store.palettes.insert(palette, authorship: store.authorship)
        let color = OpaliteColor(red: 1, green: 1, blue: 1, palette: palette)
        try store.colors.insert(color, authorship: store.authorship)
        #expect(palette.colors?.count == 1)
        try store.colors.delete(color)
        #expect(try store.colors.count() == 0)
        #expect(palette.colors?.isEmpty == true)
        #expect(try store.palettes.count() == 1)
    }

    @Test func insertingIntoAPaletteKeepsBothSidesConsistent() throws {
        let store = try TestStore()
        let palette = OpalitePalette(name: "P")
        try store.palettes.insert(palette, authorship: store.authorship)
        let color = OpaliteColor(red: 1, green: 0, blue: 0, palette: palette)
        try store.colors.insert(color, authorship: store.authorship)
        #expect(color.palette?.id == palette.id)
        #expect(palette.colors?.map(\.id) == [color.id])
        #expect(try store.palettes.palette(withID: palette.id)?.colors?.count == 1)
    }

    @Test func attachMovesBetweenPalettesAndDetachMakesLoose() throws {
        let store = try TestStore()
        let first = OpalitePalette(name: "First")
        let second = OpalitePalette(name: "Second")
        try store.palettes.insert(first, authorship: store.authorship)
        try store.palettes.insert(second, authorship: store.authorship)
        let color = OpaliteColor(name: "Mover", red: 0.2, green: 0.4, blue: 0.6)
        try store.colors.insert(color, authorship: store.authorship)
        #expect(color.palette == nil)

        try store.colors.attach(color, to: first, authorship: store.authorship)
        #expect(color.palette?.id == first.id)
        #expect(first.colors?.map(\.id) == [color.id])

        try store.colors.attach(color, to: second, authorship: store.authorship)
        #expect(color.palette?.id == second.id)
        #expect(second.colors?.map(\.id) == [color.id])
        #expect(first.colors?.isEmpty == true, "the old palette drops it")

        try store.colors.attach(color, to: second, authorship: store.authorship)
        #expect(second.colors?.count == 1, "re-attaching is idempotent")

        try store.colors.detach(color, authorship: store.authorship)
        #expect(color.palette == nil)
        #expect(second.colors?.isEmpty == true)

        try store.colors.detach(color, authorship: store.authorship)
        #expect(color.palette == nil, "detaching a loose color is a no-op")

        let reloaded = try #require(try store.colors.color(withID: color.id))
        #expect(reloaded.palette == nil)
    }

    @Test func writesNotifyTheChangeCenter() async throws {
        let store = try TestStore()
        let stream = store.changeCenter.changes()
        var iterator = stream.makeAsyncIterator()
        let palette = OpalitePalette(name: "P")
        try store.palettes.insert(palette, authorship: store.authorship)
        let color = OpaliteColor(red: 0, green: 0, blue: 0)
        try store.colors.insert(color, authorship: store.authorship)
        try store.colors.update(color, authorship: store.authorship) { $0.name = "N" }
        try store.colors.attach(color, to: palette, authorship: store.authorship)
        try store.colors.detach(color, authorship: store.authorship)
        try store.colors.delete(color)

        let expected: [PortfolioChange] = [
            .paletteCreated(palette.id),
            .colorCreated(color.id), .colorUpdated(color.id),
            .colorUpdated(color.id), .paletteUpdated(palette.id),
            .colorUpdated(color.id), .paletteUpdated(palette.id),
            .colorDeleted(color.id),
        ]
        for change in expected {
            let received = await iterator.next()
            #expect(received == change)
        }
    }
}

@Suite("DefaultPaletteRepository", .serialized)
struct DefaultPaletteRepositoryTests {
    @Test func insertStampsAuthorshipAndPersistsCarriedColors() throws {
        let store = try TestStore()
        let colorA = OpaliteColor(name: "A", red: 1, green: 0, blue: 0)
        let colorB = OpaliteColor(name: "B", createdByDisplayName: "Other", red: 0, green: 1, blue: 0)
        let palette = OpalitePalette(name: "Sunset", notes: "warm", tags: ["t"], colors: [colorA, colorB])
        try store.palettes.insert(palette, authorship: store.authorship)

        #expect(palette.createdByDisplayName == "Nick")
        #expect(colorA.palette?.id == palette.id && colorB.palette?.id == palette.id)
        #expect(colorA.createdByDisplayName == "Nick" && colorB.createdByDisplayName == "Other")
        #expect(colorA.createdOnDeviceName == "iPhone 17 Pro")
        #expect(try store.colors.count() == 2)
        #expect(try store.palettes.count() == 1)
        let fetched = try #require(try store.palettes.palette(withID: palette.id))
        #expect(fetched.colors?.count == 2)
        #expect(fetched.tags == ["t"] && fetched.notes == "warm")
    }

    @Test func palettesAreNewestFirst() throws {
        let store = try TestStore()
        let now = Date()
        let old = OpalitePalette(name: "Old", createdAt: now.addingTimeInterval(-100))
        let new = OpalitePalette(name: "New", createdAt: now)
        let mid = OpalitePalette(name: "Mid", createdAt: now.addingTimeInterval(-50))
        for palette in [old, new, mid] { try store.palettes.insert(palette, authorship: store.authorship) }
        #expect(try store.palettes.palettes().map(\.name) == ["New", "Mid", "Old"])
    }

    @Test func updateTouchesTimestamp() throws {
        let store = try TestStore()
        let palette = OpalitePalette(name: "P", updatedAt: Date(timeIntervalSince1970: 0))
        try store.palettes.insert(palette, authorship: store.authorship)
        try store.palettes.update(palette) { $0.name = "Q"; $0.isArchived = true; $0.previewBackground = .navy }
        #expect(palette.updatedAt.timeIntervalSinceNow > -5)
        let fetched = try #require(try store.palettes.palette(withID: palette.id))
        #expect(fetched.name == "Q" && fetched.isArchived && fetched.previewBackground == .navy)
    }

    @Test func deleteWithoutDeletingColorsLeavesThemLoose() throws {
        let store = try TestStore()
        let color = OpaliteColor(name: "Keep", red: 0, green: 0, blue: 0)
        let palette = OpalitePalette(name: "P", colors: [color])
        try store.palettes.insert(palette, authorship: store.authorship)
        let colorID = color.id
        try store.palettes.delete(palette, deleteColors: false)
        #expect(try store.palettes.count() == 0)
        #expect(try store.colors.count() == 1)
        let loose = try #require(try store.colors.color(withID: colorID))
        #expect(loose.palette == nil)
    }

    @Test func deleteWithColorsRemovesThemToo() throws {
        let store = try TestStore()
        let palette = OpalitePalette(name: "P", colors: [OpaliteColor(red: 0, green: 0, blue: 0), OpaliteColor(red: 1, green: 1, blue: 1)])
        try store.palettes.insert(palette, authorship: store.authorship)
        let loose = OpaliteColor(name: "Loose", red: 0.5, green: 0.5, blue: 0.5)
        try store.colors.insert(loose, authorship: store.authorship)
        #expect(try store.colors.count() == 3)
        try store.palettes.delete(palette, deleteColors: true)
        #expect(try store.palettes.count() == 0)
        #expect(try store.colors.colors().map(\.name) == ["Loose"])
    }

    @Test func deletingAPaletteUnlinksItsCanvas() throws {
        let store = try TestStore()
        let palette = OpalitePalette(name: "P")
        let canvas = CanvasFile(title: "C")
        try store.palettes.insert(palette, authorship: store.authorship)
        try store.canvases.insert(canvas, deviceName: "Mac")
        try store.palettes.attach(canvas, to: palette)
        try store.palettes.delete(palette, deleteColors: false)
        #expect(canvas.palette == nil)
        #expect(try store.canvases.count() == 1)
    }

    @Test func canvasLinksAreOneToOne() throws {
        let store = try TestStore()
        let first = OpalitePalette(name: "First")
        let second = OpalitePalette(name: "Second")
        let canvasA = CanvasFile(title: "A")
        let canvasB = CanvasFile(title: "B")
        try store.palettes.insert(first, authorship: store.authorship)
        try store.palettes.insert(second, authorship: store.authorship)
        try store.canvases.insert(canvasA, deviceName: nil)
        try store.canvases.insert(canvasB, deviceName: nil)

        try store.palettes.attach(canvasA, to: first)
        #expect(first.canvasFile?.id == canvasA.id && canvasA.palette?.id == first.id)

        try store.palettes.attach(canvasA, to: second)
        #expect(second.canvasFile?.id == canvasA.id && canvasA.palette?.id == second.id)
        #expect(first.canvasFile == nil, "a canvas belongs to one palette")

        try store.palettes.attach(canvasB, to: second)
        #expect(second.canvasFile?.id == canvasB.id && canvasB.palette?.id == second.id)
        #expect(canvasA.palette == nil, "a palette holds one canvas")

        try store.palettes.detachCanvas(from: second)
        #expect(second.canvasFile == nil && canvasB.palette == nil)
        try store.palettes.detachCanvas(from: second)
        #expect(second.canvasFile == nil, "detaching twice is harmless")
    }

    @Test func writesNotifyTheChangeCenter() async throws {
        let store = try TestStore()
        let stream = store.changeCenter.changes()
        var iterator = stream.makeAsyncIterator()
        let palette = OpalitePalette(name: "P", colors: [OpaliteColor(red: 0, green: 0, blue: 0)])
        try store.palettes.insert(palette, authorship: store.authorship)
        try store.palettes.update(palette) { $0.name = "Q" }
        let canvas = CanvasFile(title: "C")
        try store.canvases.insert(canvas, deviceName: nil)
        try store.palettes.attach(canvas, to: palette)
        try store.palettes.detachCanvas(from: palette)
        try store.palettes.delete(palette, deleteColors: true)

        let expected: [PortfolioChange] = [
            .paletteCreated(palette.id), .bulk,
            .paletteUpdated(palette.id),
            .canvasCreated(canvas.id),
            .paletteUpdated(palette.id), .canvasUpdated(canvas.id),
            .paletteUpdated(palette.id), .canvasUpdated(canvas.id),
            .paletteDeleted(palette.id), .bulk,
        ]
        for change in expected {
            let received = await iterator.next()
            #expect(received == change)
        }
    }
}

@Suite("DefaultCanvasRepository", .serialized)
struct DefaultCanvasRepositoryTests {
    @Test func insertStampsDeviceAndSortsByTitle() throws {
        let store = try TestStore()
        let zebra = CanvasFile(title: "zebra")
        let apple = CanvasFile(title: "Apple")
        let mango = CanvasFile(title: "mango")
        try store.canvases.insert(zebra, deviceName: "Mac")
        try store.canvases.insert(apple, deviceName: nil)
        try store.canvases.insert(mango, deviceName: "iPad")
        #expect(zebra.lastEditedDeviceName == "Mac")
        #expect(apple.lastEditedDeviceName == nil)
        #expect(try store.canvases.canvases().map(\.title) == ["Apple", "mango", "zebra"], "case-insensitive by title")
        #expect(try store.canvases.count() == 3)
        #expect(try store.canvases.canvas(withID: mango.id)?.title == "mango")
        #expect(try store.canvases.canvas(withID: UUID()) == nil)
    }

    @Test func updateKeepsThePreviousDeviceWhenNoneGiven() throws {
        let store = try TestStore()
        let canvas = CanvasFile(title: "C")
        try store.canvases.insert(canvas, deviceName: "Mac")
        try store.canvases.update(canvas, deviceName: nil) { $0.title = "D"; $0.thumbnailData = Data([1, 2]) }
        #expect(canvas.title == "D" && canvas.lastEditedDeviceName == "Mac")
        try store.canvases.update(canvas, deviceName: "iPad") { _ in }
        #expect(canvas.lastEditedDeviceName == "iPad")
        #expect(try store.canvases.canvas(withID: canvas.id)?.thumbnailData == Data([1, 2]))
    }

    @Test func deleteUnlinksThePalette() throws {
        let store = try TestStore()
        let palette = OpalitePalette(name: "P")
        let canvas = CanvasFile(title: "C")
        try store.palettes.insert(palette, authorship: store.authorship)
        try store.canvases.insert(canvas, deviceName: nil)
        try store.palettes.attach(canvas, to: palette)
        try store.canvases.delete(canvas)
        #expect(try store.canvases.count() == 0)
        #expect(palette.canvasFile == nil)
        #expect(try store.palettes.palette(withID: palette.id)?.canvasFile == nil)
    }

    @Test func duplicateRecordsFromASyncRaceAreFolded() throws {
        let store = try TestStore()
        let original = CanvasFile(title: "Same")
        original.updatedAt = Date(timeIntervalSince1970: 1000)
        let duplicate = CanvasFile(title: "Same")
        duplicate.id = original.id
        duplicate.updatedAt = Date(timeIntervalSince1970: 2000)
        store.context.insert(original)
        store.context.insert(duplicate)
        try store.context.save()

        let folded = try store.canvases.canvases()
        #expect(folded.count == 1)
        #expect(folded.first?.updatedAt == Date(timeIntervalSince1970: 2000), "the most recently updated copy wins")
        #expect(try store.context.fetchCount(FetchDescriptor<CanvasFile>()) == 1)
    }

    @Test func writesNotifyTheChangeCenter() async throws {
        let store = try TestStore()
        let stream = store.changeCenter.changes()
        var iterator = stream.makeAsyncIterator()
        let canvas = CanvasFile(title: "C")
        try store.canvases.insert(canvas, deviceName: nil)
        try store.canvases.update(canvas, deviceName: nil) { $0.title = "D" }
        try store.canvases.delete(canvas)
        for change in [PortfolioChange.canvasCreated(canvas.id), .canvasUpdated(canvas.id), .canvasDeleted(canvas.id)] {
            let received = await iterator.next()
            #expect(received == change)
        }
    }
}

#if DEBUG
@Suite("SamplePortfolioData", .serialized)
struct SamplePortfolioDataTests {
    @Test func seedsTheExpectedCounts() throws {
        let store = try TestStore()
        let generate = SamplePortfolioData(colors: store.colors, palettes: store.palettes, canvases: store.canvases)
        try generate()
        #expect(try store.palettes.count() == 4)
        #expect(try store.canvases.count() == 3)
        let colors = try store.colors.colors()
        #expect(colors.count == 28, "24 palette colors + 4 loose")
        #expect(colors.filter { $0.palette == nil }.count == 4)
        #expect(try store.palettes.palettes().map(\.name).sorted() == ["Grayscale", "Neon", "Ocean", "Sunrise"])
        let grayscale = try #require(try store.palettes.palettes().first { $0.name == "Grayscale" })
        #expect(grayscale.colorCount == 13)
        #expect(colors.allSatisfy { $0.createdByDisplayName == "Sample Sam" })
        #expect(try store.canvases.canvases().map(\.title) == ["Ideas", "Sketch", "Storyboard"])
    }

    @Test func seedingFiresBulkChanges() async throws {
        let store = try TestStore()
        let stream = store.changeCenter.changes()
        try SamplePortfolioData(colors: store.colors, palettes: store.palettes, canvases: store.canvases)()
        var iterator = stream.makeAsyncIterator()
        var seen: [PortfolioChange] = []
        for _ in 0..<15 {
            guard let next = await iterator.next() else { break }
            seen.append(next)
        }
        #expect(seen.contains(.bulk))
        #expect(seen.contains { if case .paletteCreated = $0 { return true } else { return false } })
    }
}
#endif
