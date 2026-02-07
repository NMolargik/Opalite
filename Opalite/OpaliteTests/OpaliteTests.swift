//
//  OpaliteTests.swift
//  OpaliteTests
//
//  Created by Nick Molargik on 12/6/25.
//

import Testing
import Foundation
import PencilKit
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

    @Test func colorWithAllProperties() {
        let date = Date()
        let color = OpaliteColor(
            id: UUID(),
            name: "Full Color",
            notes: "Test notes",
            createdByDisplayName: "Test User",
            createdOnDeviceName: "iPhone",
            updatedOnDeviceName: "iPad",
            createdAt: date,
            updatedAt: date,
            red: 0.1,
            green: 0.2,
            blue: 0.3,
            alpha: 0.5
        )

        #expect(color.name == "Full Color")
        #expect(color.notes == "Test notes")
        #expect(color.createdByDisplayName == "Test User")
        #expect(color.createdOnDeviceName == "iPhone")
        #expect(color.updatedOnDeviceName == "iPad")
        #expect(color.alpha == 0.5)
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
        let color = OpaliteColor(red: 128.0/255.0, green: 64.0/255.0, blue: 192.0/255.0)
        #expect(color.hexString == "#8040C0")
    }

    @Test func hexWithAlphaString() {
        let color = OpaliteColor(red: 1, green: 0.5, blue: 0, alpha: 0.5)
        #expect(color.hexWithAlphaString == "#FF800080")
    }

    @Test func hexWithAlphaFullOpaque() {
        let color = OpaliteColor(red: 1, green: 1, blue: 1, alpha: 1)
        #expect(color.hexWithAlphaString == "#FFFFFFFF")
    }

    @Test func hexWithAlphaTransparent() {
        let color = OpaliteColor(red: 0, green: 0, blue: 0, alpha: 0)
        #expect(color.hexWithAlphaString == "#00000000")
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

    @Test func rgbStringMidGray() {
        let gray = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)
        #expect(gray.rgbString == "rgb(128, 128, 128)")
    }

    @Test func rgbaString() {
        let color = OpaliteColor(red: 1, green: 0.5, blue: 0, alpha: 0.75)
        #expect(color.rgbaString == "rgba(255, 128, 0, 0.75)")
    }

    @Test func rgbaStringFullAlpha() {
        let color = OpaliteColor(red: 1, green: 0, blue: 0, alpha: 1.0)
        #expect(color.rgbaString == "rgba(255, 0, 0, 1.0)")
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
        #expect(gray.hslString == "hsl(0, 0%, 50%)")
    }

    @Test func hslStringYellow() {
        let yellow = OpaliteColor(red: 1, green: 1, blue: 0)
        #expect(yellow.hslString == "hsl(60, 100%, 50%)")
    }

    @Test func hslStringCyan() {
        let cyan = OpaliteColor(red: 0, green: 1, blue: 1)
        #expect(cyan.hslString == "hsl(180, 100%, 50%)")
    }

    @Test func hslStringMagenta() {
        let magenta = OpaliteColor(red: 1, green: 0, blue: 1)
        #expect(magenta.hslString == "hsl(300, 100%, 50%)")
    }

    // MARK: - HSL Conversion

    @Test func rgbToHSLRed() {
        let (h, s, l) = OpaliteColor.rgbToHSL(r: 1, g: 0, b: 0)
        #expect(h == 0)
        #expect(s == 1)
        #expect(l == 0.5)
    }

    @Test func rgbToHSLGreen() {
        let (h, s, l) = OpaliteColor.rgbToHSL(r: 0, g: 1, b: 0)
        #expect(abs(h - 1.0/3.0) < 0.001)
        #expect(s == 1)
        #expect(l == 0.5)
    }

    @Test func rgbToHSLBlue() {
        let (h, s, l) = OpaliteColor.rgbToHSL(r: 0, g: 0, b: 1)
        #expect(abs(h - 2.0/3.0) < 0.001)
        #expect(s == 1)
        #expect(l == 0.5)
    }

    @Test func rgbToHSLWhite() {
        let (h, s, l) = OpaliteColor.rgbToHSL(r: 1, g: 1, b: 1)
        #expect(s == 0)
        #expect(l == 1)
    }

    @Test func rgbToHSLBlack() {
        let (h, s, l) = OpaliteColor.rgbToHSL(r: 0, g: 0, b: 0)
        #expect(s == 0)
        #expect(l == 0)
    }

    @Test func hslToRGBRed() {
        let (r, g, b) = OpaliteColor.hslToRGB(h: 0, s: 1, l: 0.5)
        #expect(abs(r - 1.0) < 0.001)
        #expect(abs(g - 0.0) < 0.001)
        #expect(abs(b - 0.0) < 0.001)
    }

    @Test func hslToRGBGray() {
        let (r, g, b) = OpaliteColor.hslToRGB(h: 0, s: 0, l: 0.5)
        #expect(abs(r - 0.5) < 0.001)
        #expect(abs(g - 0.5) < 0.001)
        #expect(abs(b - 0.5) < 0.001)
    }

    @Test func hslRoundTrip() {
        let originalR = 0.3
        let originalG = 0.6
        let originalB = 0.9

        let (h, s, l) = OpaliteColor.rgbToHSL(r: originalR, g: originalG, b: originalB)
        let (r, g, b) = OpaliteColor.hslToRGB(h: h, s: s, l: l)

        #expect(abs(r - originalR) < 0.001)
        #expect(abs(g - originalG) < 0.001)
        #expect(abs(b - originalB) < 0.001)
    }

    @Test func hslRoundTripMultipleColors() {
        let testCases: [(Double, Double, Double)] = [
            (0.0, 0.0, 0.0),
            (1.0, 1.0, 1.0),
            (0.5, 0.5, 0.5),
            (0.2, 0.4, 0.8),
            (0.9, 0.1, 0.5)
        ]

        for (originalR, originalG, originalB) in testCases {
            let (h, s, l) = OpaliteColor.rgbToHSL(r: originalR, g: originalG, b: originalB)
            let (r, g, b) = OpaliteColor.hslToRGB(h: h, s: s, l: l)

            #expect(abs(r - originalR) < 0.01)
            #expect(abs(g - originalG) < 0.01)
            #expect(abs(b - originalB) < 0.01)
        }
    }

    // MARK: - Color Harmony

    @Test func complementaryColor() {
        let red = OpaliteColor(name: "Red", red: 1, green: 0, blue: 0)
        let complement = red.complementaryColor()

        #expect(complement.name == "Complementary")
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

    @Test func harmoniousColorsIsAliasForAnalogous() {
        let color = OpaliteColor(red: 0.5, green: 0.3, blue: 0.7)
        let harmonious = color.harmoniousColors()
        let analogous = color.analogousColors()

        #expect(harmonious.count == analogous.count)
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

    @Test func relativeLuminanceGray() {
        let gray = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)
        #expect(gray.relativeLuminance > 0)
        #expect(gray.relativeLuminance < 1)
    }

    @Test func contrastRatioBlackWhite() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        let white = OpaliteColor(red: 1, green: 1, blue: 1)

        let ratio = black.contrastRatio(against: white)
        #expect(ratio == 21.0)
    }

    @Test func contrastRatioSymmetric() {
        let color1 = OpaliteColor(red: 0.2, green: 0.4, blue: 0.6)
        let color2 = OpaliteColor(red: 0.8, green: 0.6, blue: 0.4)

        let ratio1 = color1.contrastRatio(against: color2)
        let ratio2 = color2.contrastRatio(against: color1)

        #expect(abs(ratio1 - ratio2) < 0.001)
    }

    @Test func contrastRatioSameColor() {
        let color = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)
        let ratio = color.contrastRatio(against: color)
        #expect(ratio == 1.0)
    }

    @Test func idealTextColorOnBlack() {
        let black = OpaliteColor(red: 0, green: 0, blue: 0)
        _ = black.idealTextColor()
    }

    @Test func idealTextColorOnWhite() {
        let white = OpaliteColor(red: 1, green: 1, blue: 1)
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

    @Test func withAlphaClampsHigh() {
        let color = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)
        let tooHigh = color.withAlpha(1.5)
        #expect(tooHigh.alpha == 1.0)
    }

    @Test func withAlphaClampsLow() {
        let color = OpaliteColor(red: 0.5, green: 0.5, blue: 0.5)
        let tooLow = color.withAlpha(-0.5)
        #expect(tooLow.alpha == 0.0)
    }

    @Test func withAlphaPreservesMetadata() {
        let color = OpaliteColor(
            name: "Test",
            notes: "Notes",
            createdByDisplayName: "User",
            red: 0.5,
            green: 0.5,
            blue: 0.5,
            alpha: 1.0
        )
        let modified = color.withAlpha(0.5)

        #expect(modified.name == color.name)
        #expect(modified.notes == color.notes)
        #expect(modified.createdByDisplayName == color.createdByDisplayName)
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
        #expect(dict["alpha"] as? Double == 1.0)
    }

    @Test func dictionaryRepresentationIncludesAllFormats() {
        let color = OpaliteColor(name: "Test", red: 0.5, green: 0.5, blue: 0.5)
        let dict = color.dictionaryRepresentation

        #expect(dict["hex"] != nil)
        #expect(dict["hexWithAlpha"] != nil)
        #expect(dict["rgb"] != nil)
        #expect(dict["rgba"] != nil)
        #expect(dict["hsl"] != nil)
    }

    @Test func jsonRepresentation() throws {
        let color = OpaliteColor(name: "JSON Test", red: 0.5, green: 0.5, blue: 0.5)

        let jsonData = try color.jsonRepresentation()
        #expect(jsonData.count > 0)

        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        #expect(parsed is [String: Any])
    }

    @Test func jsonRepresentationIsValid() throws {
        let color = OpaliteColor(name: "Test", red: 1, green: 0, blue: 0)
        let jsonData = try color.jsonRepresentation()

        let dict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        #expect(dict["name"] as? String == "Test")
    }

    // MARK: - Sample Data

    @Test func sampleColorExists() {
        let sample = OpaliteColor.sample
        #expect(sample.name != nil)
        #expect(sample.red >= 0 && sample.red <= 1)
        #expect(sample.green >= 0 && sample.green <= 1)
        #expect(sample.blue >= 0 && sample.blue <= 1)
    }

    @Test func sample2ColorExists() {
        let sample = OpaliteColor.sample2
        #expect(sample.name != nil)
    }
}

