//
//  OpaliteTests.swift
//  OpaliteTests
//
//  Created by Nick Molargik on 12/6/25.
//

import Testing
import Foundation
@testable import Opalite

// MARK: - OpaliteColor Tests

struct OpaliteColorTests {

    // MARK: - Initialization

    @Test func colorInitialization() {
        let color = OpaliteColor(
            name: "Test Color",
            red: 0.5,
            green: 0.25,
            blue: 0.75,
            alpha: 1.0
        )

        #expect(color.name == "Test Color")
        #expect(color.red == 0.5)
        #expect(color.green == 0.25)
        #expect(color.blue == 0.75)
        #expect(color.alpha == 1.0)
    }

    @Test func colorDefaultValues() {
        let color = OpaliteColor(red: 0.0, green: 0.0, blue: 0.0)

        #expect(color.name == nil)
        #expect(color.notes == nil)
        #expect(color.alpha == 1.0)
        #expect(color.palette == nil)
    }

    // MARK: - Hex String

    @Test func hexStringBlack() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        #expect(black.hexString == "#000000")
    }

    @Test func hexStringWhite() {
        let white = OpaliteColor(red: 1, green: 1, blue: 1)
        #expect(white.hexString == "#FFFFFF")
    }

    @Test func hexStringRed() {
        let red = OpaliteColor(red: 1, green: 0, blue: 0)
        #expect(red.hexString == "#FF0000")
    }

    @Test func hexStringGreen() {
        let green = OpaliteColor(red: 0, green: 1, blue: 0)
        #expect(green.hexString == "#00FF00")
    }

    @Test func hexStringBlue() {
        let blue = OpaliteColor(red: 0, green: 0, blue: 1)
        #expect(blue.hexString == "#0000FF")
    }

    @Test func hexStringCustomColor() {
        // RGB(128, 64, 192) should be #8040C0
        let color = OpaliteColor(red: 128.0/255.0, green: 64.0/255.0, blue: 192.0/255.0)
        #expect(color.hexString == "#8040C0")
    }

    @Test func hexWithAlphaString() {
        let color = OpaliteColor(red: 1, green: 0.5, blue: 0, alpha: 0.5)
        // RGB(255, 128, 0) with alpha 128 -> #FF800080
        #expect(color.hexWithAlphaString == "#FF800080")
    }

    // MARK: - RGB String

    @Test func rgbStringBlack() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        #expect(black.rgbString == "rgb(0, 0, 0)")
    }

    @Test func rgbStringWhite() {
        let white = OpaliteColor(red: 1, green: 1, blue: 1)
        #expect(white.rgbString == "rgb(255, 255, 255)")
    }

    @Test func rgbaString() {
        let color = OpaliteColor(red: 1, green: 0.5, blue: 0, alpha: 0.75)
        #expect(color.rgbaString == "rgba(255, 128, 0, 0.75)")
    }

    // MARK: - HSL String

    @Test func hslStringRed() {
        let red = OpaliteColor(red: 1, green: 0, blue: 0)
        #expect(red.hslString == "hsl(0, 100%, 50%)")
    }

    @Test func hslStringGreen() {
        let green = OpaliteColor(red: 0, green: 1, blue: 0)
        #expect(green.hslString == "hsl(120, 100%, 50%)")
    }

    @Test func hslStringBlue() {
        let blue = OpaliteColor(red: 0, green: 0, blue: 1)
        #expect(blue.hslString == "hsl(240, 100%, 50%)")
    }

    @Test func hslStringGray() {
        let gray = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)
        // Gray has 0 saturation
        #expect(gray.hslString == "hsl(0, 0%, 50%)")
    }

    // MARK: - HSL Conversion

    @Test func rgbToHSLRed() {
        let (h, s, l) = OpaliteColor.rgbToHSL(r: 1, g: 0, b: 0)
        #expect(h == 0)
        #expect(s == 1)
        #expect(l == 0.5)
    }

    @Test func hslToRGBRed() {
        let (r, g, b) = OpaliteColor.hslToRGB(h: 0, s: 1, l: 0.5)
        #expect(abs(r - 1.0) < 0.001)
        #expect(abs(g - 0.0) < 0.001)
        #expect(abs(b - 0.0) < 0.001)
    }

    @Test func hslRoundTrip() {
        // Test that RGB -> HSL -> RGB produces the same values
        let originalR = 0.3
        let originalG = 0.6
        let originalB = 0.9

        let (h, s, l) = OpaliteColor.rgbToHSL(r: originalR, g: originalG, b: originalB)
        let (r, g, b) = OpaliteColor.hslToRGB(h: h, s: s, l: l)

        #expect(abs(r - originalR) < 0.001)
        #expect(abs(g - originalG) < 0.001)
        #expect(abs(b - originalB) < 0.001)
    }

    // MARK: - Color Harmony

    @Test func complementaryColor() {
        let red = OpaliteColor(name: "Red", red: 1, green: 0, blue: 0)
        let complement = red.complementaryColor()

        // Complementary of red should be cyan (hue shifted 180°)
        #expect(complement.name == "Complementary")
        // Cyan is roughly (0, 1, 1) but with same saturation/lightness
        #expect(complement.red < 0.1)
        #expect(complement.green > 0.9)
        #expect(complement.blue > 0.9)
    }

    @Test func analogousColors() {
        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let analogous = color.analogousColors()

        #expect(analogous.count == 2)
        #expect(analogous[0].name == "Analogous")
        #expect(analogous[1].name == "Analogous")
    }

    @Test func triadicColors() {
        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let triadic = color.triadicColors()

        #expect(triadic.count == 2)
        #expect(triadic[0].name == "Triadic")
        #expect(triadic[1].name == "Triadic")
    }

    @Test func tetradicColors() {
        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let tetradic = color.tetradicColors()

        #expect(tetradic.count == 3)
    }

    @Test func splitComplementaryColors() {
        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let splitComp = color.splitComplementaryColors()

        #expect(splitComp.count == 2)
        #expect(splitComp[0].name == "Split-Comp")
    }

    // MARK: - Accessibility

    @Test func relativeLuminanceBlack() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        #expect(black.relativeLuminance == 0)
    }

    @Test func relativeLuminanceWhite() {
        let white = OpaliteColor(red: 1, green: 1, blue: 1)
        #expect(white.relativeLuminance == 1)
    }

    @Test func contrastRatioBlackWhite() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        let white = OpaliteColor(red: 1, green: 1, blue: 1)

        // Black vs white should have maximum contrast ratio of 21
        let ratio = black.contrastRatio(against: white)
        #expect(ratio == 21.0)
    }

    @Test func contrastRatioSameColor() {
        let color = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)

        // Same color should have contrast ratio of 1
        let ratio = color.contrastRatio(against: color)
        #expect(ratio == 1.0)
    }

    @Test func idealTextColorOnBlack() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        // White text should be better on black background
        // We can't directly compare SwiftUI Color, but we can verify the method runs
        _ = black.idealTextColor()
    }

    @Test func idealTextColorOnWhite() {
        let white = OpaliteColor(red: 1, green: 1, blue: 1)
        // Black text should be better on white background
        _ = white.idealTextColor()
    }

    // MARK: - Alpha Modification

    @Test func withAlpha() {
        let color = OpaliteColor(name: "Original", red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let modified = color.withAlpha(0.5)

        #expect(modified.alpha == 0.5)
        #expect(modified.red == color.red)
        #expect(modified.green == color.green)
        #expect(modified.blue == color.blue)
        #expect(modified.name == color.name)
    }

    @Test func withAlphaClampsValues() {
        let color = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)

        let tooHigh = color.withAlpha(1.5)
        #expect(tooHigh.alpha == 1.0)

        let tooLow = color.withAlpha(-0.5)
        #expect(tooLow.alpha == 0.0)
    }

    // MARK: - Export

    @Test func dictionaryRepresentation() {
        let color = OpaliteColor(
            name: "Test",
            red: 1,
            green: 0,
            blue: 0,
            alpha: 1
        )

        let dict = color.dictionaryRepresentation

        #expect(dict["name"] as? String == "Test")
        #expect(dict["hex"] as? String == "#FF0000")
        #expect(dict["red"] as? Double == 1.0)
        #expect(dict["green"] as? Double == 0.0)
        #expect(dict["blue"] as? Double == 0.0)
    }

    @Test func jsonRepresentation() throws {
        let color = OpaliteColor(name: "JSON Test", red: 0.5, green: 0.5, blue: 0.5)

        let jsonData = try color.jsonRepresentation()
        #expect(jsonData.count > 0)

        // Verify it's valid JSON
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        #expect(parsed is [String: Any])
    }
}

