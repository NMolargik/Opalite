//
//  ModelTests.swift
//  OpaliteCoreTests
//
//  OpaliteColor, OpalitePalette, CanvasFile, CanvasPlacedImage as plain (unmanaged) models.
//

import Foundation
import CoreGraphics
import Testing
@testable import OpaliteCore
#if canImport(PencilKit)
import PencilKit
#endif

@Suite("OpaliteColor model")
struct OpaliteColorModelTests {
    @Test func defaultsAndIdentity() {
        let color = OpaliteColor(red: 0.2, green: 0.5, blue: 0.8)
        #expect(color.alpha == 1 && color.name == nil && color.notes == nil && color.palette == nil)
        #expect(color.rgba == RGBA(red: 0.2, green: 0.5, blue: 0.8))
        #expect(color.hexString == "#3380CC")
        #expect(color.rgbString == "rgb(51, 128, 204)")
        #expect(color.hslString == color.rgba.hslString)
        #expect(color.hsl == color.rgba.hsl && color.hsv == color.rgba.hsv && color.cmyk == color.rgba.cmyk)
    }

    @Test func displayNameAndHasName() {
        #expect(OpaliteColor(name: "  Mist ", red: 0, green: 0, blue: 0).displayName == "Mist")
        #expect(OpaliteColor(name: "   ", red: 0, green: 0, blue: 0).displayName == "#000000")
        #expect(OpaliteColor(name: nil, red: 1, green: 1, blue: 1).displayName == "#FFFFFF")
        #expect(OpaliteColor(name: "x", red: 0, green: 0, blue: 0).hasName)
        #expect(!OpaliteColor(name: " ", red: 0, green: 0, blue: 0).hasName)
        #expect(!OpaliteColor(red: 0, green: 0, blue: 0).hasName)
    }

    @Test func contrastAndTextPreference() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        let white = OpaliteColor(red: 1, green: 1, blue: 1)
        #expect(black.contrastRatio(against: white).isClose(to: 21, tolerance: 1e-6))
        #expect(black.relativeLuminance == 0)
        #expect(white.prefersDarkText && !black.prefersDarkText)
    }

    @Test func withAlphaClampsAndPreservesMetadata() {
        let palette = OpalitePalette(name: "P")
        let base = OpaliteColor(name: "N", notes: "notes", createdByDisplayName: "Nick", createdAt: Date(timeIntervalSince1970: 1), red: 0.1, green: 0.2, blue: 0.3, palette: palette)
        let half = base.withAlpha(0.5)
        #expect(half.alpha == 0.5)
        #expect(half.name == "N" && half.notes == "notes" && half.createdByDisplayName == "Nick")
        #expect(half.createdAt == base.createdAt)
        #expect(half.palette === palette)
        #expect(half.id != base.id, "a copy with a fresh identity")
        #expect(base.withAlpha(2).alpha == 1)
        #expect(base.withAlpha(-1).alpha == 0)
    }

    @Test func harmonyCopiesAreDetachedAndNamed() {
        let palette = OpalitePalette(name: "P")
        let red = OpaliteColor(name: "Red", red: 1, green: 0, blue: 0, alpha: 0.5, palette: palette)
        let complement = red.complementaryColor()
        #expect(complement.name == "Complementary")
        #expect(complement.palette == nil)
        #expect(complement.alpha == 0.5)
        #expect(complement.rgba.isClose(to: RGBA(red: 0, green: 1, blue: 1, alpha: 0.5)))
        #expect(red.analogousColors().map(\.name) == ["Analogous", "Analogous"])
        #expect(red.triadicColors().count == 2 && red.tetradicColors().count == 3)
        #expect(red.splitComplementaryColors().map(\.name) == ["Split-Comp", "Split-Comp"])
    }

    @Test func simulationPreservesIdentityButDropsThePalette() {
        let palette = OpalitePalette(name: "P")
        let color = OpaliteColor(name: "N", notes: "x", red: 1, green: 0, blue: 0, alpha: 0.7, palette: palette)
        #expect(color.simulatingColorBlindness(.off) === color)
        let simulated = color.simulatingColorBlindness(.protanopia)
        #expect(simulated !== color)
        #expect(simulated.id == color.id && simulated.name == "N" && simulated.notes == "x" && simulated.alpha == 0.7)
        #expect(simulated.palette == nil)
        #expect(simulated.red < 1)
        #expect([color].simulatingColorBlindness(.off).first === color)
        #expect([color].simulatingColorBlindness(.achromatopsia).first?.red == [color].simulatingColorBlindness(.achromatopsia).first?.green)
    }

    @Test func dictionaryRepresentationCarriesEveryFormat() throws {
        let color = OpaliteColor(name: "N", red: 1, green: 0, blue: 0, alpha: 0.5)
        let dict = color.dictionaryRepresentation
        #expect(dict["id"] as? String == color.id.uuidString)
        #expect(dict["hex"] as? String == "#FF0000")
        #expect(dict["hexWithAlpha"] as? String == "#FF000080")
        #expect(dict["rgb"] as? String == "rgb(255, 0, 0)")
        #expect(dict["rgba"] as? String == "rgba(255, 0, 0, 0.5)")
        #expect(dict["hsl"] as? String == "hsl(0, 100%, 50%)")
        #expect(dict["createdOnDeviceName"] as? String == "Unknown")
        #expect(dict["createdByDisplayName"] as? String == "Unknown")
        let json = try color.jsonRepresentation()
        #expect(JSONSerialization.isValidJSONObject(dict))
        #expect(try JSONSerialization.jsonObject(with: json) is [String: Any])
    }

    @Test func samplesAreDistinct() {
        #expect(OpaliteColor.samples.count == 5)
        #expect(Set(OpaliteColor.samples.map(\.hexString)).count == 5)
        #expect(OpaliteColor.sample.name == "Sample Blue")
    }
}

