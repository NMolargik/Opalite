//
//  OpaliteWatch_Watch_AppTests.swift
//  OpaliteWatch Watch AppTests
//
//  Created by Nick Molargik on 12/29/25.
//

import Testing
import SwiftData
@testable import OpaliteWatch_Watch_App

@MainActor
struct OpaliteWatch_Watch_AppTests {

    // MARK: - Test Helpers

    /// Creates an in-memory model container for testing
    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: OpaliteColor.self, OpalitePalette.self,
            configurations: config
        )
    }

    /// Creates a test color with specified RGB values
    private func makeColor(
        name: String? = nil,
        red: Double,
        green: Double,
        blue: Double,
        palette: OpalitePalette? = nil
    ) -> OpaliteColor {
        OpaliteColor(
            name: name,
            red: red,
            green: green,
            blue: blue,
            alpha: 1.0,
            palette: palette
        )
    }

    // MARK: - WatchColorManager Tests

    @Test("WatchColorManager initializes with empty arrays")
    func testManagerInitialization() throws {
        let container = try makeTestContainer()
        let manager = WatchColorManager(context: container.mainContext)

        #expect(manager.colors.isEmpty)
        #expect(manager.palettes.isEmpty)
        #expect(manager.looseColors.isEmpty)
    }

    @Test("formattedHex includes prefix when preference is true")
    func testFormattedHexWithPrefix() throws {
        let container = try makeTestContainer()
        let manager = WatchColorManager(context: container.mainContext)

        // Set preference to include prefix
        UserDefaults.standard.set(true, forKey: "includeHexPrefix")

        let color = makeColor(red: 1.0, green: 0.0, blue: 0.0) // Pure red
        let hex = manager.formattedHex(for: color)

        #expect(hex.hasPrefix("#"))
        #expect(hex == "#FF0000")
    }

    @Test("formattedHex excludes prefix when preference is false")
    func testFormattedHexWithoutPrefix() throws {
        let container = try makeTestContainer()
        let manager = WatchColorManager(context: container.mainContext)

        // Set preference to exclude prefix
        UserDefaults.standard.set(false, forKey: "includeHexPrefix")

        let color = makeColor(red: 0.0, green: 1.0, blue: 0.0) // Pure green
        let hex = manager.formattedHex(for: color)

        #expect(!hex.hasPrefix("#"))
        #expect(hex == "00FF00")
    }

    @Test("looseColors filters out colors with palettes")
    func testLooseColorsFiltering() throws {
        let container = try makeTestContainer()
        let manager = WatchColorManager(context: container.mainContext)

        let palette = OpalitePalette(name: "Test Palette")
        let looseColor = makeColor(name: "Loose", red: 1.0, green: 0.0, blue: 0.0)
        let paletteColor = makeColor(name: "In Palette", red: 0.0, green: 1.0, blue: 0.0, palette: palette)

        manager.colors = [looseColor, paletteColor]

        #expect(manager.looseColors.count == 1)
        #expect(manager.looseColors.first?.name == "Loose")
    }

    @Test("refreshAll updates colors and palettes from context")
    func testRefreshAll() async throws {
        let container = try makeTestContainer()
        let manager = WatchColorManager(context: container.mainContext)

        // Insert test data
        let color = makeColor(name: "Test Color", red: 0.5, green: 0.5, blue: 0.5)
        let palette = OpalitePalette(name: "Test Palette")

        container.mainContext.insert(color)
        container.mainContext.insert(palette)
        try container.mainContext.save()

        // Refresh and verify
        await manager.refreshAll()

        #expect(manager.colors.count == 1)
        #expect(manager.palettes.count == 1)
        #expect(manager.colors.first?.name == "Test Color")
        #expect(manager.palettes.first?.name == "Test Palette")
    }

    // MARK: - OpaliteColor Tests

    @Test("OpaliteColor hexString formats correctly")
    func testHexString() {
        let red = makeColor(red: 1.0, green: 0.0, blue: 0.0)
        let green = makeColor(red: 0.0, green: 1.0, blue: 0.0)
        let blue = makeColor(red: 0.0, green: 0.0, blue: 1.0)
        let white = makeColor(red: 1.0, green: 1.0, blue: 1.0)
        let black = makeColor(red: 0.0, green: 0.0, blue: 0.0)

        #expect(red.hexString == "#FF0000")
        #expect(green.hexString == "#00FF00")
        #expect(blue.hexString == "#0000FF")
        #expect(white.hexString == "#FFFFFF")
        #expect(black.hexString == "#000000")
    }

    @Test("OpaliteColor rgbString formats correctly")
    func testRgbString() {
        let color = makeColor(red: 1.0, green: 0.5, blue: 0.0)
        let rgb = color.rgbString

        #expect(rgb.hasPrefix("rgb("))
        #expect(rgb.contains("255"))
        #expect(rgb.contains("128"))
        #expect(rgb.contains("0"))
    }

    @Test("OpaliteColor hslString formats correctly")
    func testHslString() {
        let color = makeColor(red: 1.0, green: 0.0, blue: 0.0) // Pure red
        let hsl = color.hslString

        #expect(hsl.hasPrefix("hsl("))
        #expect(hsl.contains("0,")) // Hue should be 0 for red
    }

    @Test("OpaliteColor idealTextColor returns contrasting color")
    func testIdealTextColor() {
        let white = makeColor(red: 1.0, green: 1.0, blue: 1.0)
        let black = makeColor(red: 0.0, green: 0.0, blue: 0.0)

        // White background should have black text
        // Black background should have white text
        let whiteTextColor = white.idealTextColor()
        let blackTextColor = black.idealTextColor()

        // These should be different
        #expect(whiteTextColor != blackTextColor)
    }

    // MARK: - OpalitePalette Tests

    @Test("OpalitePalette sortedColors returns colors sorted by createdAt")
    func testSortedColors() {
        let palette = OpalitePalette(name: "Test")

        let older = OpaliteColor(
            createdAt: Date.now.addingTimeInterval(-100),
            red: 1.0, green: 0.0, blue: 0.0
        )
        let newer = OpaliteColor(
            createdAt: Date.now,
            red: 0.0, green: 1.0, blue: 0.0
        )

        palette.colors = [older, newer]

        let sorted = palette.sortedColors

        #expect(sorted.count == 2)
        // Newest first
        #expect(sorted.first?.green == 1.0)
        #expect(sorted.last?.red == 1.0)
    }

    @Test("OpalitePalette handles empty colors array")
    func testEmptyPalette() {
        let palette = OpalitePalette(name: "Empty")
        palette.colors = []

        #expect(palette.sortedColors.isEmpty)
    }

    @Test("OpalitePalette handles nil colors")
    func testNilColors() {
        let palette = OpalitePalette(name: "Nil Colors")
        palette.colors = nil

        #expect(palette.sortedColors.isEmpty)
    }
}