// MARK: - Color Blindness Simulation Tests

struct ColorBlindnessSimulationTests {

    @Test func offModeReturnsOriginalColor() {
        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let simulated = color.simulatingColorBlindness(.off)

        #expect(simulated.red == color.red)
        #expect(simulated.green == color.green)
        #expect(simulated.blue == color.blue)
    }

    @Test func protanopiaChangesRed() {
        let red = OpaliteColor(red: 1, green: 0, blue: 0)
        let simulated = red.simulatingColorBlindness(.protanopia)

        // Protanopia affects red perception
        #expect(simulated.red != red.red || simulated.green != red.green)
    }

    @Test func deuteranopiaChangesGreen() {
        let green = OpaliteColor(red: 0, green: 1, blue: 0)
        let simulated = green.simulatingColorBlindness(.deuteranopia)

        // Deuteranopia affects green perception
        #expect(simulated.green != green.green || simulated.red != green.red)
    }

    @Test func tritanopiaChangesBlue() {
        let blue = OpaliteColor(red: 0, green: 0, blue: 1)
        let simulated = blue.simulatingColorBlindness(.tritanopia)

        // Tritanopia affects blue perception
        #expect(simulated.blue != blue.blue || simulated.green != blue.green)
    }

    @Test func simulationPreservesMetadata() {
        let color = OpaliteColor(
            id: UUID(),
            name: "Test",
            notes: "Notes",
            red: 0.5,
            green: 0.5,
            blue: 0.5
        )
        let simulated = color.simulatingColorBlindness(.protanopia)

        #expect(simulated.id == color.id)
        #expect(simulated.name == color.name)
        #expect(simulated.notes == color.notes)
    }

