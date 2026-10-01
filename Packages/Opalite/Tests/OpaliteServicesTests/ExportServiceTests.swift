//
//  ExportServiceTests.swift
//  OpaliteServicesTests
//

import Foundation
import Testing
import OpaliteCore
@testable import OpaliteServices

@Suite("ExportService")
struct ExportServiceTests {
    static var pdfIsSupported: Bool {
        #if canImport(UIKit) && !os(watchOS)
        true
        #else
        false
        #endif
    }

    private func makePalette() -> OpalitePalette {
        OpalitePalette(name: "Summer Sunset!", notes: "n", tags: ["t"], colors: [
            OpaliteColor(name: "Dusk", red: 0.9, green: 0.4, blue: 0.3),
            OpaliteColor(name: nil, red: 0.1, green: 0.2, blue: 0.3, alpha: 0.5),
        ])
    }

    private func read(_ url: URL) throws -> Data {
        defer { try? FileManager.default.removeItem(at: url) }
        return try Data(contentsOf: url)
    }

    @Test("Every color format writes a file", arguments: ColorExportFormat.allCases)
    func exportsColor(format: ColorExportFormat) throws {
        let color = OpaliteColor(name: "Dusty Rose", red: 0.8, green: 0.5, blue: 0.55)
        let url = try ExportService.exportColor(color, format: format, imagePNG: Data([0x89]))
        #expect(url.pathExtension == format.fileExtension)
        #expect(url.deletingPathExtension().lastPathComponent == "DustyRose")
        let data = try read(url)
        #expect(!data.isEmpty)
        switch format {
        case .image: #expect(data == Data([0x89]))
        case .opalite: #expect(try OpaliteFileCodec.decodeColor(from: data).id == color.id)
        case .ase: #expect([UInt8](data.prefix(4)) == [0x41, 0x53, 0x45, 0x46])
        case .procreate: #expect([UInt8](data.prefix(2)) == [0x50, 0x4B])
        case .gpl: #expect(String(decoding: data, as: UTF8.self).hasPrefix("GIMP Palette"))
        case .css: #expect(String(decoding: data, as: UTF8.self).contains("--dusty-rose: rgb(204, 128, 140);"))
        case .swiftui: #expect(String(decoding: data, as: UTF8.self).contains("static let dustyRose"))
        }
    }

    @Test func unnamedColorsAreNamedByHex() throws {
        let url = try ExportService.exportColor(OpaliteColor(red: 1, green: 0, blue: 0), format: .css)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent == "FF0000.css")
    }

    @Test func imageExportRequiresRenderedBytes() {
        #expect(throws: ExportError.self) { try ExportService.exportColor(OpaliteColor(red: 0, green: 0, blue: 0), format: .image) }
        #expect(throws: ExportError.self) { try ExportService.exportPalette(makePalette(), format: .image) }
    }

    @Test("Every palette format writes a file", arguments: PaletteExportFormat.allCases)
    func exportsPalette(format: PaletteExportFormat) throws {
        let palette = makePalette()
        guard format != .pdf || Self.pdfIsSupported else {
            #expect(throws: ExportError.self) { try ExportService.exportPalette(palette, format: .pdf) }
            return
        }
        let url = try ExportService.exportPalette(palette, format: format, imagePNG: Data([0x89, 0x50]), userName: "Nick")
        #expect(url.pathExtension == format.fileExtension)
        #expect(url.deletingPathExtension().lastPathComponent == "SummerSunset")
        let data = try read(url)
        #expect(!data.isEmpty)
        switch format {
        case .image: #expect(data == Data([0x89, 0x50]))
        case .pdf: #expect(String(decoding: data.prefix(4), as: UTF8.self) == "%PDF")
        case .opalite:
            let decoded = try OpaliteFileCodec.decodePalette(from: data)
            #expect(decoded.id == palette.id && decoded.colors.count == 2)
        case .ase:
            #expect([UInt8](data.prefix(4)) == [0x41, 0x53, 0x45, 0x46])
            #expect([UInt8](data[8..<12]) == [0, 0, 0, 4], "group start + 2 colors + group end")
        case .procreate: #expect([UInt8](data.prefix(2)) == [0x50, 0x4B])
        case .gpl:
            let text = String(decoding: data, as: UTF8.self)
            #expect(text.contains("Name: Summer Sunset!") && text.contains("Columns: 2"))
        case .css:
            let text = String(decoding: data, as: UTF8.self)
            #expect(text.contains("--summer-sunset-dusk: rgb(230, 102, 77);"))
            #expect(text.contains("rgba(26, 51, 77, 0.50)"))
        case .swiftui:
            let text = String(decoding: data, as: UTF8.self)
            #expect(text.contains("static let summersunsetDusk = Color("))
            #expect(!text.contains("// Usage"))
        }
    }

    @Test func portfolioPDF() throws {
        let palette = makePalette()
        let loose = [OpaliteColor(name: "Loose", red: 0, green: 0, blue: 0)]
        if Self.pdfIsSupported {
            let url = try ExportService.exportPortfolioPDF(palettes: [palette], looseColors: loose, userName: "Nick")
            #expect(url.pathExtension == "pdf")
            #expect(url.lastPathComponent.hasPrefix("Opalite Portfolio "))
            #expect(String(decoding: try read(url).prefix(4), as: UTF8.self) == "%PDF")
        } else {
            #expect(throws: ExportError.self) { try ExportService.exportPortfolioPDF(palettes: [palette], looseColors: loose, userName: "Nick") }
        }
    }

    @Test func exportErrorDescriptions() {
        for error in [ExportError.renderFailed, .writeFailed("disk"), .unsupportedOnThisPlatform] {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
        #expect(ExportError.writeFailed("disk full").errorDescription?.contains("disk full") == true)
    }
}
