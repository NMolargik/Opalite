//
//  DesignSystemTests.swift
//  OpaliteDesignSystemTests
//

import Foundation
import SwiftUI
import Testing
import OpaliteCore
@testable import OpaliteDesignSystem

@Suite("Color bridging")
struct ColorBridgingTests {
    @Test("Hex → Color → hex round trips", arguments: ["#FF0000", "#00FF00", "#0000FF", "#3380CC", "#000000", "#FFFFFF", "#8040BF"])
    func hexRoundTrip(hex: String) throws {
        let color = try #require(Color(hex: hex))
        #expect(color.toHex() == hex)
    }

    @Test func shorthandAndAlphaHex() throws {
        #expect(try #require(Color(hex: "#F53")).toHex() == "#FF5533")
        let translucent = try #require(Color(hex: "#FF000080"))
        #expect(translucent.toHex() == "#FF0000")
        #expect(translucent.rgba?.alpha.isClose(to: 0x80 / 255) == true)
    }

    @Test func invalidHexIsNil() {
        #expect(Color(hex: "nope") == nil)
        #expect(Color(hex: "") == nil)
        #expect(Color(hex: "#12345") == nil)
    }

    @Test func rgbaRoundTrip() throws {
        let rgba = RGBA(red: 0.2, green: 0.5, blue: 0.8, alpha: 0.6)
        let resolved = try #require(Color(rgba).rgba)
        #expect(resolved.isClose(to: rgba, tolerance: 0.002))
        #expect(rgba.color.toHex() == "#3380CC")
    }

    @Test func idealTextColorFollowsThePreference() {
        #expect(RGBA.white.idealTextColor == .black)
        #expect(RGBA.black.idealTextColor == .white)
        for sample in [RGBA(red: 1, green: 1, blue: 0), RGBA(red: 0, green: 0, blue: 0.6), RGBA(red: 0.5, green: 0.5, blue: 0.5)] {
            #expect(sample.idealTextColor == (sample.prefersDarkText ? Color.black : Color.white))
        }
    }

    @Test func modelBridging() throws {
        let color = OpaliteColor(red: 0.2, green: 0.5, blue: 0.8)
        #expect(color.swiftUIColor.toHex() == "#3380CC")
        #expect(color.idealTextColor() == .white)
        #expect(color.simulatedSwiftUIColor(.off) == color.swiftUIColor)
        #expect(color.simulatedSwiftUIColor(.protanopia) != color.swiftUIColor)
        let simulated = try #require(color.simulatedSwiftUIColor(.achromatopsia).rgba)
        #expect(simulated.red.isClose(to: simulated.green, tolerance: 0.002))
    }

    @Test func communityWatchAndWidgetBridging() {
        #expect(CommunityColor.sample.swiftUIColor.toHex() == CommunityColor.sample.hexString)
        #expect(CommunityColor.sample.idealTextColor() == CommunityColor.sample.rgba.idealTextColor)
        #expect(CommunityColor.sample.simulatedSwiftUIColor(.off) == CommunityColor.sample.swiftUIColor)
        #expect(WatchColor.sample.swiftUIColor.toHex() == WatchColor.sample.hexString)
        #expect(WatchColor.sample.idealTextColor() == WatchColor.sample.rgba.idealTextColor)
        let widget = WidgetColor(id: UUID(), name: nil, red: 1, green: 1, blue: 1, alpha: 1)
        #expect(widget.swiftUIColor.toHex() == "#FFFFFF")
        #expect(widget.idealTextColor == .black)
    }

    @Test("PreviewBackground colors match their RGBA", arguments: PreviewBackground.allCases)
    func previewBackground(background: PreviewBackground) throws {
        let resolved = try #require(background.color.rgba)
        #expect(resolved.isClose(to: background.rgba, tolerance: 0.002))
        #expect(background.idealTextColor == (background.prefersDarkText ? Color.black : Color.white))
    }

    @Test func previewBackgroundDefaultsPerScheme() {
        #expect(PreviewBackground.defaultFor(colorScheme: .dark) == .black)
        #expect(PreviewBackground.defaultFor(colorScheme: .light) == .white)
    }
}

@Suite("Brand tokens")
struct BrandTests {
    @Test func spacingAndRadiiAscend() {
        let spaces = [Brand.Space.xs, Brand.Space.sm, Brand.Space.md, Brand.Space.lg, Brand.Space.xl, Brand.Space.xxl]
        #expect(spaces == spaces.sorted() && Set(spaces).count == spaces.count)
        let radii = [Brand.Radius.chip, Brand.Radius.control, Brand.Radius.swatch, Brand.Radius.card, Brand.Radius.sheet]
        #expect(radii == radii.sorted() && Set(radii).count == radii.count)
        #expect(Brand.readableWidth < Brand.detailMaxWidth)
    }