    @Test func simulationClampsValues() {
        // Edge case: ensure values stay in valid range
        let color = OpaliteColor(red: 1, green: 1, blue: 1)
        let simulated = color.simulatingColorBlindness(.protanopia)

        #expect(simulated.red >= 0 && simulated.red <= 1)
        #expect(simulated.green >= 0 && simulated.green <= 1)
        #expect(simulated.blue >= 0 && simulated.blue <= 1)
    }

    @Test func arraySimulationOffReturnsOriginal() {
        let colors = [
            OpaliteColor(red: 1, green: 0, blue: 0),
            OpaliteColor(red: 0, green: 1, blue: 0)
        ]
        let simulated = colors.simulatingColorBlindness(.off)

        #expect(simulated.count == colors.count)
        #expect(simulated[0].red == colors[0].red)
    }

    @Test func arraySimulationAppliesMode() {
        let colors = [
            OpaliteColor(red: 1, green: 0, blue: 0),
            OpaliteColor(red: 0, green: 1, blue: 0)
        ]
        let simulated = colors.simulatingColorBlindness(.protanopia)

        #expect(simulated.count == colors.count)
        // At least one color should change
        let changed = simulated[0].red != colors[0].red ||
                      simulated[0].green != colors[0].green
        #expect(changed)
    }
}

// MARK: - ColorBlindnessMode Tests

struct ColorBlindnessModeTests {

    @Test func allCasesExist() {
        #expect(ColorBlindnessMode.allCases.count == 5)
    }

    @Test func offModeProperties() {
        let mode = ColorBlindnessMode.off
        #expect(mode.title == "Off")
        #expect(mode.shortTitle == "Normal Vision")
        #expect(mode.modeDescription == "No simulation active")
    }

    @Test func protanopiaProperties() {
        let mode = ColorBlindnessMode.protanopia
        #expect(mode.title == "Protanopia (Red-blind)")
        #expect(mode.shortTitle == "Protanopia")
        #expect(mode.modeDescription.contains("red"))
    }

    @Test func deuteranopiaProperties() {
        let mode = ColorBlindnessMode.deuteranopia
        #expect(mode.title == "Deuteranopia (Green-blind)")
        #expect(mode.shortTitle == "Deuteranopia")
        #expect(mode.modeDescription.contains("green"))
    }

    @Test func tritanopiaProperties() {
        let mode = ColorBlindnessMode.tritanopia
        #expect(mode.title == "Tritanopia (Blue-blind)")
        #expect(mode.shortTitle == "Tritanopia")
        #expect(mode.modeDescription.contains("blue"))
    }

    @Test func achromatopsiaProperties() {
        let mode = ColorBlindnessMode.achromatopsia
        #expect(mode.title == "Achromatopsia (No Color)")
        #expect(mode.shortTitle == "Achromatopsia")
        #expect(mode.modeDescription.contains("grayscale"))
    }

    @Test func identifiableConformance() {
        for mode in ColorBlindnessMode.allCases {
            #expect(mode.id == mode.rawValue)
        }
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
        #expect(palette.tags.contains("autumn"))
        #expect(palette.tags.contains("nature"))
    }