// MARK: - OpalitePalette Tests

struct OpalitePaletteTests {

    @Test func paletteInitialization() {
        let palette = OpalitePalette(name: "Test Palette")

        #expect(palette.name == "Test Palette")
        #expect(palette.colors?.isEmpty == true)
        #expect(palette.tags.isEmpty)
    }

    @Test func paletteWithColors() {
        let color1 = OpaliteColor(name: "Red", red: 1, green: 0, blue: 0)
        let color2 = OpaliteColor(name: "Blue", red: 0, green: 0, blue: 1)

        let palette = OpalitePalette(
            name: "Primary Colors",
            colors: [color1, color2]
        )

        #expect(palette.colors?.count == 2)
    }

    @Test func paletteTags() {
        let palette = OpalitePalette(
            name: "Tagged Palette",
            tags: ["warm", "autumn", "nature"]
        )

        #expect(palette.tags.count == 3)
        #expect(palette.tags.contains("warm"))
    }

    @Test func suggestedExportFilename() {
        let palette = OpalitePalette(name: "My Cool Palette")
        let filename = palette.suggestedExportFilename

        #expect(filename.hasSuffix(".opalite-palette.json"))
        #expect(filename.contains("my-cool-palette"))
    }

    @Test func suggestedExportFilenameEmpty() {
        let palette = OpalitePalette(name: "")
        let filename = palette.suggestedExportFilename

        #expect(filename == "opalite-palette.json")
    }

