//
//  ExportEncodersTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

// MARK: - Tiny readers for the binary formats

private struct ASEDocument {
    struct Block { let type: UInt16; let name: String?; let rgb: (Float, Float, Float)? }
    let blockCount: UInt32
    let blocks: [Block]

    init?(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 12, Array(bytes[0..<4]) == [0x41, 0x53, 0x45, 0x46] else { return nil }
        func u16(_ i: Int) -> UInt16 { UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1]) }
        func u32(_ i: Int) -> UInt32 { (0..<4).reduce(0) { $0 << 8 | UInt32(bytes[i + $1]) } }
        blockCount = u32(8)
        var offset = 12
        var blocks: [Block] = []
        while offset + 6 <= bytes.count {
            let type = u16(offset)
            let length = Int(u32(offset + 2))
            let start = offset + 6
            var name: String?
            var rgb: (Float, Float, Float)?
            if type == 0x0001 || type == 0xC001 {
                let units = Int(u16(start))
                let utf16 = (0..<(units - 1)).map { u16(start + 2 + $0 * 2) }
                name = String(utf16CodeUnits: utf16, count: utf16.count)
                if type == 0x0001 {
                    let modelStart = start + 2 + units * 2
                    let f = { (i: Int) -> Float in Float(bitPattern: u32(modelStart + 4 + i * 4)) }
                    rgb = (f(0), f(1), f(2))
                }
            }
            blocks.append(Block(type: type, name: name, rgb: rgb))
            offset = start + length
        }
        self.blocks = blocks
    }
}

private struct StoredZip {
    let filename: String
    let crc: UInt32
    let content: Data

    init?(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count > 30, Array(bytes[0..<4]) == [0x50, 0x4B, 0x03, 0x04] else { return nil }
        func u16(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i + 1]) << 8 }
        func u32(_ i: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(bytes[i + $1]) << (8 * UInt32($1)) } }
        crc = u32(14)
        let size = Int(u32(18))
        let nameLength = u16(26)
        let extraLength = u16(28)
        filename = String(decoding: bytes[30..<(30 + nameLength)], as: UTF8.self)
        let contentStart = 30 + nameLength + extraLength
        content = Data(bytes[contentStart..<(contentStart + size)])
    }
}

@Suite("ExportEncoders — ASE")
struct ASEEncoderTests {
    let rose = ExportSwatch(name: "Dusty Rose", rgba: RGBA(red: 0.8, green: 0.5, blue: 0.55))
    let unnamed = ExportSwatch(name: "  ", rgba: RGBA(red: 0, green: 0, blue: 1))

    @Test func resolvedNameFallsBackToHex() {
        #expect(rose.resolvedName == "Dusty Rose")
        #expect(unnamed.resolvedName == "#0000FF")
        #expect(ExportSwatch(name: nil, rgba: .black).resolvedName == "#000000")
    }

    @Test func singleColorDocumentHeader() throws {
        let data = ExportEncoders.ase(rose)
        let bytes = [UInt8](data)
        #expect(Array(bytes[0..<4]) == [0x41, 0x53, 0x45, 0x46], "ASEF signature")
        #expect(Array(bytes[4..<8]) == [0x00, 0x01, 0x00, 0x00], "version 1.0")
        #expect(Array(bytes[8..<12]) == [0x00, 0x00, 0x00, 0x01], "one block")
        #expect(Array(bytes[12..<14]) == [0x00, 0x01], "color entry")
        let doc = try #require(ASEDocument(data))
        #expect(doc.blocks.count == 1)
        #expect(doc.blocks[0].name == "Dusty Rose")
        let rgb = try #require(doc.blocks[0].rgb)
        #expect(Double(rgb.0).isClose(to: 0.8) && Double(rgb.1).isClose(to: 0.5) && Double(rgb.2).isClose(to: 0.55))
    }