@Suite("OpalitePalette model")
struct OpalitePaletteModelTests {
    @Test func sortedColorsAreNewestFirstWithStableTieBreak() {
        let now = Date()
        let old = OpaliteColor(name: "Old", updatedAt: now.addingTimeInterval(-10), red: 0, green: 0, blue: 0)
        let new = OpaliteColor(name: "New", updatedAt: now, red: 0, green: 0, blue: 0)
        let tieA = OpaliteColor(id: UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000000")!, name: "A", updatedAt: now.addingTimeInterval(-5), red: 0, green: 0, blue: 0)
        let tieB = OpaliteColor(id: UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000000")!, name: "B", updatedAt: now.addingTimeInterval(-5), red: 0, green: 0, blue: 0)
        let palette = OpalitePalette(name: "P", colors: [old, tieA, new, tieB])
        #expect(palette.sortedColors.map(\.name) == ["New", "B", "A", "Old"])
        #expect(palette.colorValues.count == 4)
        #expect(palette.colorCount == 4)
    }

    @Test func emptyPalette() {
        let palette = OpalitePalette(name: "Empty")
        #expect(palette.sortedColors.isEmpty && palette.colorCount == 0 && palette.colorValues.isEmpty)
        palette.colors = nil
        #expect(palette.colorCount == 0 && palette.sortedColors.isEmpty)
    }

    @Test func previewBackgroundRoundTripsThroughTheRawValue() {
        let palette = OpalitePalette(name: "P")
        #expect(palette.previewBackground == nil)
        palette.previewBackground = .forest
        #expect(palette.previewBackgroundRaw == "forest")
        palette.previewBackgroundRaw = "garbage"
        #expect(palette.previewBackground == nil)
        palette.previewBackground = nil
        #expect(palette.previewBackgroundRaw == nil)
    }

    @Test("Suggested export filenames", arguments: [
        ("My Palette", "my-palette.opalite-palette.json"),
        ("  ", "opalite-palette.json"),
        ("Sunset!! Vibes", "sunset-vibes.opalite-palette.json"),
        ("ok", "ok.opalite-palette.json"),
    ])
    func suggestedFilename(name: String, expected: String) {
        #expect(OpalitePalette(name: name).suggestedExportFilename == expected)
    }

    @Test func dictionaryRepresentationIncludesOptionalSections() throws {
        let canvas = CanvasFile(title: "Sketch")
        let palette = OpalitePalette(name: "P", notes: "n", tags: ["t"], isArchived: true, colors: [OpaliteColor(red: 0, green: 0, blue: 0)])
        var dict = palette.dictionaryRepresentation
        #expect(dict["previewBackground"] == nil && dict["canvasFileId"] == nil)
        #expect((dict["colors"] as? [[String: Any]])?.count == 1)
        #expect(dict["isArchived"] as? Bool == true)
        #expect(dict["tags"] as? [String] == ["t"])
        palette.previewBackground = .navy
        palette.canvasFile = canvas
        dict = palette.dictionaryRepresentation
        #expect(dict["previewBackground"] as? String == "navy")
        #expect(dict["canvasFileId"] as? String == canvas.id.uuidString)
        #expect(dict["canvasFileTitle"] as? String == "Sketch")
        #expect(try JSONSerialization.jsonObject(with: try palette.jsonRepresentation()) is [String: Any])
    }

    @Test func sampleHasSixColors() {
        #expect(OpalitePalette.sample.colorCount == 6)
        #expect(OpalitePalette.sample.tags == ["preview", "sample"])
    }
}

@Suite("CanvasFile model")
struct CanvasFileModelTests {
    @Test func defaults() {
        let canvas = CanvasFile()
        #expect(canvas.title == "Untitled Canvas")
        #expect(canvas.drawingData == nil && canvas.thumbnailData == nil && canvas.palette == nil)
        #expect(canvas.canvasSize == nil)
        #expect(CanvasFile.defaultCanvasSize == CGSize(width: 4096, height: 4096))
        #expect(CanvasFile.sample.title == "Sketch")
    }

    @Test func canvasSizeIsSetOnceAndOnlyGrows() {
        let canvas = CanvasFile(title: "C")
        let before = canvas.updatedAt
        canvas.setCanvasSize(CGSize(width: 100, height: 200))
        #expect(canvas.canvasSize == CGSize(width: 100, height: 200))
        #expect(canvas.updatedAt >= before)
        canvas.setCanvasSize(CGSize(width: 1, height: 1))
        #expect(canvas.canvasSize == CGSize(width: 100, height: 200), "later calls are ignored")
        canvas.expandCanvasIfNeeded(to: CGSize(width: 50, height: 300))
        #expect(canvas.canvasSize == CGSize(width: 100, height: 300))
        canvas.expandCanvasIfNeeded(to: CGSize(width: 10, height: 10))
        #expect(canvas.canvasSize == CGSize(width: 100, height: 300), "never shrinks")
    }

    @Test func placedImagesRoundTrip() {
        let canvas = CanvasFile(title: "C")
        #expect(canvas.placedImages.isEmpty)
        let image = CanvasPlacedImage(imageData: Data([1, 2, 3]), position: CGPoint(x: 10, y: 20), size: CGSize(width: 30, height: 40), rotation: 15, zIndex: 2)
        canvas.placedImages = [image]
        #expect(canvas.placedImagesData != nil)
        #expect(canvas.placedImages == [image])
        canvas.placedImages = []
        #expect(canvas.placedImagesData == nil)
        canvas.placedImagesData = Data("corrupt".utf8)
        #expect(canvas.placedImages.isEmpty)
    }

    #if canImport(PencilKit)
    @Test func drawingHelpersTolerateMissingAndCorruptData() {
        let canvas = CanvasFile(title: "C")
        #expect(canvas.loadDrawing().strokes.isEmpty)
        canvas.drawingData = Data("garbage".utf8)
        #expect(canvas.loadDrawing().strokes.isEmpty)
        let before = canvas.updatedAt
        canvas.saveDrawing(PKDrawing())
        #expect(canvas.drawingData != nil)
        #expect(canvas.updatedAt >= before)
        #expect(canvas.loadDrawing().strokes.isEmpty)
    }
    #endif
}

@Suite("CanvasPlacedImage")
struct CanvasPlacedImageTests {
    @Test func boundingRectIsCenteredOnPosition() {
        let image = CanvasPlacedImage(imageData: Data(), position: CGPoint(x: 100, y: 50), size: CGSize(width: 40, height: 20))
        #expect(image.boundingRect == CGRect(x: 80, y: 40, width: 40, height: 20))
        #expect(image.rotation == 0 && image.zIndex == 0)
    }

    @Test func codableUsesFlatKeys() throws {
        let image = CanvasPlacedImage(imageData: Data([9]), position: CGPoint(x: 1, y: 2), size: CGSize(width: 3, height: 4), rotation: 5, zIndex: 6, placedAt: Date(timeIntervalSince1970: 7))
        let data = try JSONEncoder().encode(image)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == ["id", "imageData", "positionX", "positionY", "width", "height", "rotation", "zIndex", "placedAt"])
        #expect(try JSONDecoder().decode(CanvasPlacedImage.self, from: data) == image)
    }

    @Test("fittedSize preserves aspect ratio", arguments: [
        (CGSize(width: 800, height: 400), CGSize(width: 400, height: 200)),
        (CGSize(width: 400, height: 800), CGSize(width: 200, height: 400)),
        (CGSize(width: 100, height: 50), CGSize(width: 100, height: 50)),
        (CGSize(width: 0, height: 50), .zero),
        (CGSize(width: 1000, height: 1000), CGSize(width: 400, height: 400)),
    ])
    func fittedSize(input: CGSize, expected: CGSize) {
        #expect(CanvasPlacedImage.fittedSize(for: input) == expected)
    }

    @Test func fittedSizeHonorsACustomMax() {
        #expect(CanvasPlacedImage.fittedSize(for: CGSize(width: 300, height: 150), maxSize: CGSize(width: 100, height: 100)) == CGSize(width: 100, height: 50))
    }
}
