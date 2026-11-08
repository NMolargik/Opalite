import Foundation
import Testing
@testable import OpaliteCore

@Suite struct PaletteExtractorTests {
    /// A synthetic "image": flat bands of colors with the given pixel counts, plus mild noise.
    private func bands(_ spec: [(String, Int)], noise: Bool = true) -> PaletteSamples {
        var bytes: [UInt8] = []
        var tick = 0
        for (hex, count) in spec {
            let c = RGBA(hex: hex)!
            for _ in 0..<count {
                let jitter = noise ? Double((tick % 5) - 2) / 255 : 0
                tick += 1
                bytes += [UInt8(max(0, min(255, (c.red + jitter) * 255))), UInt8(max(0, min(255, (c.green + jitter) * 255))), UInt8(max(0, min(255, (c.blue + jitter) * 255))), 255]
            }
        }
        return PaletteSamples(rgba8: bytes)
    }

    private func closeTo(_ a: RGBA, _ hex: String, tolerance: Double = 0.08) -> Bool {
        let b = RGBA(hex: hex)!
        return ColorSpaces.oklab(from: a).distance(to: ColorSpaces.oklab(from: b)) < tolerance
    }

    @Test func findsTheDistinctBands() {
        let samples = bands([("#E63946", 400), ("#1D3557", 300), ("#F1FAEE", 200), ("#A8DADC", 100)])
        let palette = samples.palette(count: 4)
        #expect(palette.count == 4)
        for hex in ["#E63946", "#1D3557", "#F1FAEE", "#A8DADC"] {
            #expect(palette.contains { closeTo($0.rgba, hex) }, "missing \(hex)")
        }
    }

    @Test func ordersByLightnessByDefault() {
        let palette = bands([("#F1FAEE", 200), ("#1D3557", 300), ("#E63946", 400)]).palette(count: 3)
        let lightness = palette.map { ColorSpaces.oklab(from: $0.rgba).lightness }
        #expect(lightness == lightness.sorted())
    }

    @Test func canOrderByProminence() {
        let palette = bands([("#F1FAEE", 100), ("#1D3557", 300), ("#E63946", 600)]).palette(count: 3, ordering: .prominence)
        #expect(closeTo(palette[0].rgba, "#E63946"))
        #expect(palette[0].prominence > palette[1].prominence)
        #expect(abs(palette.reduce(0) { $0 + $1.prominence } - 1) < 1e-9)
    }

    @Test func isDeterministic() {
        let samples = bands([("#E63946", 400), ("#1D3557", 300), ("#F1FAEE", 200), ("#A8DADC", 100), ("#2A9D8F", 150), ("#E9C46A", 90)])
        let first = samples.palette(count: 6)
        for _ in 0..<5 { #expect(samples.palette(count: 6) == first) }
    }

    @Test func skipsNearDuplicates() {
        // Two almost identical blues and one red: asking for 5 can only yield 2.
        let palette = bands([("#2040C0", 400), ("#2242C0", 400), ("#C02020", 300)], noise: false).palette(count: 5)
        #expect(palette.count == 2)
        let separation = PaletteExtractor.minimumSeparation
        for (i, a) in palette.enumerated() {
            for b in palette.dropFirst(i + 1) {
                #expect(ColorSpaces.oklab(from: a.rgba).distance(to: ColorSpaces.oklab(from: b.rgba)) >= separation)
            }
        }
    }

    @Test func clampsCountToThreeThroughEight() {
        let spec: [(String, Int)] = ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF", "#00FFFF", "#000000", "#FFFFFF", "#808080", "#FF8800"].map { ($0, 100) }
        let samples = bands(spec, noise: false)
        #expect(samples.palette(count: 20).count == 8)
        #expect(samples.palette(count: 1).count == 3)
        #expect(samples.palette(count: 5).count == 5)
    }

    @Test func solidImageYieldsOneColor() {
        let palette = bands([("#336699", 500)], noise: false).palette(count: 5)
        #expect(palette.count == 1)
        #expect(palette[0].rgba.hexString == "#336699")
    }

    @Test func emptyAndTransparentYieldNothing() {
        #expect(PaletteSamples().palette().isEmpty)
        #expect(PaletteSamples(rgba8: [255, 0, 0, 0, 0, 255, 0, 10]).palette().isEmpty)
    }

    @Test func tinySpecksAreNotPromoted() {
        // 1 pixel in 2000 is noise when two real colors exist and the minimum is satisfiable by them... but the floor is three.
        let palette = bands([("#E63946", 1000), ("#1D3557", 1000), ("#00FF00", 3)], noise: false).palette(count: 3)
        #expect(palette.count == 3)
        #expect(palette.map(\.prominence).min()! < 0.01)
        // With real variety available, specks below 1% are dropped.
        let four = bands([("#E63946", 1000), ("#1D3557", 1000), ("#2A9D8F", 500), ("#E9C46A", 500), ("#00FF00", 3)], noise: false).palette(count: 8)
        #expect(four.count == 4)
    }

    @Test func blendingWeightsSources() {
        let a = bands([("#E63946", 10)], noise: false)
        let b = bands([("#1D3557", 10)], noise: false)
        let palette = PaletteSamples.blend([(a, 0.8), (b, 0.2)]).palette(count: 3, ordering: .prominence)
        #expect(palette.count == 2)
        #expect(closeTo(palette[0].rgba, "#E63946"))
        #expect(abs(palette[0].prominence - 0.8) < 1e-6)
    }

    @Test func largeInputIsHandled() {
        // 200k pixels of smooth gradient noise stay fast and bounded.
        var bytes: [UInt8] = []
        bytes.reserveCapacity(800_000)
        for i in 0..<200_000 { bytes += [UInt8(i % 256), UInt8((i / 7) % 256), UInt8((i / 31) % 256), 255] }
        let palette = PaletteSamples(rgba8: bytes).palette(count: 8)
        #expect((3...8).contains(palette.count))
    }
}

private extension OKLab {
    func distance(to other: OKLab) -> Double { PaletteExtractor.distance(self, other) }
}

@Suite struct WebPaletteScannerTests {
    @Test func normalizesTypedURLs() {
        #expect(WebPaletteScanner.normalizedURL(from: "apple.com")?.absoluteString == "https://apple.com")
        #expect(WebPaletteScanner.normalizedURL(from: "  http://example.org/a ")?.absoluteString == "http://example.org/a")
        #expect(WebPaletteScanner.normalizedURL(from: "ftp://example.com") == nil)
        #expect(WebPaletteScanner.normalizedURL(from: "not a url") == nil)
        #expect(WebPaletteScanner.normalizedURL(from: "") == nil)
        #expect(WebPaletteScanner.normalizedURL(from: "javascript:alert(1)") == nil)
        #expect(WebPaletteScanner.displayHost(of: URL(string: "https://www.example.com/x")!) == "example.com")
    }

