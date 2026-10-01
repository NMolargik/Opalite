//
//  ColorEditorViewModelTests.swift
//  OpaliteFeatureColorEditorTests
//
//  Host tests for the editor's pure state: hex validation, channel math, shuffle, undo,
//  edit-mode dirty tracking, result building, name suggestions, and the grid palette.
//

import Foundation
import Testing
import OpaliteCore
@testable import OpaliteFeatureColorEditor

// MARK: - Helpers

/// A deterministic generator so shuffle tests are repeatable.
nonisolated private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@MainActor
private final class FakeNamer: ColorNaming {
    var isAvailable: Bool
    var names: [String]
    var shouldThrow = false
    private(set) var requests = 0

    init(isAvailable: Bool = true, names: [String] = ["Harbor Mist", "Slate Dusk"]) {
        self.isAvailable = isAvailable
        self.names = names
    }

    func suggestNames(for color: RGBA, count: Int) async throws -> [String] {
        requests += 1
        if shouldThrow { throw CocoaError(.featureUnsupported) }
        return Array(names.prefix(count))
    }
}

private func approximately(_ a: RGBA, _ b: RGBA, tolerance: Double = 0.003) -> Bool {
    abs(a.red - b.red) <= tolerance && abs(a.green - b.green) <= tolerance && abs(a.blue - b.blue) <= tolerance && abs(a.alpha - b.alpha) <= tolerance
}

private let seedColor = RGBA(red: 0.2, green: 0.5, blue: 0.8)

// MARK: - Hex field

@Suite("Hex field")
@MainActor
struct HexFieldTests {
    @Test func syncsFromColorWithoutPrefix() {
        let viewModel = ColorEditorViewModel(rgba: RGBA(red: 1, green: 0, blue: 0))
        #expect(viewModel.hexField == "FF0000")
        #expect(viewModel.hexFieldState == .valid)
    }

    @Test func includesAlphaDigitsWhenTranslucent() {
        let viewModel = ColorEditorViewModel(rgba: RGBA(red: 1, green: 0, blue: 0, alpha: 0.5))
        #expect(viewModel.hexField == "FF000080")
    }

    @Test func sanitizesTypedText() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.setHexField("#ab-12zq")
        #expect(viewModel.hexField == "AB12")
        viewModel.setHexField("123456789abc")
        #expect(viewModel.hexField == "12345678")
    }

    @Test(arguments: [("", ColorEditorViewModel.HexFieldState.neutral), ("A", .neutral), ("AB", .neutral), ("ABC", .valid), ("ABCD", .valid), ("ABCDE", .neutral), ("ABCDEF", .valid), ("ABCDEF1", .neutral), ("ABCDEF12", .valid), ("GHIJKL", .invalid)])
    func classifiesDigits(text: String, expected: ColorEditorViewModel.HexFieldState) {
        #expect(ColorEditorViewModel.validate(hexDigits: text) == expected)
    }

    @Test func appliesLiveAtSixDigitsAndKeepsAlpha() {
        let viewModel = ColorEditorViewModel(rgba: RGBA(red: 0, green: 0, blue: 0, alpha: 0.4))
        viewModel.setHexField("00FF0")
        #expect(viewModel.rgba.green == 0, "A partial entry must not apply")
        viewModel.setHexField("00FF00")
        #expect(viewModel.rgba.green == 1)
        #expect(viewModel.rgba.alpha == 0.4)
        #expect(viewModel.hexField == "00FF00", "Typing must not be overwritten by the sync")
    }

    @Test func appliesAlphaAtEightDigits() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.setHexField("0000FF80")
        #expect(viewModel.rgba.blue == 1)
        #expect(abs(viewModel.rgba.alpha - 128.0 / 255.0) < 0.001)
    }

    @Test func commitAcceptsShorthandAndRejectsGarbage() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.setHexField("F0A")
        #expect(viewModel.commitHexField())
        #expect(viewModel.rgba == RGBA(red: 1, green: 0, blue: 10.0 / 15.0))
        #expect(viewModel.hexField == "FF00AA")

        viewModel.setHexField("ABCDE")
        #expect(viewModel.commitHexField() == false)
        #expect(viewModel.hexField == "FF00AA", "Invalid text snaps back to the current color")
        #expect(viewModel.hexFieldState == .valid)
    }

    @Test func rgbBytesAndHSLAndAlphaEntry() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        #expect(viewModel.applyRGBBytes(red: 255, green: 128, blue: 0))
        #expect(viewModel.rgba.red == 1)
        #expect(viewModel.rgba.green == 128.0 / 255.0)
        #expect(viewModel.applyRGBBytes(red: 256, green: 0, blue: 0) == false)
        #expect(viewModel.rgba.red == 1, "Out-of-range input leaves the color alone")

        #expect(viewModel.applyHSL(hueDegrees: 120, saturationPercent: 100, lightnessPercent: 50))
        #expect(approximately(viewModel.rgba, RGBA(red: 0, green: 1, blue: 0)))
        #expect(viewModel.applyHSL(hueDegrees: 400, saturationPercent: 10, lightnessPercent: 10) == false)

        #expect(viewModel.applyAlphaPercent(25))
        #expect(viewModel.rgba.alpha == 0.25)
        #expect(viewModel.applyAlphaPercent(101) == false)
    }
}

