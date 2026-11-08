//
//  PaletteSourcesTests.swift
//  OpaliteServicesTests
//
//  Image downsampling and the website pipeline, driven through injected fetch/snapshot seams
//  so no test touches the network.
//

import Foundation
import CoreGraphics
import Testing
import OpaliteCore
@testable import OpaliteServices

@Suite("Palette sources")
struct PaletteSourcesTests {
    private func image(bands: [(UInt8, UInt8, UInt8)], size: Int = 120) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let bandHeight = size / bands.count
        for (index, band) in bands.enumerated() {
            context.setFillColor(red: CGFloat(band.0) / 255, green: CGFloat(band.1) / 255, blue: CGFloat(band.2) / 255, alpha: 1)
            context.fill(CGRect(x: 0, y: index * bandHeight, width: size, height: bandHeight))
        }
        return context.makeImage()!
    }

    @Test func extractsBandsFromAnImage() {
        let palette = ImagePaletteSampler.samples(from: image(bands: [(230, 57, 70), (29, 53, 87), (241, 250, 238), (42, 157, 143)])).palette(count: 4)
        #expect(palette.count == 4)
        let hexes = Set(palette.map(\.rgba.hexString))
        #expect(hexes.contains("#E63946") && hexes.contains("#1D3557") && hexes.contains("#2A9D8F"))
    }

    private nonisolated static func http(_ url: String, status: Int = 200, type: String = "text/html") -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: url)!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": type])!
    }

    private nonisolated static let page = """
    <html><head><meta name="theme-color" content="#0A84FF"><link rel="stylesheet" href="/s.css"></head>
    <body style="background:#ffffff"><p style="color:#E63946">Hi</p></body></html>
    """

    @Test func combinesPageAndStylesheetColors() async throws {
        let service = WebsitePaletteService(
            fetch: { url in
                if url.path == "/s.css" { return (Data(":root{--accent:#2A9D8F}".utf8), Self.http(url.absoluteString, type: "text/css")) }
                return (Data(Self.page.utf8), Self.http("https://www.example.com/"))
            },
            snapshot: { _ in nil }
        )
        let result = try await service.extract(from: "example.com")
        #expect(result.host == "example.com")
        #expect(!result.usedSnapshot)
        let hexes = Set(result.samples.palette(count: 5).map(\.rgba.hexString))
        #expect(hexes.isSuperset(of: ["#0A84FF", "#E63946", "#2A9D8F"]))
    }

    @Test func blendsASnapshotWhenAvailable() async throws {
        let snapshot = image(bands: [(255, 128, 0), (255, 128, 0)])
        let service = WebsitePaletteService(
            fetch: { url in (Data(Self.page.utf8), Self.http(url.absoluteString)) },
            snapshot: { _ in snapshot }
        )
        let result = try await service.extract(from: "https://example.com")
        #expect(result.usedSnapshot)
        #expect(result.samples.palette(count: 5).contains { $0.rgba.hexString == "#FF8000" })
    }

    @Test func mapsFailuresToClearErrors() async {
        func run(_ error: Error) async -> WebsitePaletteError? {
            let service = WebsitePaletteService(fetch: { _ in throw error }, snapshot: { _ in nil })
            do { _ = try await service.extract(from: "example.com"); return nil } catch { return error as? WebsitePaletteError }
        }
        #expect(await run(URLError(.timedOut)) == .timedOut)
        #expect(await run(URLError(.notConnectedToInternet)) == .offline)
        #expect(await run(URLError(.cannotFindHost)) == .unreachable)

        let invalid = WebsitePaletteService(fetch: { _ in throw URLError(.badURL) }, snapshot: { _ in nil })
        await #expect(throws: WebsitePaletteError.invalidURL) { _ = try await invalid.extract(from: "not a url") }

        let missing = WebsitePaletteService(fetch: { url in (Data(), Self.http(url.absoluteString, status: 404)) }, snapshot: { _ in nil })
        await #expect(throws: WebsitePaletteError.badStatus(404)) { _ = try await missing.extract(from: "example.com") }

        let json = WebsitePaletteService(fetch: { url in (Data("{}".utf8), Self.http(url.absoluteString, type: "application/json")) }, snapshot: { _ in nil })
        await #expect(throws: WebsitePaletteError.notAWebPage) { _ = try await json.extract(from: "example.com") }

        let bare = WebsitePaletteService(fetch: { url in (Data("<html></html>".utf8), Self.http(url.absoluteString)) }, snapshot: { _ in nil })
        await #expect(throws: WebsitePaletteError.noColors) { _ = try await bare.extract(from: "example.com") }
    }

    @Test func errorsHaveMessages() {
        for error in [WebsitePaletteError.invalidURL, .offline, .timedOut, .unreachable, .badStatus(500), .notAWebPage, .noColors] {
            #expect(error.errorDescription?.isEmpty == false)
            #expect(error.errorDescription?.contains("\u{2014}") == false)
        }
    }

    @Test func stylesheetsAreRequestedOnlyFromTheSameHost() async throws {
        let html = #"<link rel="stylesheet" href="https://cdn.evil.com/x.css"><link rel="stylesheet" href="/ok.css"><p style="color:#112233">x</p>"#
        let requested = Requested()
        let service = WebsitePaletteService(
            fetch: { url in await requested.add(url); return (Data(html.utf8), Self.http(url.absoluteString)) },
            snapshot: { _ in nil }
        )
        _ = try await service.extract(from: "https://example.com/")
        let hosts = Set(await requested.urls.compactMap(\.host))
        #expect(hosts == ["example.com"])
    }
}

private actor Requested {
    var urls: [URL] = []
    func add(_ url: URL) { urls.append(url) }
}
