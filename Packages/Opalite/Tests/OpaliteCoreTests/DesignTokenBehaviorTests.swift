//
//  DesignTokenBehaviorTests.swift
//  OpaliteCoreTests
//

import Foundation
import Testing
@testable import OpaliteCore

@Suite("Token naming")
struct TokenNamingTests {
    private func swatch(_ name: String?) -> ExportSwatch { ExportSwatch(name: name, rgba: RGBA(red: 1, green: 0.34, blue: 0.2)) }

    @Test func wordsFoldDiacriticsAndDropSymbols() {
        #expect(TokenNaming.words("Crème Brûlée #2") == ["creme", "brulee", "2"])
        #expect(TokenNaming.words("  --  ").isEmpty)
        #expect(TokenNaming.words("夕焼け").isEmpty)
    }

    @Test func styles() {
        let swatches = [swatch("Dusty Rose")]
        #expect(TokenNaming.uniqueNames(for: swatches, style: .kebab) == ["dusty-rose"])
        #expect(TokenNaming.uniqueNames(for: swatches, style: .snake) == ["dusty_rose"])
        #expect(TokenNaming.uniqueNames(for: swatches, style: .lowerCamel) == ["dustyRose"])
        #expect(TokenNaming.uniqueNames(for: swatches, style: .title) == ["Dusty Rose"])
        #expect(TokenNaming.uniqueNames(for: swatches, prefix: "Ocean", style: .kebab) == ["ocean-dusty-rose"])
    }

    @Test func collisionsAfterSanitizingGetNumbers() {
        let swatches = [swatch("Dusty Rose"), swatch("dusty-rose"), swatch("DUSTY ROSE!"), swatch("Dusty Rose 2")]
        #expect(TokenNaming.uniqueNames(for: swatches, style: .kebab) == ["dusty-rose", "dusty-rose-2", "dusty-rose-3", "dusty-rose-2-2"])
        #expect(TokenNaming.uniqueNames(for: swatches, style: .lowerCamel) == ["dustyRose", "dustyRose2", "dustyRose3", "dustyRose22"])
    }

    @Test func titleNamesCollideCaseInsensitively() {
        let names = TokenNaming.uniqueNames(for: [swatch("sky"), swatch("SKY")], style: .title)
        #expect(Set(names.map { $0.lowercased() }).count == 2)
    }

    @Test func unnamedAndNonLatinFallBackToHex() {
        let names = TokenNaming.uniqueNames(for: [swatch(nil), swatch("夕焼け")], style: .kebab)
        #expect(names == ["ff5733", "ff5733-2"])
    }

    @Test func leadingDigitsAndReservedWords() {
        let digits = [ExportSwatch(name: "123 abc", rgba: .black)]
        #expect(TokenNaming.uniqueNames(for: digits, style: .lowerCamel) == ["color123Abc"])
        #expect(TokenNaming.uniqueNames(for: digits, style: .kebab, leadingLetter: false) == ["123-abc"])
        let reserved = [swatch("default"), swatch("class"), swatch("Color")]
        #expect(TokenNaming.uniqueNames(for: reserved, style: .lowerCamel, reserved: TokenNaming.dartReserved) == ["defaultColor", "classColor", "color"])
        #expect(TokenNaming.uniqueNames(for: reserved, style: .snake, reserved: TokenNaming.androidReserved) == ["default_color", "class_color", "color"])
    }

    @Test func companionSuffixIsReserved() {
        let names = TokenNaming.uniqueNames(for: [swatch("sky"), swatch("sky dark")], style: .snake, companionSuffix: "_dark")
        #expect(names == ["sky", "sky_dark_2"])
    }

    @Test func typeNames() {
        #expect(TokenNaming.typeName("summer sunset", fallback: "Opalite") == "SummerSunset")
        #expect(TokenNaming.typeName("2024 brand", fallback: "Palette") == "Palette2024Brand")
        #expect(TokenNaming.typeName("夕焼け", fallback: "Opalite") == "Opalite")
        #expect(TokenNaming.typeName(nil, fallback: "Opalite") == "Opalite")
    }
}