    @Test func paletteNotes() {
        let palette = OpalitePalette(
            name: "With Notes",
            notes: "Test notes"
        )

        #expect(palette.notes == "Test notes")
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

    @Test func suggestedExportFilenameWithSpaces() {
        let palette = OpalitePalette(name: "My Palette Name")
        let filename = palette.suggestedExportFilename

        #expect(!filename.contains(" "))
        #expect(filename.hasSuffix(".opalite-palette.json"))
    }

    @Test func suggestedExportFilenameWithSpecialChars() {
        let palette = OpalitePalette(name: "Test!@#$%Palette")
        let filename = palette.suggestedExportFilename

        #expect(filename.hasSuffix(".opalite-palette.json"))
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

    @Test func dictionaryRepresentationIncludesColors() {
        let color = OpaliteColor(name: "Red", red: 1, green: 0, blue: 0)
        let palette = OpalitePalette(name: "With Color", colors: [color])

        let dict = palette.dictionaryRepresentation
        let colors = dict["colors"] as? [[String: Any]]

        #expect(colors?.count == 1)
    }

    @Test func jsonRepresentation() throws {
        let palette = OpalitePalette(name: "JSON Palette")

        let jsonData = try palette.jsonRepresentation()
        #expect(jsonData.count > 0)

        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        #expect(parsed is [String: Any])
    }

    @Test func samplePaletteExists() {
        let sample = OpalitePalette.sample
        #expect(!sample.name.isEmpty)
        #expect(sample.colors != nil)
    }
}

// MARK: - CanvasFile Tests

struct CanvasFileTests {

    @Test func canvasFileInitialization() {
        let canvas = CanvasFile(title: "Test Canvas")

        #expect(canvas.title == "Test Canvas")
        #expect(canvas.drawingData != nil)
    }

    @Test func canvasFileDefaultTitle() {
        let canvas = CanvasFile()

        #expect(canvas.title == "Untitled Canvas")
    }

    @Test func canvasFileDefaultCanvasSize() {
        let size = CanvasFile.defaultCanvasSize

        #expect(size.width == 4096)
        #expect(size.height == 4096)
    }

    @Test func loadDrawingReturnsEmptyForNilData() {
        let canvas = CanvasFile()
        canvas.drawingData = nil

        let drawing = canvas.loadDrawing()
        #expect(drawing.strokes.isEmpty)
    }

    @Test func loadDrawingReturnsEmptyForInvalidData() {
        let canvas = CanvasFile()
        canvas.drawingData = Data([0x00, 0x01, 0x02]) // Invalid data

        let drawing = canvas.loadDrawing()
        #expect(drawing.strokes.isEmpty)
    }

    @Test func saveDrawingUpdatesTimestamp() {
        let canvas = CanvasFile()
        let originalUpdatedAt = canvas.updatedAt

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)

        canvas.saveDrawing(PKDrawing())

        #expect(canvas.updatedAt > originalUpdatedAt)
    }

    @Test func saveAndLoadDrawingRoundTrip() {
        let canvas = CanvasFile()
        let drawing = PKDrawing()

        canvas.saveDrawing(drawing)
        let loaded = canvas.loadDrawing()

        #expect(loaded.strokes.count == drawing.strokes.count)
    }

    @Test func canvasSizeReturnsNilWhenNotSet() {
        let canvas = CanvasFile()
        canvas.canvasWidth = 0
        canvas.canvasHeight = 0

        #expect(canvas.canvasSize == nil)
    }

    @Test func canvasSizeReturnsValueWhenSet() {
        let canvas = CanvasFile()
        canvas.canvasWidth = 100
        canvas.canvasHeight = 200

        let size = canvas.canvasSize
        #expect(size?.width == 100)
        #expect(size?.height == 200)
    }

    @Test func setCanvasSizeOnlyOnce() {
        let canvas = CanvasFile()
        canvas.canvasWidth = 0
        canvas.canvasHeight = 0

        canvas.setCanvasSize(CGSize(width: 100, height: 100))
        #expect(canvas.canvasWidth == 100)

        // Second call should not change size
        canvas.setCanvasSize(CGSize(width: 200, height: 200))
        #expect(canvas.canvasWidth == 100)
    }

    @Test func expandCanvasIfNeededExpands() {
        let canvas = CanvasFile()
        canvas.canvasWidth = 100
        canvas.canvasHeight = 100

        canvas.expandCanvasIfNeeded(to: CGSize(width: 200, height: 150))

        #expect(canvas.canvasWidth == 200)
        #expect(canvas.canvasHeight == 150)
    }

    @Test func expandCanvasIfNeededDoesNotShrink() {
        let canvas = CanvasFile()
        canvas.canvasWidth = 200
        canvas.canvasHeight = 200

        canvas.expandCanvasIfNeeded(to: CGSize(width: 100, height: 100))

        #expect(canvas.canvasWidth == 200)
        #expect(canvas.canvasHeight == 200)
    }
}

// MARK: - OnyxSubscription Tests

struct OnyxSubscriptionTests {

    @Test func annualProperties() {
        let annual = OnyxSubscription.annual

        #expect(annual.rawValue == "onyx_1yr_4.99")
        #expect(annual.displayName == "Onyx Annual")
        #expect(annual.priceDescription == "per year")
        #expect(annual.isSubscription == true)
    }