    @Test func dictionaryRepresentation() {
        let palette = OpalitePalette(
            name: "Export Test",
            notes: "Test notes",
            tags: ["test"]
        )

        let dict = palette.dictionaryRepresentation

        #expect(dict["name"] as? String == "Export Test")
        #expect(dict["notes"] as? String == "Test notes")
        #expect((dict["tags"] as? [String])?.contains("test") == true)
    }

    @Test func jsonRepresentation() throws {
        let palette = OpalitePalette(name: "JSON Palette")

        let jsonData = try palette.jsonRepresentation()
        #expect(jsonData.count > 0)

        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        #expect(parsed is [String: Any])
    }
}

// MARK: - HexCopyManager Tests

struct HexCopyManagerTests {

    @Test @MainActor func formattedHexWithPrefix() {
        // Reset UserDefaults for test
        UserDefaults.standard.set(true, forKey: "includeHexPrefix")
        UserDefaults.standard.set(true, forKey: "hasAskedHexPreference")

        let manager = HexCopyManager()
        manager.includeHexPrefix = true

        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let hex = manager.formattedHex(for: color)

        #expect(hex == "#FF0000")
    }

    @Test @MainActor func formattedHexWithoutPrefix() {
        UserDefaults.standard.set(true, forKey: "hasAskedHexPreference")

        let manager = HexCopyManager()
        manager.includeHexPrefix = false

        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let hex = manager.formattedHex(for: color)

        #expect(hex == "FF0000")
    }
}

// MARK: - Color Utility Tests

struct ColorUtilityTests {

    @Test func hexRounding() {
        // Test that colors at boundary values round correctly
        // 127.5 should round to 128 (0x80)
        let color = OpaliteColor(red: 127.5/255.0, green: 127.5/255.0, blue: 127.5/255.0)
        #expect(color.hexString == "#808080")
    }

    @Test func extremeValues() {
        // Test with values at 0 and 1
        let black = OpaliteColor(red: 0.0, green: 0.0, blue: 0.0)
        let white = OpaliteColor(red: 1.0, green: 1.0, blue: 1.0)

        #expect(black.hexString == "#000000")
        #expect(white.hexString == "#FFFFFF")
    }
}