    @Test func brandColorsResolve() {
        #expect(Color.opaliteBlue.rgba != nil)
        #expect(Color.opalitePurple.rgba != nil)
        #expect(Color.opaliteTan.rgba != nil)
        #expect(Color.onyx.rgba != nil)
        #expect(Color.onyx.rgba.map { $0.relativeLuminance < 0.05 } == true)
        #expect(Color.opaliteBlue.rgba.map { $0.prefersDarkText } == true)
    }

    @Test func hapticsAreCallableEverywhere() {
        let previous = Haptics.isEnabled
        Haptics.isEnabled = false
        defer { Haptics.isEnabled = previous }
        Haptics.lightImpact(); Haptics.mediumImpact(); Haptics.selection(); Haptics.success(); Haptics.warning(); Haptics.error()
    }
}

@Suite("Localized titles")
struct LocalizedTitleTests {
    @Test("AppTab", arguments: AppTab.allCases)
    func appTab(tab: AppTab) {
        #expect(!tab.title.isEmpty)
        _ = tab.color
    }

    @Test func appTabTitlesAreUnique() {
        #expect(Set(AppTab.allCases.map(\.title)).count == AppTab.allCases.count)
    }

    @Test("ColorPickerTab", arguments: ColorPickerTab.allCases)
    func pickerTab(tab: ColorPickerTab) {
        #expect(!tab.title.isEmpty && !tab.accessibilityLabel.isEmpty)
    }

    @Test("ColorBlindnessMode", arguments: ColorBlindnessMode.allCases)
    func blindnessMode(mode: ColorBlindnessMode) {
        #expect(!mode.title.isEmpty && !mode.shortTitle.isEmpty && !mode.modeDescription.isEmpty)
        #expect(mode.title.hasPrefix(mode.shortTitle) || mode == .off)
    }

    @Test("AppThemeOption", arguments: AppThemeOption.allCases)
    func theme(option: AppThemeOption) {
        #expect(!option.title.isEmpty)
        switch option {
        case .system: #expect(option.preferredColorScheme == nil)
        case .light: #expect(option.preferredColorScheme == .light)
        case .dark: #expect(option.preferredColorScheme == .dark)
        }
    }