    @Test func groupedDocumentWrapsColorsInGroupMarkers() throws {
        let data = ExportEncoders.ase(groupName: "Sunset", swatches: [rose, unnamed])
        let doc = try #require(ASEDocument(data))
        #expect(doc.blockCount == 4, "group start + 2 colors + group end")
        #expect(doc.blocks.map(\.type) == [0xC001, 0x0001, 0x0001, 0xC002])
        #expect(doc.blocks[0].name == "Sunset")
        #expect(doc.blocks[1].name == "Dusty Rose")
        #expect(doc.blocks[2].name == "#0000FF")
        #expect([UInt8](data.suffix(6)) == [0xC0, 0x02, 0, 0, 0, 0])
    }

    @Test func emptyGroupStillHasMarkers() throws {
        let doc = try #require(ASEDocument(ExportEncoders.ase(groupName: "Empty", swatches: [])))
        #expect(doc.blockCount == 2)
        #expect(doc.blocks.map(\.type) == [0xC001, 0xC002])
    }

    @Test func namesAreUTF16() throws {
        let doc = try #require(ASEDocument(ExportEncoders.ase(ExportSwatch(name: "Café ☕", rgba: .black))))
        #expect(doc.blocks[0].name == "Café ☕")
    }
}

@Suite("ExportEncoders — text formats")
struct TextEncoderTests {
    let swatches = [
        ExportSwatch(name: "Dusty Rose", rgba: RGBA(red: 1, green: 0, blue: 0)),
        ExportSwatch(name: nil, rgba: RGBA(red: 0, green: 0, blue: 1, alpha: 0.5)),
    ]

