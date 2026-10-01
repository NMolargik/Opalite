//
//  ColorEditorViewModel.swift
//  OpaliteFeatureColorEditor
//
//  The editor's state machine, free of SwiftUI and SwiftData so it runs in host tests:
//  the working `RGBA` + name + notes, the active picker mode, channel math in RGB/HSL/HSV
//  (with hue/saturation memory so sliders don't snap when the color goes achromatic),
//  hex-field validation, shuffle with a history, an undo stack of picks, the sibling
//  "palette strip", dirty tracking for edit mode, and Apple Intelligence name suggestions
//  through the `ColorNaming` seam.
//

import Foundation
import Observation
import OpaliteCore
import os

@Observable
public final class ColorEditorViewModel {
    // MARK: - Working values

    /// The color being edited. Mutate through `pick`, `update`, or the channel setters so
    /// undo and the code fields stay in step.
    public private(set) var rgba: RGBA {
        didSet { colorDidChange() }
    }
    public var name: String
    public var notes: String
    public private(set) var mode: ColorPickerTab

    /// Whether the editor opened on an existing color.
    public let isEditing: Bool
    /// The other colors of the palette this color belongs to (for the strip).
    public let siblingColors: [RGBA]
    public var isShowingPaletteStrip = false

    // MARK: - Undo

    public private(set) var undoStack: [RGBA] = []
    public var canUndo: Bool { !undoStack.isEmpty }
    @ObservationIgnored private var isInGesture = false
    private static let undoLimit = 50

    // MARK: - Shuffle

    public private(set) var shuffleHistory: [RGBA] = []
    @ObservationIgnored private var recentHues: [Double] = []
    @ObservationIgnored private var generator: any RandomNumberGenerator
    public static let shuffleHistoryLimit = 12

    // MARK: - Codes

    /// The hex field's text without the "#" (uppercase hex digits only, at most 8).
    public private(set) var hexField = ""
    public private(set) var hexFieldState: HexFieldState = .valid

    public enum HexFieldState: Sendable, Equatable {
        /// Empty or a partial entry.
        case neutral
        /// A complete, parseable code.
        case valid
        /// A complete-length entry that does not parse.
        case invalid
    }

    // MARK: - Names

    public private(set) var nameSuggestions: [String] = []
    public private(set) var isLoadingSuggestions = false
    @ObservationIgnored private var suggestionTask: Task<Void, Never>?

    // MARK: - Private state

    private let original: ColorEditorResult?
    @ObservationIgnored private var hueMemory: Double
    @ObservationIgnored private var hsvSaturationMemory: Double
    @ObservationIgnored private var hslSaturationMemory: Double
    @ObservationIgnored private var isSyncingFields = false
    private static let epsilon = 0.0005

    // MARK: - Init

    /// The default starting color for a new color: a soft slate blue.
    public static let defaultNewColor = RGBA(red: 0.5, green: 0.6, blue: 0.7)

    public convenience init(mode: ColorEditorMode, initialTab: ColorPickerTab = .spectrum) {
        switch mode {
        case .create(let palette, let initial):
            self.init(
                rgba: initial ?? Self.defaultNewColor,
                siblings: (palette?.sortedColors ?? []).map(\.rgba),
                initialTab: initialTab
            )
        case .edit(let color):
            self.init(
                rgba: color.rgba,
                name: color.name,
                notes: color.notes,
                original: ColorEditorResult(rgba: color.rgba, name: color.name, notes: color.notes),
                siblings: (color.palette?.sortedColors ?? []).filter { $0.id != color.id }.map(\.rgba),
                initialTab: initialTab
            )
        }
    }

    /// The designated initializer: everything is a value, so tests need no models.
    public init(
        rgba: RGBA,
        name: String? = nil,
        notes: String? = nil,
        original: ColorEditorResult? = nil,
        siblings: [RGBA] = [],
        initialTab: ColorPickerTab = .spectrum,
        generator: any RandomNumberGenerator = SystemRandomNumberGenerator()
    ) {
        self.rgba = rgba
        self.name = name ?? ""
        self.notes = notes ?? ""
        self.original = original.map(Self.normalized)
        self.isEditing = original != nil
        self.siblingColors = siblings
        self.mode = initialTab
        self.generator = generator

        let hsv = rgba.hsv
        hueMemory = hsv.hue
        hsvSaturationMemory = hsv.saturation
        hslSaturationMemory = rgba.hsl.saturation
        syncHexField()
    }