// MARK: - Channels

@Suite("Channel sliders")
@MainActor
struct ChannelTests {
    @Test func rgbSettersClampAndPreserveOtherChannels() {
        let viewModel = ColorEditorViewModel(rgba: RGBA(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.9))
        viewModel.red = 1.5
        #expect(viewModel.rgba == RGBA(red: 1, green: 0.5, blue: 0.8, alpha: 0.9))
        viewModel.green = -1
        #expect(viewModel.rgba.green == 0)
        viewModel.blue = 0.25
        #expect(viewModel.rgba.blue == 0.25)
        viewModel.alpha = 0.5
        #expect(viewModel.rgba == RGBA(red: 1, green: 0, blue: 0.25, alpha: 0.5))
    }

    @Test func hueSetterRotatesAndKeepsAlpha() {
        let viewModel = ColorEditorViewModel(rgba: RGBA(red: 1, green: 0, blue: 0, alpha: 0.7))
        viewModel.hue = 240
        #expect(approximately(viewModel.rgba, RGBA(red: 0, green: 0, blue: 1, alpha: 0.7)))
        #expect(abs(viewModel.hue - 240) < 0.01)
        #expect(abs(viewModel.brightness - 1) < 0.001)
        #expect(abs(viewModel.hsvSaturation - 1) < 0.001)
    }

    @Test func hueSurvivesDesaturationAndBlack() {
        let viewModel = ColorEditorViewModel(rgba: HSV(hue: 200, saturation: 0.8, value: 0.9).rgba)
        viewModel.hsvSaturation = 0
        #expect(abs(viewModel.hue - 200) < 0.01, "A gray keeps the hue it came from")
        viewModel.hsvSaturation = 0.8
        #expect(approximately(viewModel.rgba, HSV(hue: 200, saturation: 0.8, value: 0.9).rgba))

        viewModel.brightness = 0
        #expect(viewModel.rgba == RGBA(red: 0, green: 0, blue: 0))
        #expect(abs(viewModel.hsvSaturation - 0.8) < 0.01, "Black keeps its saturation position")
        viewModel.brightness = 0.9
        #expect(approximately(viewModel.rgba, HSV(hue: 200, saturation: 0.8, value: 0.9).rgba))
    }

    @Test func hslSettersRoundTrip() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.lightness = 0.5
        viewModel.hslSaturation = 1
        viewModel.hue = 0
        #expect(approximately(viewModel.rgba, RGBA(red: 1, green: 0, blue: 0)))
        viewModel.lightness = 1
        #expect(viewModel.rgba == .white)
        #expect(abs(viewModel.hslSaturation - 1) < 0.001, "White keeps the saturation position")
        viewModel.lightness = 0.5
        #expect(approximately(viewModel.rgba, RGBA(red: 1, green: 0, blue: 0)))
    }

    @Test func planeSetsSaturationAndBrightnessTogether() {
        let viewModel = ColorEditorViewModel(rgba: RGBA(red: 1, green: 0, blue: 0))
        viewModel.setSaturationAndBrightness(saturation: 0.5, brightness: 0.5)
        #expect(approximately(viewModel.rgba, HSV(hue: 0, saturation: 0.5, value: 0.5).rgba))
        #expect(viewModel.hsvDescription.contains("50"))
    }
}

// MARK: - Shuffle

@Suite("Shuffle")
@MainActor
struct ShuffleTests {
    @Test func shuffleChangesColorAndRecordsHistory() {
        let viewModel = ColorEditorViewModel(rgba: seedColor, generator: SeededGenerator(seed: 7))
        let before = viewModel.rgba
        viewModel.shuffle()
        #expect(viewModel.rgba != before)
        #expect(viewModel.shuffleHistory == [before])
        #expect(viewModel.rgba.alpha == before.alpha)

        let hsv = viewModel.rgba.hsv
        #expect(ShuffleEngine.saturationRange.contains((hsv.saturation * 1000).rounded() / 1000))
        #expect(ShuffleEngine.valueRange.contains((hsv.value * 1000).rounded() / 1000))
    }