    @Test func gplShape() {
        let text = String(decoding: ExportEncoders.gpl(name: "Sunset", swatches: swatches), as: UTF8.self)
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "GIMP Palette")
        #expect(lines[1] == "Name: Sunset")
        #expect(lines[2] == "Columns: 2")
        #expect(lines[3] == "#")
        #expect(lines[4] == "255   0   0\tDusty Rose")
        #expect(lines[5] == "  0   0 255\t#0000FF")
        #expect(lines.count == 6)
    }

    @Test func gplColumnsClampBetweenOneAndSixteen() {
        let none = String(decoding: ExportEncoders.gpl(name: "N", swatches: []), as: UTF8.self)
        #expect(none.contains("Columns: 1"))
        let many = (0..<20).map { _ in ExportSwatch(name: nil, rgba: .black) }
        #expect(String(decoding: ExportEncoders.gpl(name: "M", swatches: many), as: UTF8.self).contains("Columns: 16"))
    }

    @Test func cssShape() {
        let text = String(decoding: ExportEncoders.css(title: "Sunset", prefix: nil, swatches: swatches), as: UTF8.self)
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "/* Sunset - Exported from Opalite */")
        #expect(lines[1] == ":root {")
        #expect(lines[2] == "  --dusty-rose: rgb(255, 0, 0);")
        #expect(lines[3] == "  --dusty-rose-hex: #FF0000;")
        #expect(lines[4] == "  --0000ff: rgba(0, 0, 255, 0.50);")
        #expect(lines[5] == "  --0000ff-hex: #0000FF;")
        #expect(lines.last == "}")
    }

    @Test func cssPrefixIsSlugged() {
        let text = String(decoding: ExportEncoders.css(title: "T", prefix: "My Palette!", swatches: [swatches[0]]), as: UTF8.self)
        #expect(text.contains("--my-palette-dusty-rose: rgb(255, 0, 0);"))
        #expect(text.contains("--my-palette-dusty-rose-hex: #FF0000;"))
        let empty = String(decoding: ExportEncoders.css(title: "T", prefix: "!!!", swatches: [swatches[0]]), as: UTF8.self)
        #expect(empty.contains("--color-dusty-rose:"), "an unsluggable prefix falls back to 'color'")
    }

    @Test("CSS slugs", arguments: [
        ("Dusty Rose", "dusty-rose"), ("  Ocean  Mist ", "--ocean--mist-"), ("#FF5733", "ff5733"), ("", "color"), ("!!!", "color"), ("Café", "caf"),
    ])
    func cssSlug(input: String, expected: String) {
        #expect(ExportEncoders.cssSlug(input) == expected)
    }

    @Test func swiftUIShapeForOneSwatch() {
        let text = String(decoding: ExportEncoders.swiftUI(title: "Dusty Rose", prefix: nil, swatches: [swatches[0]]), as: UTF8.self)
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0] == "// Dusty Rose - Exported from Opalite")
        #expect(lines[1] == "import SwiftUI")
        #expect(lines[3] == "extension Color {")
        #expect(lines[4] == "    static let dustyRose = Color(")
        #expect(lines[5] == "        red: 1.000,")
        #expect(lines[6] == "        green: 0.000,")
        #expect(lines[7] == "        blue: 0.000,")
        #expect(lines[8] == "        opacity: 1.00")
        #expect(lines[9] == "    )")
        #expect(lines[10] == "}")
        #expect(text.hasSuffix("// Usage: Color.dustyRose\n// Hex: #FF0000"))
    }

    @Test func swiftUIForManySwatchesHasNoUsageLineAndUsesPrefix() {
        let text = String(decoding: ExportEncoders.swiftUI(title: "Sunset", prefix: "My Palette", swatches: swatches), as: UTF8.self)
        #expect(!text.contains("// Usage"))
        #expect(text.contains("static let mypaletteDustyRose = Color("))
        #expect(text.contains("static let mypaletteColor0000ff = Color("))
        #expect(text.contains("opacity: 0.50"))
        #expect(text.hasSuffix("}"))
        #expect(!text.contains("\n\n}"), "no blank line before the closing brace")
    }

    @Test("lowerCamel", arguments: [
        ("Dusty Rose", "dustyRose"), ("#FF5733", "ff5733"), ("123 Go", "color123Go"), ("", "customColor"), ("!!!", "customColor"),
        ("ocean   MIST blue", "oceanMistBlue"), ("Red", "red"),
    ])
    func lowerCamel(input: String, expected: String) {
        #expect(ExportEncoders.lowerCamel(input) == expected)
    }

    @Test("upperCamel", arguments: [("dusty rose", "DustyRose"), ("my palette!", "MyPalette"), ("", "")])
    func upperCamel(input: String, expected: String) {
        #expect(ExportEncoders.upperCamel(input) == expected)
    }

    @Test("sanitizedFilename", arguments: [
        ("my sunset palette!", "MySunsetPalette"), ("", "Untitled"), ("   ", "Untitled"), ("!!!", "Untitled"),
        ("  a-b_c ", "A-b_c"), ("Ocean Mist", "OceanMist"), ("x", "X"),
    ])
    func sanitizedFilename(input: String, expected: String) {
        #expect(ExportEncoders.sanitizedFilename(input) == expected)
    }

    @Test func filenameFromHex() {
        #expect(ExportEncoders.filename(fromHex: "#FF5733") == "FF5733")
        #expect(ExportEncoders.filename(fromHex: "FF5733") == "FF5733")
    }
}

@Suite("ExportEncoders — Procreate & ZIP")
struct ProcreateEncoderTests {
    @Test func crc32KnownVectors() {
        #expect(ZipArchive.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
        #expect(ZipArchive.crc32(Data()) == 0)
        #expect(ZipArchive.crc32(Data("a".utf8)) == 0xE8B7_BE43)
        #expect(ZipArchive.crc32(Data("hello".utf8)) == ZipArchive.crc32(Data("hello".utf8)))
    }

    @Test func dosDateTimePacksFields() {
        var components = DateComponents()
        components.year = 2024; components.month = 1; components.day = 2
        components.hour = 3; components.minute = 4; components.second = 6
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let dos = ZipArchive.dosDateTime(date)
        #expect(dos.date == UInt16((44 << 9) | (1 << 5) | 2))
        #expect(dos.time == UInt16((3 << 11) | (4 << 5) | 3))
    }