    // MARK: - Result

    /// The result Save would hand back (names and notes trimmed; empty becomes nil).
    public var result: ColorEditorResult {
        Self.normalized(ColorEditorResult(rgba: rgba, name: name, notes: notes))
    }

    /// Whether anything differs from the color the editor opened on (always true when creating).
    public var isDirty: Bool {
        guard let original else { return true }
        return result != original
    }

    /// Save is always possible for a new color; an edit needs a change.
    public var canSave: Bool { !isEditing || isDirty }

    private static func normalized(_ result: ColorEditorResult) -> ColorEditorResult {
        func trimmed(_ text: String?) -> String? {
            let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        }
        return ColorEditorResult(rgba: result.rgba, name: trimmed(result.name), notes: trimmed(result.notes))
    }

    // MARK: - Mode

    public func select(_ tab: ColorPickerTab) {
        guard tab != mode else { return }
        mode = tab
    }

    /// Switches modes from a 1–6 key; false when the key isn't a mode.
    @discardableResult
    public func selectTab(forKey key: Character) -> Bool {
        guard let tab = ColorPickerTab(fromKey: key) else { return false }
        select(tab)
        return true
    }

    // MARK: - Picking

    /// A discrete pick (grid cell, shuffle, code entry, image tap): undoable as one step.
    public func pick(_ new: RGBA) {
        guard new != rgba else { return }
        pushUndo()
        rgba = new
    }

    /// Marks the start of a continuous interaction (a drag or slider). The value when the
    /// gesture began becomes one undo step no matter how many updates follow.
    public func beginGesture() {
        guard !isInGesture else { return }
        isInGesture = true
        pushUndo()
    }

    public func endGesture() {
        isInGesture = false
    }

    /// Sets the color during a gesture; outside one it behaves like `pick`.
    public func update(_ new: RGBA) {
        guard new != rgba else { return }
        if isInGesture {
            rgba = new
        } else {
            pick(new)
        }
    }