@Suite("Design token encoders")
struct DesignTokenEncoderBehaviorTests {
    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func jsonOutputsAreValid() throws {
        for dark in [false, true] {
            let set = DesignTokenFixtures.set(dark: dark)
            for kind in [DesignTokenKind.dtcg, .json, .figma] {
                _ = try object(kind.encode(set, catalogName: "X"))
            }
        }
    }

    @Test func dtcgTokensFollowTheColorModule() throws {
        let root = try object(DesignTokenEncoders.dtcg(DesignTokenFixtures.set(dark: true)))
        let group = try #require(root["summer-sunset"] as? [String: Any])
        #expect(group.count == DesignTokenFixtures.swatches.count)
        for (_, value) in group {
            let token = try #require(value as? [String: Any])
            #expect(token["$type"] as? String == "color")
            let color = try #require(token["$value"] as? [String: Any])
            #expect(["srgb", "display-p3", "oklch"].contains(color["colorSpace"] as? String ?? ""))
            #expect((color["components"] as? [Double])?.count == 3)
            #expect((color["hex"] as? String)?.range(of: "^#[0-9a-f]{6}$", options: .regularExpression) != nil)
        }
        let lime = try #require(group["neon-lime"] as? [String: Any])
        #expect((lime["$value"] as? [String: Any])?["colorSpace"] as? String == "display-p3")
        let glass = try #require((group["glass"] as? [String: Any])?["$value"] as? [String: Any])
        #expect(glass["alpha"] as? Double == 0.5)
    }

    @Test func singleColorHasNoGroup() throws {
        let set = TokenSet(title: "Rose", prefix: nil, swatches: [ExportSwatch(name: "Rose", rgba: RGBA(red: 0.8, green: 0.5, blue: 0.55))])
        let root = try object(DesignTokenEncoders.dtcg(set))
        #expect(root["rose"] != nil)
        let css = String(decoding: DesignTokenEncoders.tailwind(set), as: UTF8.self)
        #expect(css.contains("--color-rose: oklch("))
    }

    @Test func tailwindFlagsOutOfGamutColors() {
        let css = String(decoding: DesignTokenEncoders.tailwind(DesignTokenFixtures.set(dark: false)), as: UTF8.self)
        #expect(css.contains("neon-lime: oklch(") && css.contains("/* outside sRGB, fallback #00FE24 */"))
        #expect(css.components(separatedBy: "outside sRGB").count == 2, "only the wide color is flagged")
        #expect(!css.contains("prefers-color-scheme"))
    }

    @Test func darkVariantsAreOptional() {
        let light = DesignTokenFixtures.set(dark: false)
        #expect(!String(decoding: DesignTokenEncoders.androidColorsXML(light), as: UTF8.self).contains("_dark"))
        #expect(!String(decoding: DesignTokenEncoders.flutter(light), as: UTF8.self).contains("Dark"))
        #expect(!String(decoding: DesignTokenEncoders.scss(light), as: UTF8.self).contains("-dark"))
        #expect(!String(decoding: DesignTokenEncoders.figmaVariables(light), as: UTF8.self).contains("Dark"))
        let files = DesignTokenEncoders.xcassetsFiles(light)
        #expect(files.allSatisfy { !String(decoding: $0.data, as: UTF8.self).contains("luminosity") })
    }

    @Test func xcassetsUsesDisplayP3ForWideColorsAndDarkAppearances() {
        let files = DesignTokenEncoders.xcassetsFiles(DesignTokenFixtures.set(dark: true))
        #expect(files.count == DesignTokenFixtures.swatches.count + 1)
        let lime = files.first { $0.path.contains("Neon Lime") }.map { String(decoding: $0.data, as: UTF8.self) } ?? ""
        #expect(lime.contains("\"color-space\" : \"display-p3\""))
        let rose = files.first { $0.path == "Summer Sunset Dusty Rose.colorset/Contents.json" }.map { String(decoding: $0.data, as: UTF8.self) } ?? ""
        #expect(rose.contains("\"value\" : \"dark\"") && rose.contains("\"color-space\" : \"srgb\""))
        let paths = files.map { $0.path.lowercased() }
        #expect(Set(paths).count == paths.count)
    }

