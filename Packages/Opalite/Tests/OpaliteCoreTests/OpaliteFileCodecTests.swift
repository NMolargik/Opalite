//
//  OpaliteFileCodecTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("OpaliteFileCodec")
struct OpaliteFileCodecTests {
    private func makeColor() -> OpaliteColor {
        OpaliteColor(name: "Dusty Rose", notes: "warm", createdByDisplayName: "Nick", createdOnDeviceName: "iPhone", updatedOnDeviceName: "iPad",
                     createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_500),
                     red: 0.8, green: 0.5, blue: 0.55, alpha: 0.9)
    }

    @Test func colorRoundTripsThroughTheNativeJSON() throws {
        let color = makeColor()
        let decoded = try OpaliteFileCodec.decodeColor(from: try color.jsonRepresentation())
        #expect(decoded.id == color.id)
        #expect(decoded.name == "Dusty Rose")
        #expect(decoded.notes == "warm")
        #expect(decoded.rgba == color.rgba)
        #expect(decoded.createdByDisplayName == "Nick")
        #expect(decoded.createdOnDeviceName == "iPhone")
        #expect(decoded.updatedOnDeviceName == "iPad")
        #expect(decoded.createdAt.timeIntervalSince1970.isClose(to: 1_700_000_000))
        #expect(decoded.updatedAt.timeIntervalSince1970.isClose(to: 1_700_000_500))
    }

    @Test func nilNameSurvivesAsNil() throws {
        let color = OpaliteColor(red: 0.1, green: 0.2, blue: 0.3)
        let decoded = try OpaliteFileCodec.decodeColor(from: try color.jsonRepresentation())
        #expect(decoded.name == nil)
        #expect(decoded.notes == nil)
        #expect(decoded.rgba.alpha == 1)
    }

    @Test func decodedColorMakesAnEquivalentModel() throws {
        let decoded = try OpaliteFileCodec.decodeColor(from: try makeColor().jsonRepresentation())
        let model = decoded.makeModel()
        #expect(model.id == decoded.id && model.name == decoded.name && model.rgba == decoded.rgba)
        #expect(model.createdByDisplayName == "Nick" && model.palette == nil)
    }

    @Test func invalidPayloadsThrowInvalidFormat() {
        #expect(throws: OpaliteFileError.invalidFormat) { try OpaliteFileCodec.decodeColor(from: Data("not json".utf8)) }
        #expect(throws: OpaliteFileError.invalidFormat) { try OpaliteFileCodec.decodeColor(from: Data("[1,2,3]".utf8)) }
        #expect(throws: OpaliteFileError.invalidFormat) { try OpaliteFileCodec.decodePalette(from: Data()) }
    }

    @Test func missingFieldsThrow() {
        #expect(throws: OpaliteFileError.missingRequiredFields) {
            try OpaliteFileCodec.decodeColor(json: ["id": UUID().uuidString, "red": 1.0, "green": 0.0])
        }
        #expect(throws: OpaliteFileError.missingRequiredFields) {
            try OpaliteFileCodec.decodeColor(json: ["id": "nope", "red": 1.0, "green": 0.0, "blue": 0.0])
        }
        #expect(throws: OpaliteFileError.missingRequiredFields) {
            try OpaliteFileCodec.decodeColor(json: ["red": 1.0, "green": 0.0, "blue": 0.0])
        }
        #expect(throws: OpaliteFileError.missingRequiredFields) {
            try OpaliteFileCodec.decodePalette(from: Data("{\"id\":\"\(UUID().uuidString)\"}".utf8))
        }
    }

    @Test func minimalColorUsesDefaults() throws {
        let decoded = try OpaliteFileCodec.decodeColor(json: ["id": UUID().uuidString, "red": 0.5, "green": 0.25, "blue": 1.0])
        #expect(decoded.rgba.alpha == 1 && decoded.name == nil)
        #expect(abs(decoded.createdAt.timeIntervalSinceNow) < 5)
    }

    @Test func colorValuesToleratesAMissingID() {
        #expect(OpaliteFileCodec.decodeColorValues(json: ["red": 0.5, "green": 0.25, "blue": 1.0, "alpha": 0.5]) == RGBA(red: 0.5, green: 0.25, blue: 1, alpha: 0.5))
        #expect(OpaliteFileCodec.decodeColorValues(json: ["red": 0.5, "green": 0.25]) == nil)
    }

    @Test func paletteRoundTrips() throws {
        let c1 = makeColor()
        let c2 = OpaliteColor(name: "Mist", red: 0.1, green: 0.2, blue: 0.3)
        let palette = OpalitePalette(name: "Sunset", createdByDisplayName: "Nick", notes: "warm", tags: ["a", "b"], colors: [c1, c2])
        palette.previewBackground = .navy
        let decoded = try OpaliteFileCodec.decodePalette(from: try palette.jsonRepresentation())
        #expect(decoded.id == palette.id)
        #expect(decoded.name == "Sunset" && decoded.notes == "warm" && decoded.tags == ["a", "b"])
        #expect(decoded.createdByDisplayName == "Nick")
        #expect(decoded.previewBackgroundRaw == PreviewBackground.navy.rawValue)
        #expect(Set(decoded.colors.map(\.id)) == [c1.id, c2.id])
        #expect(decoded.colors.count == 2)
    }

    @Test func paletteWithABadColorThrows() throws {
        let json: [String: Any] = ["id": UUID().uuidString, "name": "P", "colors": [["id": UUID().uuidString, "red": 1.0]]]
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: OpaliteFileError.missingRequiredFields) { try OpaliteFileCodec.decodePalette(from: data) }
    }

    @Test func decodedPaletteMakesAModelWithBackReferences() throws {
        let palette = OpalitePalette(name: "Sunset", colors: [OpaliteColor(name: "A", red: 1, green: 0, blue: 0)])
        palette.previewBackground = .cream
        let decoded = try OpaliteFileCodec.decodePalette(from: try palette.jsonRepresentation())
        let model = decoded.makeModel()
        #expect(model.id == palette.id && model.name == "Sunset")
        #expect(model.colors?.count == 1)
        #expect(model.colors?.first?.palette === model)
        #expect(model.previewBackground == .cream)
    }

    @Test("Kind by extension", arguments: [
        ("swatch.opalitecolor", OpaliteFileCodec.Kind.color),
        ("SWATCH.OPALITECOLOR", .color),
        ("set.opalitepalette", .palette),
        ("set.txt", nil),
        ("noext", nil),
    ])
    func kind(path: String, expected: OpaliteFileCodec.Kind?) {
        #expect(OpaliteFileCodec.kind(of: URL(fileURLWithPath: "/tmp/\(path)")) == expected)
    }

    @Test("Error descriptions are non-empty", arguments: [
        OpaliteFileError.invalidFormat, .missingRequiredFields, .fileAccessDenied, .unsupportedExtension("txt"),
    ])
    func errorDescriptions(error: OpaliteFileError) {
        #expect(!(error.errorDescription ?? "").isEmpty)
    }
}

