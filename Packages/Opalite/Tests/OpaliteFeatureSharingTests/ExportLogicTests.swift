//
//  ExportLogicTests.swift
//  OpaliteFeatureSharingTests
//

import Foundation
import Testing
import UniformTypeIdentifiers
import OpaliteCore
import OpaliteServices
import OpaliteFeatureShared
@testable import OpaliteFeatureSharing

@Suite("Export gating")
struct ExportAccessTests {
    @Test func freeFormatsAreNeverLocked() {
        for format in ExportFormatCatalog.colorFormats where format.isFreeFormat {
            #expect(!ExportAccess.isLocked(format, hasOnyx: false))
        }
        for format in ExportFormatCatalog.paletteFormats where format.isFreeFormat {
            #expect(!ExportAccess.isLocked(format, hasOnyx: false))
        }
    }

    @Test func proFormatsLockWithoutOnyx() {
        #expect(ExportAccess.isLocked(ColorExportFormat.ase, hasOnyx: false))
        #expect(!ExportAccess.isLocked(ColorExportFormat.ase, hasOnyx: true))
        #expect(ExportAccess.isLocked(PaletteExportFormat.swiftui, hasOnyx: false))
        #expect(!ExportAccess.isLocked(PaletteExportFormat.pdf, hasOnyx: false))
    }

    @Test func defaultSelectionIsTheFirstUsableFormat() {
        #expect(ExportAccess.defaultFormat(in: ExportFormatCatalog.colorFormats, hasOnyx: false) == .image)
        #expect(ExportAccess.defaultFormat(in: [ColorExportFormat.ase, .css, .opalite], hasOnyx: false) == .opalite)
        #expect(ExportAccess.defaultFormat(in: [ColorExportFormat.ase, .css], hasOnyx: false) == nil)
        #expect(ExportAccess.defaultFormat(in: [ColorExportFormat.ase, .css], hasOnyx: true) == .ase)
    }

    @Test func lockedFootnoteOnlyWithoutOnyx() {
        #expect(ExportAccess.hasLockedFormats(in: ExportFormatCatalog.paletteFormats, hasOnyx: false))
        #expect(!ExportAccess.hasLockedFormats(in: ExportFormatCatalog.paletteFormats, hasOnyx: true))
    }

    @Test func catalogsOfferEveryFormatFreeOnesFirst() {
        #expect(Set(ExportFormatCatalog.colorFormats) == Set(ColorExportFormat.allCases))
        #expect(Set(ExportFormatCatalog.paletteFormats) == Set(PaletteExportFormat.allCases))
        let firstLockedColor = ExportFormatCatalog.colorFormats.firstIndex { !$0.isFreeFormat } ?? .max
        #expect(ExportFormatCatalog.colorFormats.enumerated().allSatisfy { $0.element.isFreeFormat == ($0.offset < firstLockedColor) })
        let firstLockedPalette = ExportFormatCatalog.paletteFormats.firstIndex { !$0.isFreeFormat } ?? .max
        #expect(ExportFormatCatalog.paletteFormats.enumerated().allSatisfy { $0.element.isFreeFormat == ($0.offset < firstLockedPalette) })
    }
}

@Suite("Export content types")
struct ExportContentTypeTests {
    @Test func everyFormatMapsToAWritableType() {
        for format in ColorExportFormat.allCases {
            #expect(ExportContentType.all.contains(ExportContentType.utType(for: format)))
        }
        for format in PaletteExportFormat.allCases {
            #expect(ExportContentType.all.contains(ExportContentType.utType(for: format)))
        }
    }

    @Test func nativeTypesCarryOpaliteIdentifiersAndExtensions() {
        #expect(ExportContentType.utType(for: ColorExportFormat.opalite).identifier == OpaliteFileType.colorIdentifier)
        #expect(ExportContentType.utType(for: PaletteExportFormat.opalite).identifier == OpaliteFileType.paletteIdentifier)
        #expect(ExportContentType.utType(for: ColorExportFormat.image) == .png)
        #expect(ExportContentType.utType(for: PaletteExportFormat.pdf) == .pdf)
        #expect(ExportContentType.utType(for: PaletteExportFormat.swiftui) == .swiftSource)
    }
}

@Suite("Exported files")
struct ExportedFileTests {
    @Test func loadsWhatTheExportServiceWrote() throws {
        let environment = PreviewEnvironment()
        let color = try #require(environment.portfolio.colors.first { $0.name == "Moss" })
        let url = try ExportService.exportColor(color, format: .css)
        let file = try ExportedFile.load(url, contentType: ExportContentType.utType(for: ColorExportFormat.css))
        defer { file.removeFromDisk() }

        #expect(file.filename == "Moss.css")
        #expect(file.baseName == "Moss")
        #expect(file.byteCount > 0)
        #expect(!file.isImage)
        #expect(file.summary.hasPrefix("Moss.css · "))
        #expect(String(decoding: file.data, as: UTF8.self).contains(color.hexString.lowercased()) || String(decoding: file.data, as: UTF8.self).contains(color.hexString))
    }

    @Test func imageFilesReportAsImages() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sharing-test-\(UUID().uuidString).png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        let file = try ExportedFile.load(url, contentType: .png)
        #expect(file.isImage)
        file.removeFromDisk()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        file.removeFromDisk() // idempotent
    }

    @Test func missingFileThrows() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString).ase")
        #expect(throws: (any Error).self) {
            try ExportedFile.load(url, contentType: .data)
        }
    }
}