    @Test func xcassetsArchiveListsEveryFileUnderTheCatalogFolder() throws {
        let set = DesignTokenFixtures.set(dark: true)
        let archive = DesignTokenEncoders.xcassetsArchive(set, catalogName: "SummerSunset", date: Date(timeIntervalSince1970: 1_700_000_000))
        let entries = try ZipReader.entries(archive)
        #expect(entries.map(\.path) == DesignTokenEncoders.xcassetsFiles(set).map { "SummerSunset.xcassets/\($0.path)" })
        for (entry, file) in zip(entries, DesignTokenEncoders.xcassetsFiles(set)) {
            #expect(entry.data == file.data)
            #expect(entry.crc == ZipArchive.crc32(file.data))
        }
    }

    @Test func pairingStopsAtTheShorterPalette() {
        let set = TokenSet(
            title: "T", prefix: "T",
            swatches: DesignTokenFixtures.swatches,
            darkSwatches: [DesignTokenFixtures.darkSwatches[0]]
        )
        let xml = String(decoding: DesignTokenEncoders.androidColorsXML(set), as: UTF8.self)
        #expect(xml.components(separatedBy: "_dark\"").count == 2)
    }

    @Test func commentsCannotBreakOutOfTheirSyntax() {
        let set = TokenSet(title: "a -- b */ c", prefix: nil, swatches: [ExportSwatch(name: "x", rgba: .black)])
        #expect(!String(decoding: DesignTokenEncoders.androidColorsXML(set), as: UTF8.self).contains("a -- b"))
        #expect(String(decoding: DesignTokenEncoders.tailwind(set), as: UTF8.self).components(separatedBy: "*/").count == 2)
    }

    @Test func emptyPaletteStillProducesValidFiles() throws {
        let set = TokenSet(title: "Empty", prefix: "Empty", swatches: [])
        for kind in DesignTokenKind.allCases { #expect(!kind.encode(set, catalogName: "Empty").isEmpty) }
        _ = try object(DesignTokenEncoders.json(set))
    }
}

@Suite("Zip archive")
struct ZipArchiveTests {
    @Test func singleEntryMatchesTheLegacyLayout() throws {
        let entries = try ZipReader.entries(ZipArchive.stored(filename: "Swatches.json", content: Data("{}".utf8), date: Date(timeIntervalSince1970: 0)))
        #expect(entries.count == 1 && entries[0].path == "Swatches.json" && entries[0].data == Data("{}".utf8))
    }

    @Test func multipleEntriesKeepOffsetsStraight() throws {
        let entries = (0..<4).map { ZipEntry(path: "dir/file\($0).txt", content: Data(String(repeating: "x", count: $0 * 10).utf8)) }
        let read = try ZipReader.entries(ZipArchive.stored(entries: entries))
        #expect(read.map(\.path) == entries.map(\.path))
        #expect(read.map(\.data) == entries.map(\.content))
    }
}

/// A minimal reader for stored ZIPs, driven by the central directory.
enum ZipReader {
    struct Entry { let path: String; let data: Data; let crc: UInt32 }
    struct Malformed: Error {}

    static func entries(_ zip: Data) throws -> [Entry] {
        let bytes = [UInt8](zip)
        func u16(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i + 1]) << 8 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }
        guard let eocd = (0...(bytes.count - 22)).reversed().first(where: { bytes[$0...$0 + 3] == [0x50, 0x4B, 0x05, 0x06] }) else { throw Malformed() }
        let count = u16(eocd + 10)
        var offset = u32(eocd + 16)
        var result: [Entry] = []
        for _ in 0..<count {
            guard bytes[offset...offset + 3] == [0x50, 0x4B, 0x01, 0x02] else { throw Malformed() }
            let crc = UInt32(u32(offset + 16))
            let size = u32(offset + 24)
            let nameLength = u16(offset + 28)
            let extra = u16(offset + 30), comment = u16(offset + 32)
            let local = u32(offset + 42)
            let name = String(decoding: bytes[offset + 46..<offset + 46 + nameLength], as: UTF8.self)
            guard bytes[local...local + 3] == [0x50, 0x4B, 0x03, 0x04] else { throw Malformed() }
            let dataStart = local + 30 + u16(local + 26) + u16(local + 28)
            result.append(Entry(path: name, data: Data(bytes[dataStart..<dataStart + size]), crc: crc))
            offset += 46 + nameLength + extra + comment
        }
        return result
    }
}
