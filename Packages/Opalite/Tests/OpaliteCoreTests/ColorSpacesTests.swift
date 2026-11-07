import Testing
@testable import OpaliteCore

@Suite struct ColorSpacesTests {
    private func near(_ a: Double, _ b: Double, _ tol: Double) -> Bool { abs(a - b) <= tol }

    @Test func oklabReferenceValues() {
        // Reference values from Ottosson's OKLab article / CSS Color 4.
        let red = RGBA(red: 1, green: 0, blue: 0).oklch
        #expect(near(red.lightness, 0.6280, 0.001) && near(red.chroma, 0.2577, 0.001) && near(red.hue, 29.23, 0.1))
        let green = RGBA(red: 0, green: 1, blue: 0).oklch
        #expect(near(green.lightness, 0.8664, 0.001) && near(green.chroma, 0.2948, 0.001) && near(green.hue, 142.5, 0.1))
        let blue = RGBA(red: 0, green: 0, blue: 1).oklch
        #expect(near(blue.lightness, 0.4520, 0.001) && near(blue.chroma, 0.3132, 0.001) && near(blue.hue, 264.05, 0.1))
        let white = RGBA.white.oklab
        #expect(near(white.lightness, 1, 0.0005) && near(white.a, 0, 0.0005) && near(white.b, 0, 0.0005))
        #expect(near(RGBA.black.oklab.lightness, 0, 1e-6))
    }

    @Test func oklchRoundTrips() {
        for hex in ["#FF8800", "#123456", "#C4E9F9", "#808080", "#00FFAA"] {
            let color = RGBA(hex: hex)!
            let back = color.oklch.extendedSRGB
            #expect(near(back.red, color.red, 1e-6) && near(back.green, color.green, 1e-6) && near(back.blue, color.blue, 1e-6))
        }
        #expect(RGBA(hex: "#808080")!.oklch.chroma < 1e-4)
    }

    @Test func displayP3ReferenceValues() {
        let p3 = RGBA(red: 1, green: 0, blue: 0).displayP3
        #expect(near(p3.red, 0.9175, 0.001) && near(p3.green, 0.2003, 0.001) && near(p3.blue, 0.1386, 0.001))
        let white = RGBA.white.displayP3
        #expect(near(white.red, 1, 1e-4) && near(white.green, 1, 1e-4) && near(white.blue, 1, 1e-4))
        // Pure P3 green is outside sRGB.
        let green = DisplayP3(red: 0, green: 1, blue: 0).extendedSRGB
        #expect(!green.isInSRGBGamut)
        #expect(near(green.green, 1.018, 0.01) && near(green.red, -0.5116, 0.01))
        let roundTrip = ColorSpaces.srgb(from: RGBA(hex: "#3366CC")!.displayP3)
        #expect(near(roundTrip.red, 0.2, 1e-4) && near(roundTrip.blue, 0.8, 1e-4))
    }

    @Test func gamutDetectionAndMapping() {
        #expect(RGBA(hex: "#FF0000")!.isInSRGBGamut)
        let vivid = OKLCH(lightness: 0.7, chroma: 0.35, hue: 150)
        #expect(!vivid.isInSRGBGamut)
        let mapped = vivid.gamutMappedRGBA
        #expect(mapped.isInSRGBGamut)
        #expect(near(mapped.oklch.hue, 150, 3))
    }

    @Test func cssStrings() {
        #expect(RGBA(red: 1, green: 0, blue: 0).oklchString == "oklch(62.8% 0.258 29.23)")
        #expect(RGBA(red: 1, green: 0, blue: 0).displayP3String == "color(display-p3 0.9175 0.2003 0.1386)")
    }
}

@Suite struct APCATests {
    @Test func publishedReferencePairs() {
        // Reference outputs of apca-w3 0.0.98G-4g.
        #expect(abs(APCA.contrast(text: .black, background: .white) - 106.04) < 0.1)
        #expect(abs(APCA.contrast(text: .white, background: .black) - -107.88) < 0.1)
        #expect(abs(APCA.contrast(text: RGBA(hex: "#888888")!, background: .white) - 63.06) < 0.1)
        #expect(abs(APCA.contrast(text: RGBA(hex: "#aaaaaa")!, background: .white) - 45.0) < 1.5)
        #expect(APCA.contrast(text: .white, background: .white) == 0)
    }

    @Test func bands() {
        #expect(APCA.Band(lc: -108) == .fluent)
        #expect(APCA.Band(lc: 63) == .content)
        #expect(APCA.Band(lc: 10) == .fail)
    }

    @Test func suggestFixReachesAA() {
        let bg = RGBA.white
        let fg = RGBA(hex: "#9AA0F0")!
        #expect(fg.contrastRatio(against: bg) < 4.5)
        let fixed = ColorMath.suggestForeground(fg, on: bg)
        #expect(fixed != nil)
        #expect(fixed!.contrastRatio(against: bg) >= 4.5)
        // Hue is preserved approximately.
        #expect(abs(fixed!.oklch.hue - fg.oklch.hue) < 8)
        #expect(ColorMath.suggestForeground(.black, on: bg) == nil)
        // Dark background moves toward light.
        let onDark = ColorMath.suggestForeground(RGBA(hex: "#333366")!, on: RGBA(hex: "#111111")!)
        #expect(onDark != nil && onDark!.relativeLuminance > 0.1)
    }
}

@Suite struct WideGamutExportTests {
    private func swatch(_ rgba: RGBA) -> ExportSwatch { ExportSwatch(name: "Vivid", rgba: rgba) }

    @Test func cssAddsOKLCHAndP3ForWideColors() {
        let wide = DisplayP3(red: 0, green: 1, blue: 0).extendedSRGB
        let text = String(decoding: ExportEncoders.css(title: "T", prefix: nil, swatches: [swatch(wide)]), as: UTF8.self)
        #expect(text.contains("--vivid-oklch: oklch("))
        #expect(text.contains("--vivid-p3: color(display-p3 0.0000 1.0000 0.0000)"))
        let plain = String(decoding: ExportEncoders.css(title: "T", prefix: nil, swatches: [swatch(RGBA(hex: "#336699")!)]), as: UTF8.self)
        #expect(plain.contains("--vivid-oklch: oklch("))
        #expect(!plain.contains("-p3:"))
    }

    @Test func swiftUIUsesDisplayP3OnlyWhenOutsideSRGB() {
        let wide = DisplayP3(red: 0, green: 1, blue: 0).extendedSRGB
        let text = String(decoding: ExportEncoders.swiftUI(title: "T", prefix: nil, swatches: [swatch(wide)]), as: UTF8.self)
        #expect(text.contains(".displayP3,"))
        let plain = String(decoding: ExportEncoders.swiftUI(title: "T", prefix: nil, swatches: [swatch(RGBA(hex: "#336699")!)]), as: UTF8.self)
        #expect(!plain.contains(".displayP3"))
    }
}