    @Test func lifetimeProperties() {
        let lifetime = OnyxSubscription.lifetime

        #expect(lifetime.rawValue == "onyx_lifetime_20")
        #expect(lifetime.displayName == "Onyx Lifetime")
        #expect(lifetime.priceDescription == "one-time purchase")
        #expect(lifetime.isSubscription == false)
    }

    @Test func productIDsContainsAllCases() {
        let productIDs = OnyxSubscription.productIDs

        #expect(productIDs.count == OnyxSubscription.allCases.count)
        for subscription in OnyxSubscription.allCases {
            #expect(productIDs.contains(subscription.rawValue))
        }
    }

    @Test func identifiableConformance() {
        for subscription in OnyxSubscription.allCases {
            #expect(subscription.id == subscription.rawValue)
        }
    }
}

// MARK: - ToastStyle Tests

struct ToastStyleTests {

    @Test func errorStyleProperties() {
        let style = ToastStyle.error
        #expect(style.iconName == "xmark.circle.fill")
    }

    @Test func successStyleProperties() {
        let style = ToastStyle.success
        #expect(style.iconName == "checkmark.circle.fill")
    }

    @Test func infoStyleProperties() {
        let style = ToastStyle.info
        #expect(style.iconName == "info.circle.fill")
    }
}

// MARK: - ToastItem Tests

struct ToastItemTests {

    @Test func toastItemDefaultValues() {
        let toast = ToastItem(message: "Test")

        #expect(toast.message == "Test")
        #expect(toast.style == .info)
        #expect(toast.icon == nil)
        #expect(toast.duration == 3.0)
    }

    @Test func toastItemCustomValues() {
        let toast = ToastItem(
            message: "Error!",
            style: .error,
            icon: "xmark",
            duration: 5.0
        )

        #expect(toast.message == "Error!")
        #expect(toast.style == .error)
        #expect(toast.icon == "xmark")
        #expect(toast.duration == 5.0)
    }

    @Test func toastItemFromError() {
        let toast = ToastItem(error: .colorCreationFailed)

        #expect(toast.message == "Unable to create color")
        #expect(toast.style == .error)
        #expect(toast.icon != nil)
    }

    @Test func toastItemEquality() {
        let toast1 = ToastItem(message: "Test")
        let toast2 = ToastItem(message: "Test")

        // Different IDs means not equal
        #expect(toast1 != toast2)
        #expect(toast1 == toast1)
    }
}

// MARK: - OpaliteError Tests

struct OpaliteErrorTests {

    @Test func colorErrorDescriptions() {
        #expect(OpaliteError.colorCreationFailed.errorDescription == "Unable to create color")
        #expect(OpaliteError.colorUpdateFailed.errorDescription == "Unable to update color")
        #expect(OpaliteError.colorDeletionFailed.errorDescription == "Unable to delete color")
        #expect(OpaliteError.colorFetchFailed.errorDescription == "Unable to load colors")
    }

    @Test func paletteErrorDescriptions() {
        #expect(OpaliteError.paletteCreationFailed.errorDescription == "Unable to create palette")
        #expect(OpaliteError.paletteUpdateFailed.errorDescription == "Unable to update palette")
        #expect(OpaliteError.paletteDeletionFailed.errorDescription == "Unable to delete palette")
        #expect(OpaliteError.paletteFetchFailed.errorDescription == "Unable to load palettes")
    }

    @Test func canvasErrorDescriptions() {
        #expect(OpaliteError.canvasCreationFailed.errorDescription == "Unable to create canvas")
        #expect(OpaliteError.canvasUpdateFailed.errorDescription == "Unable to update canvas")
        #expect(OpaliteError.canvasDeletionFailed.errorDescription == "Unable to delete canvas")
        #expect(OpaliteError.canvasFetchFailed.errorDescription == "Unable to load canvases")
        #expect(OpaliteError.canvasSaveFailed.errorDescription == "Unable to save canvas")
    }

    @Test func importExportErrorDescriptions() {
        #expect(OpaliteError.importFailed(reason: "test").errorDescription == "Import failed: test")
        #expect(OpaliteError.exportFailed(reason: "test").errorDescription == "Export failed: test")
        #expect(OpaliteError.pdfExportFailed.errorDescription == "Unable to export PDF")
    }

    @Test func subscriptionErrorDescriptions() {
        #expect(OpaliteError.subscriptionLoadFailed.errorDescription == "Unable to load subscription options")
        #expect(OpaliteError.subscriptionPurchaseFailed.errorDescription == "Purchase could not be completed")
        #expect(OpaliteError.subscriptionRestoreFailed.errorDescription == "Unable to restore purchases")
    }

    @Test func errorSystemImages() {
        #expect(OpaliteError.colorCreationFailed.systemImage == "plus.circle.fill")
        #expect(OpaliteError.colorUpdateFailed.systemImage == "pencil.circle.fill")
        #expect(OpaliteError.colorDeletionFailed.systemImage == "trash.circle.fill")
        #expect(OpaliteError.saveFailed.systemImage == "externaldrive.fill.badge.xmark")
    }

    @Test func errorEquality() {
        #expect(OpaliteError.colorCreationFailed == OpaliteError.colorCreationFailed)
        #expect(OpaliteError.colorCreationFailed != OpaliteError.colorUpdateFailed)
    }