@Suite("Import previews")
struct ImportPreviewTests {
    @Test func colorPreviewMarksExistingAsSkipped() throws {
        let color = OpaliteColor(red: 0.3, green: 0.3, blue: 0.3)
        let data = try color.jsonRepresentation()
        let fresh = try OpaliteFileCodec.previewColorImport(data: data, existingColorIDs: [])
        #expect(!fresh.willSkip && fresh.existingColorID == nil && fresh.color.id == color.id)
        let dup = try OpaliteFileCodec.previewColorImport(data: data, existingColorIDs: [color.id, UUID()])
        #expect(dup.willSkip && dup.existingColorID == color.id)
    }

    @Test func palettePreviewSplitsNewAndExistingColors() throws {
        let known = OpaliteColor(name: "Known", red: 0, green: 0, blue: 0)
        let new = OpaliteColor(name: "New", red: 1, green: 1, blue: 1)
        let palette = OpalitePalette(name: "P", colors: [known, new])
        let data = try palette.jsonRepresentation()

        let fresh = try OpaliteFileCodec.previewPaletteImport(data: data, existingPaletteIDs: [], existingColorIDs: [known.id])
        #expect(!fresh.willUpdate)
        #expect(fresh.newColors.map(\.id) == [new.id])
        #expect(fresh.existingColorIDs == [known.id])

        let update = try OpaliteFileCodec.previewPaletteImport(data: data, existingPaletteIDs: [palette.id], existingColorIDs: [])
        #expect(update.willUpdate && update.existingPaletteID == palette.id)
        #expect(update.newColors.count == 2 && update.existingColorIDs.isEmpty)
    }

    @Test func previewsPropagateDecodeErrors() {
        #expect(throws: OpaliteFileError.invalidFormat) { try OpaliteFileCodec.previewColorImport(data: Data("x".utf8), existingColorIDs: []) }
        #expect(throws: OpaliteFileError.invalidFormat) { try OpaliteFileCodec.previewPaletteImport(data: Data("x".utf8), existingPaletteIDs: [], existingColorIDs: []) }
    }
}