    @Test func consecutiveShufflesKeepHuesApart() {
        let viewModel = ColorEditorViewModel(rgba: seedColor, generator: SeededGenerator(seed: 99))
        var hues: [Double] = [viewModel.hue]
        for _ in 0..<40 {
            viewModel.shuffle()
            let hue = viewModel.hue
            for previous in hues.suffix(ShuffleEngine.rememberedHues) {
                #expect(ShuffleEngine.hueDistance(previous, hue) >= ShuffleEngine.minimumHueDistance - 0.001)
            }
            hues.append(hue)
        }
    }

    @Test func engineFallsBackToWidestGapWhenCrowded() {
        var generator = SeededGenerator(seed: 1)
        let crowded: [Double] = [0, 60, 120, 180, 240, 300]
        let hue = ShuffleEngine.nextHue(avoiding: crowded, using: &generator)
        #expect(abs(hue.truncatingRemainder(dividingBy: 60) - 30) < 0.001, "Lands in the middle of a gap")
        let single = ShuffleEngine.nextHue(avoiding: [90], using: &generator)
        #expect(ShuffleEngine.hueDistance(single, 90) >= ShuffleEngine.minimumHueDistance - 0.001)
    }

    @Test func historyIsCappedAndRestorable() {
        let viewModel = ColorEditorViewModel(rgba: seedColor, generator: SeededGenerator(seed: 3))
        for _ in 0..<(ColorEditorViewModel.shuffleHistoryLimit + 4) { viewModel.shuffle() }
        #expect(viewModel.shuffleHistory.count == ColorEditorViewModel.shuffleHistoryLimit)

        let target = viewModel.shuffleHistory[2]
        viewModel.restoreFromHistory(target)
        #expect(viewModel.rgba == target)
    }

    @Test func hueDistanceWrapsAroundTheWheel() {
        #expect(ShuffleEngine.hueDistance(10, 350) == 20)
        #expect(ShuffleEngine.hueDistance(0, 180) == 180)
        #expect(ShuffleEngine.hueDistance(90, 90) == 0)
    }
}

// MARK: - Undo

@Suite("Undo")
@MainActor
struct UndoTests {
    @Test func discretePicksUndoOneAtATime() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        #expect(viewModel.canUndo == false)
        viewModel.pick(.white)
        viewModel.pick(.black)
        #expect(viewModel.undoStack == [seedColor, .white])
        viewModel.undo()
        #expect(viewModel.rgba == .white)
        viewModel.undo()
        #expect(viewModel.rgba == seedColor)
        #expect(viewModel.canUndo == false)
        viewModel.undo()
        #expect(viewModel.rgba == seedColor, "Undo on an empty stack is harmless")
    }

    @Test func gestureCollapsesIntoOneStep() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.beginGesture()
        viewModel.red = 0.3
        viewModel.red = 0.6
        viewModel.red = 0.9
        viewModel.endGesture()
        #expect(viewModel.undoStack.count == 1)
        viewModel.undo()
        #expect(viewModel.rgba == seedColor)
    }

    @Test func pickingTheSameColorIsNotAStep() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.pick(seedColor)
        #expect(viewModel.canUndo == false)
    }
}

// MARK: - Edit mode

@Suite("Edit mode and results")
@MainActor
struct EditModeTests {
    @Test func createModeAlwaysSaves() {
        let viewModel = ColorEditorViewModel(mode: .create())
        #expect(viewModel.isEditing == false)
        #expect(viewModel.isDirty)
        #expect(viewModel.canSave)
        #expect(viewModel.rgba == ColorEditorViewModel.defaultNewColor)
    }

    @Test func createModeHonorsInitialColorAndPaletteSiblings() {
        let palette = OpalitePalette(name: "Sea", colors: [
            OpaliteColor(name: "Foam", red: 0.9, green: 0.95, blue: 1),
            OpaliteColor(name: "Kelp", red: 0.1, green: 0.4, blue: 0.3),
        ])
        let viewModel = ColorEditorViewModel(mode: .create(palette: palette, initial: RGBA(red: 0, green: 0, blue: 1)))
        #expect(viewModel.rgba == RGBA(red: 0, green: 0, blue: 1))
        #expect(viewModel.siblingColors.count == 2)
    }

    @Test func editModeTracksDirtyState() {
        let color = OpaliteColor(name: "Sky", notes: "  morning  ", red: 0.2, green: 0.5, blue: 0.8)
        let viewModel = ColorEditorViewModel(mode: .edit(color))
        #expect(viewModel.isEditing)
        #expect(viewModel.isDirty == false)
        #expect(viewModel.canSave == false)

        viewModel.name = "Sky "
        #expect(viewModel.isDirty == false, "Whitespace-only changes don't count")
        viewModel.notes = "morning"
        #expect(viewModel.isDirty == false)

        viewModel.pick(.white)
        #expect(viewModel.isDirty)
        #expect(viewModel.canSave)
        viewModel.undo()
        #expect(viewModel.isDirty == false)

        viewModel.name = "Dawn"
        #expect(viewModel.isDirty)
    }