    @Test func unknownErrorWithMessage() {
        let error = OpaliteError.unknownError("Custom message")
        #expect(error.errorDescription == "Custom message")
        #expect(error.systemImage == "exclamationmark.triangle.fill")
    }
}

// MARK: - HexCopyManager Tests

struct HexCopyManagerTests {

    @Test @MainActor func formattedHexWithPrefix() {
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

    @Test @MainActor func formattedHexVariousColors() {
        let manager = HexCopyManager()
        manager.includeHexPrefix = true

        let white = OpaliteColor(red: 1, green: 1, blue: 1)
        let black = OpaliteColor(red: 0, green: 0, blue: 0)

        #expect(manager.formattedHex(for: white) == "#FFFFFF")
        #expect(manager.formattedHex(for: black) == "#000000")
    }

    @Test @MainActor func initialState() {
        let manager = HexCopyManager()

        #expect(manager.showPreferenceAlert == false)
        #expect(manager.pendingCopyColor == nil)
    }
}

// MARK: - ColorEditorViewModel Tests

struct ColorEditorViewModelTests {

    @Test func viewModelWithExistingColor() {
        let color = OpaliteColor(
            name: "Test",
            red: 0.5,
            green: 0.5,
            blue: 0.5
        )

        let viewModel = ColorEditorView.ViewModel(color: color)

        #expect(viewModel.originalColor?.name == "Test")
        #expect(viewModel.tempColor.red == 0.5)
        #expect(viewModel.tempColor.name == "Test")
    }

    @Test func viewModelWithNilColor() {
        let viewModel = ColorEditorView.ViewModel(color: nil)

        #expect(viewModel.originalColor == nil)
        #expect(viewModel.tempColor.red == 0.5)
        #expect(viewModel.tempColor.green == 0.6)
        #expect(viewModel.tempColor.blue == 0.7)
    }

    @Test func viewModelDefaultState() {
        let viewModel = ColorEditorView.ViewModel(color: nil)

        #expect(viewModel.mode == .grid)
        #expect(viewModel.isShowingPaletteStrip == false)
        #expect(viewModel.isColorExpanded == false)
        #expect(viewModel.didCopyHex == false)
    }

    @Test func viewModelTempColorIsIndependent() {
        let color = OpaliteColor(name: "Original", red: 0.5, green: 0.5, blue: 0.5)
        let viewModel = ColorEditorView.ViewModel(color: color)

        // Modify temp color
        viewModel.tempColor.red = 0.8

        // Original should be unchanged
        #expect(color.red == 0.5)
        #expect(viewModel.tempColor.red == 0.8)
    }
}

// MARK: - ColorDetailViewModel Tests

struct ColorDetailViewModelTests {

    @Test func viewModelInitialization() {
        let color = OpaliteColor(name: "Test", notes: "Test notes", red: 0.5, green: 0.5, blue: 0.5)
        let viewModel = ColorDetailView.ViewModel(color: color)

        #expect(viewModel.notesDraft == "Test notes")
        #expect(viewModel.isSavingNotes == false)
    }

    @Test func viewModelWithNilNotes() {
        let color = OpaliteColor(name: "Test", red: 0.5, green: 0.5, blue: 0.5)
        let viewModel = ColorDetailView.ViewModel(color: color)

        #expect(viewModel.notesDraft == "")
    }

    @Test func badgeTextWithName() {
        let color = OpaliteColor(name: "My Color", red: 0.5, green: 0.5, blue: 0.5)
        let viewModel = ColorDetailView.ViewModel(color: color)

        #expect(viewModel.badgeText == "My Color")
    }

    @Test func badgeTextWithoutName() {
        let color = OpaliteColor(red: 1, green: 0, blue: 0)
        let viewModel = ColorDetailView.ViewModel(color: color)

        #expect(viewModel.badgeText == "#FF0000")
    }
}

// MARK: - Color Utility Tests

struct ColorUtilityTests {

    @Test func hexRounding() {
        let color = OpaliteColor(red: 127.5/255.0, green: 127.5/255.0, blue: 127.5/255.0)
        #expect(color.hexString == "#808080")
    }

    @Test func extremeValues() {
        let black = OpaliteColor(red: 0.0, green: 0.0, blue: 0.0)
        let white = OpaliteColor(red: 1.0, green: 1.0, blue: 1.0)

        #expect(black.hexString == "#000000")
        #expect(white.hexString == "#FFFFFF")
    }

    @Test func nearBoundaryValues() {
        let almostWhite = OpaliteColor(red: 0.999, green: 0.999, blue: 0.999)
        let almostBlack = OpaliteColor(red: 0.001, green: 0.001, blue: 0.001)

        #expect(almostWhite.hexString == "#FFFFFF")
        #expect(almostBlack.hexString == "#000000")
    }
}

// MARK: - AppIconOption Tests

struct AppIconOptionTests {

    @Test func allCasesExist() {
        #expect(AppIconOption.allCases.count == 2)
    }

    @Test func darkIconProperties() {
        let dark = AppIconOption.dark
        #expect(dark.title == "Dark")
        #expect(dark.iconName == nil)
        #expect(dark.id == "dark")
    }

    @Test func lightIconProperties() {
        let light = AppIconOption.light
        #expect(light.title == "Light")
        #expect(light.iconName == "AppIcon-Light")
        #expect(light.id == "light")
    }
}

// MARK: - AppStage Tests

struct AppStageTests {