    @Test("AppIconOption", arguments: AppIconOption.allCases)
    func icon(option: AppIconOption) { #expect(!option.title.isEmpty) }

    @Test("SwatchSize", arguments: SwatchSize.allCases)
    func swatchSize(size: SwatchSize) { #expect(!size.accessibilityName.isEmpty) }

    @Test("PreviewBackground", arguments: PreviewBackground.allCases)
    func previewBackground(background: PreviewBackground) { #expect(!background.displayName.isEmpty) }

    @Test("CanvasShape", arguments: CanvasShape.allCases)
    func canvasShape(shape: CanvasShape) { #expect(!shape.displayName.isEmpty) }

    @Test("CommunitySortOption", arguments: CommunitySortOption.allCases)
    func sortOption(option: CommunitySortOption) { #expect(!option.title.isEmpty) }

    @Test("CommunitySegment", arguments: CommunitySegment.allCases)
    func segment(segment: CommunitySegment) { #expect(!segment.title.isEmpty) }

    @Test("ReportReason", arguments: ReportReason.allCases)
    func reportReason(reason: ReportReason) { #expect(!reason.title.isEmpty) }

    @Test("OnyxSubscription", arguments: OnyxSubscription.allCases)
    func onyx(product: OnyxSubscription) { #expect(!product.displayName.isEmpty && !product.priceDescription.isEmpty) }

    @Test("ColorExportFormat", arguments: ColorExportFormat.allCases)
    func colorExport(format: ColorExportFormat) {
        #expect(!format.displayName.isEmpty && !format.formatDescription.isEmpty)
        _ = format.tint
    }

    @Test("PaletteExportFormat", arguments: PaletteExportFormat.allCases)
    func paletteExport(format: PaletteExportFormat) {
        #expect(!format.displayName.isEmpty && !format.formatDescription.isEmpty)
        _ = format.tint
    }

    @Test("WCAG level", arguments: [WCAGConformance.Level.aaa, .aa, .aaLarge, .fail])
    func wcagLevel(level: WCAGConformance.Level) {
        #expect(!level.title.isEmpty)
        _ = level.color
    }

    @Test func wcagLevelColorsAreDistinct() {
        let levels: [WCAGConformance.Level] = [.aaa, .aa, .aaLarge, .fail]
        #expect(Set(levels.map { $0.color.description }).count == 4)
    }
}

@Suite("ToastManager")
struct ToastManagerTests {
    @Test func initialState() {
        #expect(ToastManager().currentToast == nil)
    }

    @Test func showSetsTheCurrentToast() {
        let manager = ToastManager()
        manager.show(message: "Hello", style: .info, systemImage: "star")
        let toast = manager.currentToast
        #expect(toast?.message == "Hello")
        #expect(toast?.style == .info)
        #expect(toast?.systemImage == "star")
        #expect(toast?.duration == 3)
    }

    @Test func showSuccessUsesTheSuccessStyle() {
        let manager = ToastManager()
        manager.showSuccess("Saved", systemImage: "checkmark")
        #expect(manager.currentToast?.style == .success)
        #expect(manager.currentToast?.message == "Saved")
    }

    @Test func showErrorCarriesTheOpaliteErrorSymbolAndAction() {
        let manager = ToastManager()
        var fired = false
        manager.show(error: OpaliteError.paletteLimitReached, actionTitle: "Get Onyx") { fired = true }
        let toast = manager.currentToast
        #expect(toast?.style == .error)
        #expect(toast?.message == OpaliteError.paletteLimitReached.errorDescription)
        #expect(toast?.systemImage == OpaliteError.paletteLimitReached.systemImage)
        #expect(toast?.actionTitle == "Get Onyx")
        #expect(toast?.duration == 5, "actionable toasts stay longer")
        toast?.action?()
        #expect(fired)
    }

    @Test func showErrorForNonOpaliteErrorsUsesTheDescription() {
        struct Boom: LocalizedError { var errorDescription: String? { "Boom" } }
        let manager = ToastManager()
        manager.show(error: Boom())
        #expect(manager.currentToast?.message == "Boom")
        #expect(manager.currentToast?.systemImage == nil)
    }

    @Test func dismissClearsTheToast() {
        let manager = ToastManager()
        manager.show(message: "x")
        manager.dismiss()
        #expect(manager.currentToast == nil)
    }

    @Test func showReplacesTheExistingToast() {
        let manager = ToastManager()
        manager.show(message: "first")
        let first = manager.currentToast
        manager.show(message: "second")
        #expect(manager.currentToast?.message == "second")
        #expect(manager.currentToast != first)
    }

    @Test func toastsAutoDismissAfterTheirDuration() async {
        let manager = ToastManager()
        manager.show(ToastItem(message: "quick", duration: 0.05))
        #expect(manager.currentToast != nil)
        try? await Task.sleep(for: .milliseconds(250))
        #expect(manager.currentToast == nil)
    }

    @Test func replacingAToastCancelsTheOldTimer() async {
        let manager = ToastManager()
        manager.show(ToastItem(message: "quick", duration: 0.05))
        manager.show(ToastItem(message: "long", duration: 5))
        try? await Task.sleep(for: .milliseconds(200))
        #expect(manager.currentToast?.message == "long", "the first toast's timer must not dismiss the second")
        manager.dismiss()
    }

    @Test func toastItemDefaultsAndEquality() {
        let a = ToastItem(message: "m")
        let b = ToastItem(message: "m")
        #expect(a.style == .info && a.systemImage == nil && a.duration == 3 && a.actionTitle == nil && a.action == nil)
        #expect(a != b, "identity, not content")
        #expect(a == a)
        #expect(ToastItem(message: "m", duration: 1, actionTitle: "A", action: {}).duration == 5)
        #expect(ToastItem(message: "m", duration: 8, actionTitle: "A", action: {}).duration == 8)
    }

    @Test func stylesHaveDistinctSymbols() {
        let styles: [ToastStyle] = [.error, .success, .info]
        #expect(Set(styles.map(\.systemImage)).count == 3)
        #expect(ToastStyle.error.tint == .red && ToastStyle.success.tint == .green)
    }
}

extension Double {
    func isClose(to other: Double, tolerance: Double = 0.001) -> Bool { abs(self - other) <= tolerance }
}

extension RGBA {
    func isClose(to other: RGBA, tolerance: Double = 0.001) -> Bool {
        red.isClose(to: other.red, tolerance: tolerance) && green.isClose(to: other.green, tolerance: tolerance)
            && blue.isClose(to: other.blue, tolerance: tolerance) && alpha.isClose(to: other.alpha, tolerance: tolerance)
    }
}