    @Test func dosDateClampsBefore1980() {
        var components = DateComponents()
        components.year = 1970; components.month = 6; components.day = 15
        let date = Calendar(identifier: .gregorian).date(from: components)!
        #expect(ZipArchive.dosDateTime(date).date >> 9 == 0)
    }

    @Test func storedZipHasSignaturesAndIntactEntry() throws {
        let content = Data("{\"hello\":1}".utf8)
        let zip = ZipArchive.stored(filename: "Swatches.json", content: content)
        #expect([UInt8](zip.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])
        #expect([UInt8](zip.suffix(22).prefix(4)) == [0x50, 0x4B, 0x05, 0x06], "end of central directory")
        let entry = try #require(StoredZip(zip))
        #expect(entry.filename == "Swatches.json")
        #expect(entry.content == content)
        #expect(entry.crc == ZipArchive.crc32(content))
        let cdSignature: [UInt8] = [0x50, 0x4B, 0x01, 0x02]
        #expect(zip.range(of: Data(cdSignature)) != nil, "central directory present")
    }

    @Test func procreateSwatchesIsAZipOfSwatchesJSON() throws {
        let swatches = [
            ExportSwatch(name: "Red", rgba: RGBA(red: 1, green: 0, blue: 0)),
            ExportSwatch(name: nil, rgba: RGBA(red: 0, green: 0.5, blue: 1, alpha: 0.4)),
        ]
        let data = try ExportEncoders.procreateSwatches(name: "Sunset", swatches: swatches)
        let entry = try #require(StoredZip(data))
        #expect(entry.filename == "Swatches.json")
        let json = try #require(try JSONSerialization.jsonObject(with: entry.content) as? [String: Any])
        #expect(json["name"] as? String == "Sunset")
        let list = try #require(json["swatches"] as? [[String: Any]])
        #expect(list.count == 2)
        #expect((list[0]["hue"] as? Double)?.isClose(to: 0) == true)
        #expect((list[0]["saturation"] as? Double)?.isClose(to: 1) == true)
        #expect((list[0]["brightness"] as? Double)?.isClose(to: 1) == true)
        #expect(list[0]["colorSpace"] as? Int == 0)
        #expect((list[1]["alpha"] as? Double)?.isClose(to: 0.4) == true)
        let hsv = swatches[1].rgba.hsv
        #expect((list[1]["hue"] as? Double)?.isClose(to: hsv.hue / 360) == true)
    }
}

@Suite("Export formats")
struct ExportFormatTests {
    @Test func colorFreeFormats() {
        #expect(Set(ColorExportFormat.allCases.filter(\.isFreeFormat)) == [.opalite, .image])
        #expect(ColorExportFormat.allCases.count == 7)
    }

    @Test func paletteFreeFormats() {
        #expect(Set(PaletteExportFormat.allCases.filter(\.isFreeFormat)) == [.opalite, .image, .pdf])
        #expect(PaletteExportFormat.allCases.count == 8)
    }

    @Test func extensionsAndTypes() {
        #expect(ColorExportFormat.opalite.fileExtension == OpaliteFileType.colorExtension)
        #expect(PaletteExportFormat.opalite.fileExtension == OpaliteFileType.paletteExtension)
        #expect(ColorExportFormat.opalite.utTypeIdentifier == OpaliteFileType.colorIdentifier)
        #expect(PaletteExportFormat.opalite.utTypeIdentifier == OpaliteFileType.paletteIdentifier)
        #expect(ColorExportFormat.allCases.filter { $0 != .opalite }.allSatisfy { $0.utTypeIdentifier == nil })
        #expect(ColorExportFormat.allCases.allSatisfy { !$0.fileExtension.isEmpty && !$0.systemImage.isEmpty && $0.id == $0.rawValue })
        #expect(PaletteExportFormat.allCases.allSatisfy { !$0.fileExtension.isEmpty && !$0.systemImage.isEmpty })
        #expect(PaletteExportFormat.pdf.fileExtension == "pdf")
        #expect(ColorExportFormat.swiftui.fileExtension == "swift")
    }
}