    @Test func rawValues() {
        #expect(AppStage.splash.rawValue == "splash")
        #expect(AppStage.onboarding.rawValue == "onboarding")
        #expect(AppStage.syncing.rawValue == "syncing")
        #expect(AppStage.main.rawValue == "main")
    }

    @Test func identifiableConformance() {
        let stages: [AppStage] = [.splash, .onboarding, .syncing, .main]
        let ids = Set(stages.map(\.id))
        #expect(ids.count == 4)
    }
}

// MARK: - AppThemeOption Tests

struct AppThemeOptionTests {

    @Test func allCasesExist() {
        #expect(AppThemeOption.allCases.count == 3)
    }

    @Test func titles() {
        #expect(AppThemeOption.system.title == "System")
        #expect(AppThemeOption.light.title == "Light")
        #expect(AppThemeOption.dark.title == "Dark")
    }

    @Test func identifiableConformance() {
        for option in AppThemeOption.allCases {
            #expect(option.id == option.rawValue)
        }
    }
}

// MARK: - CanvasShape Tests

struct CanvasShapeTests {

    @Test func allCasesExist() {
        #expect(CanvasShape.allCases.count == 7)
    }

    @Test func displayNames() {
        #expect(CanvasShape.square.displayName == "Square")
        #expect(CanvasShape.circle.displayName == "Circle")
        #expect(CanvasShape.triangle.displayName == "Triangle")
        #expect(CanvasShape.line.displayName == "Line")
        #expect(CanvasShape.arrow.displayName == "Arrow")
        #expect(CanvasShape.shirt.displayName == "Shirt")
        #expect(CanvasShape.rectangle.displayName == "Rectangle")
    }

    @Test func systemImages() {
        for shape in CanvasShape.allCases {
            #expect(!shape.systemImage.isEmpty)
        }
    }

    @Test func onlyRectangleSupportsNonUniformScale() {
        for shape in CanvasShape.allCases {
            if shape == .rectangle {
                #expect(shape.supportsNonUniformScale == true)
            } else {
                #expect(shape.supportsNonUniformScale == false)
            }
        }
    }
}

// MARK: - ColorPickerTab Tests

struct ColorPickerTabTests {

    @Test func allCasesExist() {
        #expect(ColorPickerTab.allCases.count == 6)
    }

    @Test func rawValuesAreDisplayNames() {
        #expect(ColorPickerTab.spectrum.rawValue == "Spectrum")
        #expect(ColorPickerTab.grid.rawValue == "Grid")
        #expect(ColorPickerTab.shuffle.rawValue == "Shuffle")
        #expect(ColorPickerTab.sliders.rawValue == "Channels")
        #expect(ColorPickerTab.codes.rawValue == "Codes")
        #expect(ColorPickerTab.image.rawValue == "Image")
    }

    @Test func keyboardShortcuts() {
        #expect(ColorPickerTab.spectrum.keyboardShortcutKey == "1")
        #expect(ColorPickerTab.grid.keyboardShortcutKey == "2")
        #expect(ColorPickerTab.shuffle.keyboardShortcutKey == "3")
        #expect(ColorPickerTab.sliders.keyboardShortcutKey == "4")
        #expect(ColorPickerTab.codes.keyboardShortcutKey == "5")
        #expect(ColorPickerTab.image.keyboardShortcutKey == "6")
    }

    @Test func fromKeyRoundTrip() {
        for tab in ColorPickerTab.allCases {
            let key = tab.keyboardShortcutKey
            let recovered = ColorPickerTab(fromKey: key)
            #expect(recovered == tab)
        }
    }

    @Test func fromKeyInvalidReturnsNil() {
        #expect(ColorPickerTab(fromKey: "0") == nil)
        #expect(ColorPickerTab(fromKey: "7") == nil)
        #expect(ColorPickerTab(fromKey: "a") == nil)
    }

    @Test func accessibilityLabels() {
        for tab in ColorPickerTab.allCases {
            #expect(!tab.accessibilityLabel.isEmpty)
        }
    }
}

// MARK: - CommunitySegment Tests

struct CommunitySegmentTests {

    @Test func allCasesExist() {
        #expect(CommunitySegment.allCases.count == 2)
    }

    @Test func properties() {
        #expect(CommunitySegment.colors.rawValue == "Colors")
        #expect(CommunitySegment.colors.icon == "paintpalette")

        #expect(CommunitySegment.palettes.rawValue == "Palettes")
        #expect(CommunitySegment.palettes.icon == "swatchpalette")
    }

    @Test func identifiableConformance() {
        for segment in CommunitySegment.allCases {
            #expect(segment.id == segment.rawValue)
        }
    }
}

// MARK: - DeviceKind Tests

struct DeviceKindTests {

