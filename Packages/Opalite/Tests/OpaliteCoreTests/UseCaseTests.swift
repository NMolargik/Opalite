//
//  UseCaseTests.swift
//  OpaliteCoreTests
//
//  The Core use-cases over in-memory fakes: gating, authorship, donation, relationship
//  moves, and typed error mapping.
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("Color use-cases")
struct ColorUseCaseTests {
    let authorship = Authorship(displayName: "Nick", deviceName: "iPhone")

    @Test func createColorStampsAuthorshipAndDonates() throws {
        let repo = FakeColorRepository()
        let donor = RecordingDonor()
        let create = CreateColorUseCase(repository: repo, donor: donor)
        let color = try create(RGBA(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4), name: "Mist", notes: "n", palette: nil, authorship: authorship)
        #expect(color.rgba == RGBA(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4))
        #expect(color.name == "Mist" && color.notes == "n")
        #expect(color.createdByDisplayName == "Nick")
        #expect(color.createdOnDeviceName == "iPhone")
        #expect(repo.storage.map(\.id) == [color.id])
        #expect(donor.donated == [.createColor])
    }

    @Test func createColorIntoAPaletteKeepsBothSides() throws {
        let repo = FakeColorRepository()
        let palette = OpalitePalette(name: "P")
        let color = try CreateColorUseCase(repository: repo)(RGBA.black, name: nil, notes: nil, palette: palette, authorship: authorship)
        #expect(color.palette === palette)
        #expect(palette.colors?.contains { $0.id == color.id } == true)
    }

    @Test func createColorPropagatesPersistenceErrors() {
        let repo = FakeColorRepository()
        repo.failure = .saveFailed("disk")
        #expect(throws: PersistenceError.saveFailed("disk")) {
            try CreateColorUseCase(repository: repo)(RGBA.black, name: nil, notes: nil, palette: nil, authorship: authorship)
        }
    }

    @Test func insertKeepsExistingAuthorship() throws {
        let repo = FakeColorRepository()
        let color = OpaliteColor(name: "Imported", createdByDisplayName: "Someone Else", red: 1, green: 0, blue: 0)
        let inserted = try InsertColorUseCase(repository: repo)(color, authorship: authorship)
        #expect(inserted === color)
        #expect(inserted.createdByDisplayName == "Someone Else")
        #expect(inserted.createdOnDeviceName == "iPhone", "gaps are filled")
    }

    @Test func updateAppliesConfigureAndStampsDevice() throws {
        let color = OpaliteColor(red: 0, green: 0, blue: 0)
        let repo = FakeColorRepository(colors: [color])
        try UpdateColorUseCase(repository: repo)(color, authorship: authorship) { $0.name = "Renamed" }
        #expect(color.name == "Renamed")
        #expect(color.updatedOnDeviceName == "iPhone")
    }

    @Test func deleteRemovesFromRepositoryAndPalette() throws {
        let palette = OpalitePalette(name: "P")
        let color = OpaliteColor(red: 0, green: 0, blue: 0, palette: palette)
        palette.colors = [color]
        let repo = FakeColorRepository(colors: [color])
        try DeleteColorUseCase(repository: repo)(color)
        #expect(repo.storage.isEmpty)
        #expect(palette.colors?.isEmpty == true)
    }

    @Test func findReturnsMatchingColor() throws {
        let color = OpaliteColor(red: 0, green: 0, blue: 0)
        let repo = FakeColorRepository(colors: [color])
        #expect(try FindColorUseCase(repository: repo)(withID: color.id) === color)
        #expect(try FindColorUseCase(repository: repo)(withID: UUID()) == nil)
        #expect(try LoadColorsUseCase(repository: repo)().count == 1)
    }

    @Test func moveAttachesToANewPaletteAndDetachesFromTheOld() throws {
        let old = OpalitePalette(name: "Old")
        let new = OpalitePalette(name: "New")
        let color = OpaliteColor(red: 0, green: 0, blue: 0, palette: old)
        old.colors = [color]
        let repo = FakeColorRepository(colors: [color])
        let move = MoveColorToPaletteUseCase(repository: repo)

        try move(color, to: new, authorship: authorship)
        #expect(color.palette === new)
        #expect(new.colors?.map(\.id) == [color.id])
        #expect(old.colors?.isEmpty == true)

        try move(color, to: nil, authorship: authorship)
        #expect(color.palette == nil)
        #expect(new.colors?.isEmpty == true)
    }

    @Test func detachingALooseColorIsANoOp() throws {
        let color = OpaliteColor(red: 0, green: 0, blue: 0)
        let repo = FakeColorRepository(colors: [color])
        try MoveColorToPaletteUseCase(repository: repo)(color, to: nil, authorship: authorship)
        #expect(color.palette == nil)
    }
}