    @Test func editModeExcludesItselfFromSiblings() {
        let me = OpaliteColor(name: "Me", red: 0.5, green: 0.5, blue: 0.5)
        let other = OpaliteColor(name: "Other", red: 0.1, green: 0.2, blue: 0.3)
        let palette = OpalitePalette(name: "Pair", colors: [me, other])
        me.palette = palette
        other.palette = palette
        let viewModel = ColorEditorViewModel(mode: .edit(me))
        #expect(viewModel.siblingColors == [other.rgba])
    }

    @Test func resultTrimsAndNilsEmptyText() {
        let viewModel = ColorEditorViewModel(rgba: seedColor, name: "  Harbor  ", notes: "   ")
        let result = viewModel.result
        #expect(result.rgba == seedColor)
        #expect(result.name == "Harbor")
        #expect(result.notes == nil)

        viewModel.name = ""
        viewModel.notes = " Keep this "
        #expect(viewModel.result.name == nil)
        #expect(viewModel.result.notes == "Keep this")
    }

    @Test func modeSwitchingByKey() {
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        #expect(viewModel.mode == .spectrum)
        #expect(viewModel.selectTab(forKey: "4"))
        #expect(viewModel.mode == .sliders)
        #expect(viewModel.selectTab(forKey: "9") == false)
        #expect(viewModel.mode == .sliders)
        viewModel.select(.image)
        #expect(viewModel.mode == .image)
    }

    @Test func modePaletteAccessor() {
        let palette = OpalitePalette(name: "P")
        #expect(ColorEditorMode.create(palette: palette).palette === palette)
        #expect(ColorEditorMode.create().palette == nil)
        #expect(ColorEditorMode.create().isEditing == false)
        let color = OpaliteColor(red: 0, green: 0, blue: 0, palette: palette)
        #expect(ColorEditorMode.edit(color).palette === palette)
        #expect(ColorEditorMode.edit(color).isEditing)
    }
}

// MARK: - Names

@Suite("Name suggestions")
@MainActor
struct NameSuggestionTests {
    @Test func loadsSuggestionsWhenAvailable() async throws {
        let namer = FakeNamer()
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.loadNameSuggestions(using: namer)
        #expect(viewModel.isLoadingSuggestions)
        try await waitUntil { !viewModel.isLoadingSuggestions }
        #expect(viewModel.nameSuggestions == ["Harbor Mist", "Slate Dusk"])
        #expect(namer.requests == 1)

        viewModel.applySuggestion("Slate Dusk")
        #expect(viewModel.name == "Slate Dusk")
        viewModel.clearNameSuggestions()
        #expect(viewModel.nameSuggestions.isEmpty)
    }

    @Test func skipsWhenUnavailable() async throws {
        let namer = FakeNamer(isAvailable: false)
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.loadNameSuggestions(using: namer)
        #expect(viewModel.isLoadingSuggestions == false)
        #expect(namer.requests == 0)
    }

    @Test func failuresClearLoading() async throws {
        let namer = FakeNamer()
        namer.shouldThrow = true
        let viewModel = ColorEditorViewModel(rgba: seedColor)
        viewModel.loadNameSuggestions(using: namer)
        try await waitUntil { !viewModel.isLoadingSuggestions }
        #expect(viewModel.nameSuggestions.isEmpty)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for condition")
    }
}

// MARK: - Grid

@Suite("Grid palette")
struct GridPaletteTests {
    @Test func gridHasGrayscaleRowThenTones() {
        let cells = GridPalette.cells
        #expect(cells.count == GridPalette.rows * GridPalette.columns)
        #expect(cells.first?.rgba == .white)
        #expect(cells[GridPalette.columns - 1].rgba == .black)
        #expect(cells.first?.name == "White")
        #expect(Set(cells.map(\.id)).count == cells.count)
        #expect(cells.allSatisfy { !$0.name.isEmpty })
        #expect(cells[GridPalette.columns].name.hasPrefix("Pastel"))
    }

    @Test func matchesExactCellsOnly() {
        let vivid = GridPalette.cells.first { $0.name == "Vivid Red" }
        let vividRed = try! #require(vivid)
        #expect(GridPalette.cell(matching: vividRed.rgba)?.id == vividRed.id)
        #expect(GridPalette.cell(matching: RGBA(red: 0.33, green: 0.21, blue: 0.47)) == nil)
    }
}