    @Test func fromKnownDeviceNames() {
        #expect(DeviceKind.from("Apple Watch Series 9") == .appleWatch)
        #expect(DeviceKind.from("Apple Vision Pro") == .visionPro)
        #expect(DeviceKind.from("iPhone 16 Pro") == .iPhone)
        #expect(DeviceKind.from("iPad Pro 13-inch") == .iPad)
        #expect(DeviceKind.from("iMac 24-inch") == .iMac)
        #expect(DeviceKind.from("Mac Studio") == .macStudio)
        #expect(DeviceKind.from("Mac mini") == .macMini)
        #expect(DeviceKind.from("Mac Pro") == .macPro)
        #expect(DeviceKind.from("MacBook Pro 16-inch") == .macBook)
    }

    @Test func fromNilReturnsUnknown() {
        #expect(DeviceKind.from(nil) == .unknown)
    }

    @Test func fromEmptyStringReturnsUnknown() {
        #expect(DeviceKind.from("") == .unknown)
        #expect(DeviceKind.from("   ") == .unknown)
    }

    @Test func fromUnrecognizedReturnsUnknown() {
        #expect(DeviceKind.from("Toaster") == .unknown)
    }

    @Test func caseInsensitiveMatching() {
        #expect(DeviceKind.from("IPHONE") == .iPhone)
        #expect(DeviceKind.from("macbook") == .macBook)
    }

    @Test func symbolNames() {
        #expect(DeviceKind.iPhone.symbolName == "iphone")
        #expect(DeviceKind.iPad.symbolName == "ipad")
        #expect(DeviceKind.macBook.symbolName == "macbook")
        #expect(DeviceKind.unknown.symbolName == "ipad.and.iphone")
    }
}

// MARK: - PreviewBackground Tests

struct PreviewBackgroundTests {

    @Test func allCasesExist() {
        #expect(PreviewBackground.allCases.count == 8)
    }

    @Test func defaultForColorScheme() {
        #expect(PreviewBackground.defaultFor(colorScheme: .dark) == .black)
        #expect(PreviewBackground.defaultFor(colorScheme: .light) == .white)
    }

    @Test func displayNames() {
        for bg in PreviewBackground.allCases {
            #expect(!bg.displayName.isEmpty)
        }
    }

    @Test func iconNames() {
        for bg in PreviewBackground.allCases {
            #expect(!bg.iconName.isEmpty)
        }
    }

    @Test func idealTextColorContrast() {
        // Light backgrounds should have black text
        #expect(PreviewBackground.white.idealTextColor == .black)
        #expect(PreviewBackground.cream.idealTextColor == .black)

        // Dark backgrounds should have white text
        #expect(PreviewBackground.black.idealTextColor == .white)
        #expect(PreviewBackground.navy.idealTextColor == .white)
    }
}

// MARK: - SwatchSize Tests

struct SwatchSizeTests {

    @Test func allCasesExist() {
        #expect(SwatchSize.allCases.count == 3)
    }

    @Test func sizeValues() {
        #expect(SwatchSize.small.size == 75)
        #expect(SwatchSize.medium.size == 150)
        #expect(SwatchSize.large.size == 250)
    }

    @Test func showOverlays() {
        #expect(SwatchSize.small.showOverlays == false)
        #expect(SwatchSize.medium.showOverlays == true)
        #expect(SwatchSize.large.showOverlays == true)
    }

    @Test func nextCyclesThroughAll() {
        #expect(SwatchSize.small.next == .medium)
        #expect(SwatchSize.medium.next == .large)
        #expect(SwatchSize.large.next == .small)
    }

    @Test func nextCompactCyclesBetweenSmallAndMedium() {
        #expect(SwatchSize.small.nextCompact == .medium)
        #expect(SwatchSize.medium.nextCompact == .small)
        #expect(SwatchSize.large.nextCompact == .small)
    }

    @Test func accessibilityNames() {
        #expect(SwatchSize.small.accessibilityName == "Small")
        #expect(SwatchSize.medium.accessibilityName == "Medium")
        #expect(SwatchSize.large.accessibilityName == "Large")
    }
}

// MARK: - Tabs Tests

struct TabsTests {

    @Test func uniqueIDs() {
        let tabs: [Tabs] = [.portfolio, .community, .canvas, .settings, .search, .swatchBar]
        let ids = Set(tabs.map(\.id))
        #expect(ids.count == tabs.count)
    }

    @Test func names() {
        #expect(Tabs.portfolio.name == "Portfolio")
        #expect(Tabs.community.name == "Community")
        #expect(Tabs.canvas.name == "Canvas")
        #expect(Tabs.settings.name == "Settings")
        #expect(Tabs.search.name == "Search")
        #expect(Tabs.swatchBar.name == "SwatchBar")
    }

    @Test func symbols() {
        #expect(Tabs.portfolio.symbol == "paintpalette.fill")
        #expect(Tabs.community.symbol == "person.2")
        #expect(Tabs.canvas.symbol == "pencil.and.scribble")
        #expect(Tabs.settings.symbol == "gear")
        #expect(Tabs.search.symbol == "magnifyingglass")
        #expect(Tabs.swatchBar.symbol == "square.stack")
    }

    @Test func isSecondary() {
        #expect(Tabs.portfolio.isSecondary == false)
        #expect(Tabs.community.isSecondary == false)
        #expect(Tabs.canvas.isSecondary == false)
        #expect(Tabs.settings.isSecondary == false)
        #expect(Tabs.search.isSecondary == false)
        #expect(Tabs.swatchBar.isSecondary == false)
    }
}