@Suite("Palette use-cases")
struct PaletteUseCaseTests {
    let authorship = Authorship(displayName: "Nick", deviceName: "iPhone")

    private func fullRepository() -> FakePaletteRepository {
        FakePaletteRepository(palettes: (0..<OnyxGate.freePaletteLimit).map { OpalitePalette(name: "P\($0)") })
    }

    @Test func createPaletteUnderTheFreeLimit() throws {
        let repo = FakePaletteRepository(palettes: [OpalitePalette(name: "Existing")])
        let donor = RecordingDonor()
        let create = CreatePaletteUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: false), donor: donor)
        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let palette = try create(name: "Sunset", notes: "warm", tags: ["a"], colors: [color], authorship: authorship)
        #expect(palette.name == "Sunset" && palette.notes == "warm" && palette.tags == ["a"])
        #expect(palette.createdByDisplayName == "Nick")
        #expect(color.palette === palette)
        #expect(repo.storage.count == 2)
        #expect(donor.donated == [.createPalette])
    }

    @Test func createPaletteAtTheFreeLimitIsGated() {
        let repo = fullRepository()
        let donor = RecordingDonor()
        let create = CreatePaletteUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: false), donor: donor)
        #expect(throws: PaletteCreationError.limitReached) {
            try create(name: "One more", notes: nil, tags: [], colors: [], authorship: authorship)
        }
        #expect(repo.storage.count == OnyxGate.freePaletteLimit)
        #expect(donor.donated.isEmpty)
    }

    @Test func onyxLiftsTheLimit() throws {
        let repo = fullRepository()
        let create = CreatePaletteUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: true))
        _ = try create(name: "Six", notes: nil, tags: [], colors: [], authorship: authorship)
        #expect(repo.storage.count == OnyxGate.freePaletteLimit + 1)
    }

    @Test func createPaletteWrapsPersistenceErrors() {
        let repo = FakePaletteRepository()
        repo.failure = .fetchFailed("boom")
        let create = CreatePaletteUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: true))
        #expect(throws: PaletteCreationError.persistence(.fetchFailed("boom"))) {
            try create(name: "X", notes: nil, tags: [], colors: [], authorship: authorship)
        }
    }

    @Test func insertPaletteIsGatedTheSameWay() throws {
        let gated = InsertPaletteUseCase(repository: fullRepository(), entitlements: FixedEntitlement(hasOnyx: false))
        #expect(throws: PaletteCreationError.limitReached) { try gated(OpalitePalette(name: "X"), authorship: authorship) }

        let repo = FakePaletteRepository()
        let insert = InsertPaletteUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: false))
        let palette = OpalitePalette(name: "Imported")
        #expect(try insert(palette, authorship: authorship) === palette)
        #expect(palette.createdByDisplayName == "Nick")
    }

    @Test func updateDeleteAndFind() throws {
        let palette = OpalitePalette(name: "P", colors: [OpaliteColor(red: 0, green: 0, blue: 0)])
        let repo = FakePaletteRepository(palettes: [palette])
        try UpdatePaletteUseCase(repository: repo)(palette) { $0.name = "Q"; $0.isArchived = true }
        #expect(palette.name == "Q" && palette.isArchived)
        #expect(try FindPaletteUseCase(repository: repo)(withID: palette.id) === palette)
        #expect(try LoadPalettesUseCase(repository: repo)().count == 1)
        try DeletePaletteUseCase(repository: repo)(palette, deleteColors: false)
        #expect(repo.storage.isEmpty)
        #expect(palette.colors?.first?.palette == nil, "colors become loose")
    }

    @Test func linkCanvasAttachesAndDetaches() throws {
        let palette = OpalitePalette(name: "P")
        let other = OpalitePalette(name: "Other")
        let canvas = CanvasFile(title: "Sketch")
        let repo = FakePaletteRepository(palettes: [palette, other])
        let link = LinkCanvasToPaletteUseCase(repository: repo)

        try link(canvas, to: palette)
        #expect(palette.canvasFile === canvas && canvas.palette === palette)

        try link(canvas, to: other)
        #expect(other.canvasFile === canvas && canvas.palette === other)
        #expect(palette.canvasFile == nil, "a canvas links to one palette")

        try link(nil, to: other)
        #expect(other.canvasFile == nil && canvas.palette == nil)
    }
}