    @Test func parsesCSSColors() {
        #expect(WebPaletteScanner.parseColor("#ff8800")?.hexString == "#FF8800")
        #expect(WebPaletteScanner.parseColor("#f80")?.hexString == "#FF8800")
        #expect(WebPaletteScanner.parseColor("rgb(255, 136, 0)")?.hexString == "#FF8800")
        #expect(WebPaletteScanner.parseColor("rgb(255 136 0 / 50%)")?.alpha == 0.5)
        #expect(WebPaletteScanner.parseColor("rgba(0,0,0,.25)")?.alpha == 0.25)
        #expect(WebPaletteScanner.parseColor("hsl(120, 100%, 50%)")?.hexString == "#00FF00")
        #expect(WebPaletteScanner.parseColor("hsl(240deg 100% 50%)")?.hexString == "#0000FF")
        #expect(WebPaletteScanner.parseColor("var(--x)") == nil)
        #expect(WebPaletteScanner.parseColor("rebeccapurple") == nil)
    }

    @Test func findsThemeColorAndStylesheets() {
        let html = """
        <html><head>
        <meta name="viewport" content="width=device-width">
        <meta content="#112233" name="theme-color">
        <meta name='theme-color' content='rgb(10, 20, 30)' media='(prefers-color-scheme: dark)'>
        <link rel="stylesheet" href="/a.css">
        <link href="b.css?x=1&amp;y=2" rel="stylesheet">
        <link rel="stylesheet" href="https://cdn.other.com/c.css">
        <link rel="icon" href="/favicon.ico">
        </head></html>
        """
        #expect(WebPaletteScanner.themeColors(inHTML: html).map(\.hexString) == ["#112233", "#0A141E"])
        let base = URL(string: "https://example.com/site/")!
        #expect(WebPaletteScanner.stylesheetURLs(inHTML: html, base: base).map(\.absoluteString)
            == ["https://example.com/a.css", "https://example.com/site/b.css?x=1&y=2"])
    }

    @Test func countsDeclaredColorsByFrequency() {
        let css = """
        :root { --brand: #e63946; --muted: #cccccc; }
        a { color: #E63946; } b { background: rgb(29, 53, 87); } i { color: #fff; border-color: #fff; }
        """
        let samples = WebPaletteScanner.declaredColors(in: css)
        func weight(_ hex: String) -> Double { samples.first { $0.rgba.hexString == hex }?.weight ?? 0 }
        // brand: 1 (var) + 1 (a) + custom bonus; far above the lone navy.
        #expect(weight("#E63946") == 1 + 1 + (WebPaletteScanner.customPropertyWeight - 1))
        #expect(weight("#1D3557") == 1)
        // Neutrals are discounted.
        #expect(weight("#FFFFFF") == 2 * WebPaletteScanner.neutralWeight)
    }

    @Test func themeColorDominatesTheResult() {
        let html = ##"<meta name="theme-color" content="#0A84FF"><div style="color:#00ff00;background:#ff0000"></div>"##
        let palette = WebPaletteScanner.samples(html: html, stylesheets: []).palette(count: 3, ordering: .prominence)
        #expect(palette.first?.rgba.hexString == "#0A84FF")
        #expect(palette.count == 3)
    }
}

@Suite struct PaletteSamplesTests {
    @Test func discountingNeutralsShrinksOnlyGreys() {
        let samples = PaletteSamples([
            WeightedColor(RGBA(hex: "#FFFFFF")!, weight: 10),
            WeightedColor(RGBA(hex: "#E63946")!, weight: 10),
        ]).discountingNeutrals(to: 0.1)
        let byHex = Dictionary(uniqueKeysWithValues: samples.samples.map { ($0.rgba.hexString, $0.weight) })
        #expect(abs((byHex["#FFFFFF"] ?? 0) - 1) < 1e-9)
        #expect(byHex["#E63946"] == 10)
    }
}