    /// Restores the color from before the last pick or gesture.
    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        isInGesture = false
        rgba = previous
    }

    private func pushUndo() {
        undoStack.append(rgba)
        if undoStack.count > Self.undoLimit { undoStack.removeFirst(undoStack.count - Self.undoLimit) }
    }

    private func colorDidChange() {
        let hsv = rgba.hsv
        if hsv.value > Self.epsilon, hsv.saturation > Self.epsilon { hueMemory = hsv.hue }
        if hsv.value > Self.epsilon { hsvSaturationMemory = hsv.saturation }
        let hsl = rgba.hsl
        if hsl.lightness > Self.epsilon, hsl.lightness < 1 - Self.epsilon { hslSaturationMemory = hsl.saturation }
        syncHexField()
    }

    // MARK: - Channels (0...1 unless noted)

    public var red: Double {
        get { rgba.red }
        set { update(RGBA(red: ColorMath.clamp(newValue), green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)) }
    }

    public var green: Double {
        get { rgba.green }
        set { update(RGBA(red: rgba.red, green: ColorMath.clamp(newValue), blue: rgba.blue, alpha: rgba.alpha)) }
    }

    public var blue: Double {
        get { rgba.blue }
        set { update(RGBA(red: rgba.red, green: rgba.green, blue: ColorMath.clamp(newValue), alpha: rgba.alpha)) }
    }

    public var alpha: Double {
        get { rgba.alpha }
        set { update(RGBA(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: ColorMath.clamp(newValue))) }
    }

    /// Hue in degrees 0..<360; remembered across achromatic colors.
    public var hue: Double {
        get {
            let hsv = rgba.hsv
            return (hsv.saturation > Self.epsilon && hsv.value > Self.epsilon) ? hsv.hue : hueMemory
        }
        set {
            let wrapped = ((newValue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
            hueMemory = wrapped
            update(withAlpha(HSV(hue: wrapped, saturation: hsvSaturation, value: brightness).rgba))
        }
    }

    /// HSV saturation; remembered while the color is black.
    public var hsvSaturation: Double {
        get { rgba.hsv.value > Self.epsilon ? rgba.hsv.saturation : hsvSaturationMemory }
        set {
            let clamped = ColorMath.clamp(newValue)
            hsvSaturationMemory = clamped
            update(withAlpha(HSV(hue: hue, saturation: clamped, value: brightness).rgba))
        }
    }

    /// HSV value.
    public var brightness: Double {
        get { rgba.hsv.value }
        set { update(withAlpha(HSV(hue: hue, saturation: hsvSaturation, value: ColorMath.clamp(newValue)).rgba)) }
    }

    /// HSL saturation; remembered while the color is black or white.
    public var hslSaturation: Double {
        get {
            let hsl = rgba.hsl
            return (hsl.lightness > Self.epsilon && hsl.lightness < 1 - Self.epsilon) ? hsl.saturation : hslSaturationMemory
        }
        set {
            let clamped = ColorMath.clamp(newValue)
            hslSaturationMemory = clamped
            update(withAlpha(HSL(hue: hue, saturation: clamped, lightness: lightness).rgba))
        }
    }

    public var lightness: Double {
        get { rgba.hsl.lightness }
        set { update(withAlpha(HSL(hue: hue, saturation: hslSaturation, lightness: ColorMath.clamp(newValue)).rgba)) }
    }

    /// Sets saturation and brightness together (the spectrum plane).
    public func setSaturationAndBrightness(saturation: Double, brightness: Double) {
        let s = ColorMath.clamp(saturation), v = ColorMath.clamp(brightness)
        hsvSaturationMemory = s
        update(withAlpha(HSV(hue: hue, saturation: s, value: v).rgba))
    }

    private func withAlpha(_ value: RGBA) -> RGBA {
        var copy = value
        copy.alpha = rgba.alpha
        return copy
    }

    // MARK: - Codes

    /// Accepts typed hex text: strips "#", uppercases, drops non-hex characters, caps at 8,
    /// and applies the color live once six or eight digits are present.
    public func setHexField(_ text: String) {
        let sanitized = String(text.uppercased().filter(\.isHexDigit).prefix(8))
        hexField = sanitized
        hexFieldState = Self.validate(hexDigits: sanitized)
        if hexFieldState == .valid, sanitized.count == 6 || sanitized.count == 8, let parsed = ColorMath.parseHex(sanitized) {
            isSyncingFields = true
            pick(sanitized.count == 6 ? withAlpha(parsed) : parsed)
            isSyncingFields = false
        }
    }

    /// Applies the field on submit (3/4/6/8 digits). Invalid text snaps back to the current
    /// color. Returns whether the text was accepted.
    @discardableResult
    public func commitHexField() -> Bool {
        guard let parsed = ColorMath.parseHex(hexField) else {
            syncHexField()
            return false
        }
        pick(hexField.count == 6 || hexField.count == 3 ? withAlpha(parsed) : parsed)
        syncHexField()
        return true
    }

    /// Applies 0–255 channel values; false (and no change) when any is out of range.
    @discardableResult
    public func applyRGBBytes(red: Int, green: Int, blue: Int) -> Bool {
        guard (0...255).contains(red), (0...255).contains(green), (0...255).contains(blue) else { return false }
        pick(RGBA(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, alpha: rgba.alpha))
        return true
    }

    /// Applies hue in degrees and saturation/lightness in percent.
    @discardableResult
    public func applyHSL(hueDegrees: Double, saturationPercent: Double, lightnessPercent: Double) -> Bool {
        guard (0...360).contains(hueDegrees), (0...100).contains(saturationPercent), (0...100).contains(lightnessPercent) else { return false }
        hueMemory = hueDegrees.truncatingRemainder(dividingBy: 360)
        hslSaturationMemory = saturationPercent / 100
        pick(withAlpha(HSL(hue: hueDegrees, saturation: saturationPercent / 100, lightness: lightnessPercent / 100).rgba))
        return true
    }

    /// Applies opacity in percent.
    @discardableResult
    public func applyAlphaPercent(_ percent: Int) -> Bool {
        guard (0...100).contains(percent) else { return false }
        pick(RGBA(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: Double(percent) / 100))
        return true
    }

    /// Classifies typed hex digits (no "#"): partial entries are neutral, 3/4/6/8 digits
    /// are valid, other complete-looking lengths are invalid.
    public static func validate(hexDigits text: String) -> HexFieldState {
        guard !text.isEmpty else { return .neutral }
        guard text.allSatisfy(\.isHexDigit) else { return .invalid }
        switch text.count {
        case 3, 4, 6, 8: return .valid
        case 1, 2, 5, 7: return .neutral
        default: return .invalid
        }
    }

    private func syncHexField() {
        guard !isSyncingFields else { return }
        let hex = rgba.alpha < 1 ? rgba.hexWithAlphaString : rgba.hexString
        hexField = String(hex.dropFirst())
        hexFieldState = .valid
    }

    // MARK: - Shuffle

    /// Jumps to a random, clearly different color and remembers where it came from.
    public func shuffle() {
        // Remember where we are (the last shuffle's hue, or whatever the user picked since),
        // then draw a hue far from the last few.
        let current = hue
        if recentHues.last.map({ ShuffleEngine.hueDistance($0, current) > 0.5 }) ?? true {
            recentHues.append(current)
        }
        trimRecentHues()
        let next = ShuffleEngine.next(avoiding: recentHues, using: &generator)

        shuffleHistory.insert(rgba, at: 0)
        if shuffleHistory.count > Self.shuffleHistoryLimit { shuffleHistory.removeLast() }

        pick(withAlpha(next.rgba))
    }

    private func trimRecentHues() {
        if recentHues.count > ShuffleEngine.rememberedHues { recentHues.removeFirst(recentHues.count - ShuffleEngine.rememberedHues) }
    }

    /// Returns to a color from the shuffle history (as an undoable pick).
    public func restoreFromHistory(_ value: RGBA) {
        pick(value)
    }

    // MARK: - Names

    public func applySuggestion(_ suggestion: String) {
        name = suggestion
    }

    public func clearNameSuggestions() {
        suggestionTask?.cancel()
        suggestionTask = nil
        nameSuggestions = []
        isLoadingSuggestions = false
    }

    /// Asks Apple Intelligence for names for the current color. A no-op when unavailable.
    public func loadNameSuggestions(using namer: any ColorNaming, count: Int = ColorNamePrompt.defaultCount) {
        guard namer.isAvailable else { return }
        suggestionTask?.cancel()
        isLoadingSuggestions = true
        nameSuggestions = []
        let color = rgba
        suggestionTask = Task { [weak self] in
            do {
                let names = try await namer.suggestNames(for: color, count: count)
                guard !Task.isCancelled, let self else { return }
                self.nameSuggestions = names
            } catch {
                guard !Task.isCancelled else { return }
                Log.intelligence.error("Name suggestions failed: \(error.localizedDescription)")
            }
            self?.isLoadingSuggestions = false
        }
    }

    // MARK: - Descriptions

    /// "Hue 210°, saturation 60%, brightness 80%" for VoiceOver on the spectrum controls.
    public var hsvDescription: String {
        String(localized: "Hue \(Int(hue.rounded())) degrees, saturation \(Int((hsvSaturation * 100).rounded())) percent, brightness \(Int((brightness * 100).rounded())) percent")
    }

    /// "Vivid Blue" for the readouts and VoiceOver.
    public var familyDescription: String {
        ColorClassifier.description(of: rgba).capitalized
    }
}

// MARK: - Shuffle engine

/// Random colors that stay visibly far from recent hues and avoid muddy extremes. The new
/// hue is drawn from the stretches of the wheel that keep `minimumHueDistance` from every
/// avoided hue (weighted by their width), so the guarantee holds whenever one exists.
nonisolated public enum ShuffleEngine {
    /// Minimum angular distance from every recent hue, in degrees.
    public static let minimumHueDistance = 54.0
    /// How many previous hues to steer clear of (3 × 108° < 360°, so a gap always exists).
    public static let rememberedHues = 3
    public static let saturationRange = 0.6...1.0
    public static let valueRange = 0.5...1.0

    public static func next(avoiding hues: [Double], using generator: inout some RandomNumberGenerator) -> HSV {
        HSV(
            hue: nextHue(avoiding: hues, using: &generator),
            saturation: Double.random(in: saturationRange, using: &generator),
            value: Double.random(in: valueRange, using: &generator)
        )
    }

    /// A hue at least `minimumHueDistance` from every avoided hue when possible; otherwise
    /// the middle of the widest gap.
    public static func nextHue(avoiding hues: [Double], using generator: inout some RandomNumberGenerator) -> Double {
        let sorted = hues.map(normalize).sorted()
        guard let first = sorted.first else { return Double.random(in: 0..<360, using: &generator) }

        var gaps: [(start: Double, width: Double)] = []
        for (index, start) in sorted.enumerated() {
            let end = index + 1 < sorted.count ? sorted[index + 1] : first + 360
            gaps.append((start, end - start))
        }

        let usable = gaps.compactMap { gap -> (start: Double, width: Double)? in
            let width = gap.width - 2 * minimumHueDistance
            return width > 0 ? (gap.start + minimumHueDistance, width) : nil
        }
        guard !usable.isEmpty else {
            let widest = gaps.max { $0.width < $1.width }!
            return normalize(widest.start + widest.width / 2)
        }

        let total = usable.reduce(0) { $0 + $1.width }
        var roll = Double.random(in: 0..<total, using: &generator)
        for span in usable {
            if roll < span.width { return normalize(span.start + roll) }
            roll -= span.width
        }
        return normalize(usable[usable.count - 1].start)
    }

    /// Shortest distance around the wheel (0...180).
    public static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    private static func normalize(_ hue: Double) -> Double {
        ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - Grid palette

/// The named swatch grid: a grayscale row, then one hue per column with a tone per row.
nonisolated public enum GridPalette {
    public struct Cell: Identifiable, Hashable, Sendable {
        public let id: Int
        public let rgba: RGBA
        public let name: String
    }

    public struct Tone: Sendable {
        public let name: String
        public let saturation: Double
        public let value: Double
    }

    public static let columns = 12

    public static let tones: [Tone] = [
        Tone(name: String(localized: "Pastel"), saturation: 0.28, value: 1.0),
        Tone(name: String(localized: "Light"), saturation: 0.5, value: 1.0),
        Tone(name: String(localized: "Bright"), saturation: 0.78, value: 1.0),
        Tone(name: String(localized: "Vivid"), saturation: 1.0, value: 1.0),
        Tone(name: String(localized: "Rich"), saturation: 1.0, value: 0.82),
        Tone(name: String(localized: "Deep"), saturation: 1.0, value: 0.64),
        Tone(name: String(localized: "Dark"), saturation: 0.95, value: 0.46),
        Tone(name: String(localized: "Shadow"), saturation: 0.85, value: 0.3),
    ]

    public static var rows: Int { tones.count + 1 }

    /// Every cell in reading order (row-major).
    public static var cells: [Cell] {
        var result: [Cell] = []
        result.reserveCapacity(rows * columns)
        for column in 0..<columns {
            let t = Double(column) / Double(columns - 1)
            let white = 1 - t
            let name: String
            switch column {
            case 0: name = String(localized: "White")
            case columns - 1: name = String(localized: "Black")
            default: name = String(localized: "Gray \(Int((white * 100).rounded()))%")
            }
            result.append(Cell(id: column, rgba: RGBA(red: white, green: white, blue: white), name: name))
        }
        for (rowIndex, tone) in tones.enumerated() {
            for column in 0..<columns {
                let hue = Double(column) / Double(columns) * 360
                let rgba = HSV(hue: hue, saturation: tone.saturation, value: tone.value).rgba
                let family = ColorClassifier.family(of: rgba).rawValue.capitalized
                let id = (rowIndex + 1) * columns + column
                result.append(Cell(id: id, rgba: rgba, name: "\(tone.name) \(family)"))
            }
        }
        return result
    }

    /// The cell matching a color closely enough to show as selected, if any.
    public static func cell(matching rgba: RGBA, tolerance: Double = 0.0125) -> Cell? {
        cells.first { cell in
            abs(cell.rgba.red - rgba.red) <= tolerance
                && abs(cell.rgba.green - rgba.green) <= tolerance
                && abs(cell.rgba.blue - rgba.blue) <= tolerance
        }
    }
}