@Suite("Canvas use-cases")
struct CanvasUseCaseTests {
    @Test func createCanvasIsGatedForFreeUsers() throws {
        let repo = FakeCanvasRepository()
        let create = CreateCanvasUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: false))
        let first = try create(title: "First", deviceName: "iPad")
        #expect(first.title == "First" && first.lastEditedDeviceName == "iPad")
        #expect(throws: CanvasCreationError.limitReached) { try create(title: "Second", deviceName: nil) }
        #expect(repo.storage.count == OnyxGate.freeCanvasLimit)
    }

    @Test func onyxCreatesUnlimitedCanvases() throws {
        let repo = FakeCanvasRepository()
        let create = CreateCanvasUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: true))
        for i in 0..<4 { _ = try create(title: "C\(i)", deviceName: nil) }
        #expect(repo.storage.count == 4)
    }

    @Test func createCanvasWrapsPersistenceErrors() {
        let repo = FakeCanvasRepository()
        repo.failure = .saveFailed("x")
        let create = CreateCanvasUseCase(repository: repo, entitlements: FixedEntitlement(hasOnyx: true))
        #expect(throws: CanvasCreationError.persistence(.saveFailed("x"))) { try create(title: "C", deviceName: nil) }
    }

    @Test func updateFindDelete() throws {
        let canvas = CanvasFile(title: "A")
        let repo = FakeCanvasRepository(canvases: [canvas])
        try UpdateCanvasUseCase(repository: repo)(canvas, deviceName: "Mac") { $0.title = "B" }
        #expect(canvas.title == "B")
        #expect(try FindCanvasUseCase(repository: repo)(withID: canvas.id) === canvas)
        #expect(try LoadCanvasesUseCase(repository: repo)().map(\.title) == ["B"])
        try DeleteCanvasUseCase(repository: repo)(canvas)
        #expect(repo.storage.isEmpty)
    }
}

@Suite("Authorship & seams")
struct SeamTests {
    @Test func anonymousAuthorship() {
        #expect(Authorship.anonymous.displayName == "User")
        #expect(Authorship.anonymous.deviceName == nil)
        #expect(Authorship(displayName: "A") == Authorship(displayName: "A", deviceName: nil))
    }

    @Test func fixedEntitlementIsMutable() {
        let entitlement = FixedEntitlement(hasOnyx: false)
        #expect(!entitlement.hasOnyx)
        entitlement.hasOnyx = true
        #expect(entitlement.hasOnyx)
    }

    @Test func genericDeviceDefaults() {
        #expect(GenericDevice().deviceName == "This Device")
        #expect(GenericDevice(deviceName: "Mac").deviceName == "Mac")
    }

    @Test func uncheckedSendableBoxCarriesItsValue() {
        let box = UncheckedSendableBox(value: [1, 2, 3])
        #expect(box.value == [1, 2, 3])
    }

    @Test func uniquedKeepsFirstOccurrences() {
        #expect([3, 1, 3, 2, 1].uniqued() == [3, 1, 2])
        #expect(["aa", "b", "cc", "d"].uniqued(by: \.count) == ["aa", "b"])
        #expect([Int]().uniqued().isEmpty)
    }
}
