//
//  WebsitePaletteService.swift
//  OpaliteServices
//
//  Palette extraction sources that touch the system: downsampling a `CGImage` into samples,
//  and reading a website the user typed. The website path fetches only that page and up to
//  six stylesheets on the same host, then (iOS and visionOS) renders the page in an
//  offscreen web view for a snapshot. Declared colors and the snapshot are blended into one
//  `PaletteSamples`. Nothing else is requested by Opalite itself; the web view loads the page's
//  own resources, exactly as opening it would.
//

import Foundation
import CoreGraphics
import OpaliteCore
import os

// MARK: - Images

nonisolated public enum ImagePaletteSampler {
    /// Samples from an image, scaled so its longest side is `maxDimension` (palettes need
    /// the broad areas of color, not detail). Output is sRGB regardless of the source space.
    public static func samples(from image: CGImage, maxDimension: Int = 96) -> PaletteSamples {
        let longest = max(image.width, image.height)
        guard longest > 0 else { return PaletteSamples() }
        let scale = min(1, Double(maxDimension) / Double(longest))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return PaletteSamples() }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return PaletteSamples() }

        // Un-premultiply so translucent edges keep their true color.
        var index = 0
        while index + 3 < pixels.count {
            let alpha = Int(pixels[index + 3])
            if alpha > 0, alpha < 255 {
                for channel in 0..<3 { pixels[index + channel] = UInt8(min(255, Int(pixels[index + channel]) * 255 / alpha)) }
            }
            index += 4
        }
        return PaletteSamples(rgba8: pixels)
    }
}

// MARK: - Websites

nonisolated public enum WebsitePaletteError: LocalizedError, Equatable {
    case invalidURL
    case offline
    case timedOut
    case unreachable
    case badStatus(Int)
    case notAWebPage
    case noColors

    public var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "That doesn't look like a website address. Try something like example.com.")
        case .offline: String(localized: "You appear to be offline. Connect to the internet and try again.")
        case .timedOut: String(localized: "The website took too long to respond. Check the address and try again.")
        case .unreachable: String(localized: "Opalite couldn't reach that website. Check the address and try again.")
        case .badStatus(let code): String(localized: "The website returned an error (\(String(code))).")
        case .notAWebPage: String(localized: "That address didn't return a web page.")
        case .noColors: String(localized: "No colors could be found on that page.")
        }
    }
}

nonisolated public struct WebsitePaletteResult: Sendable {
    /// The page's final URL after redirects.
    public let url: URL
    public let samples: PaletteSamples
    /// Whether a rendered snapshot contributed alongside the declared colors.
    public let usedSnapshot: Bool
    public var host: String { WebPaletteScanner.displayHost(of: url) }
}

nonisolated public struct WebsitePaletteService: Sendable {
    public typealias Fetch = @Sendable (URL) async throws -> (Data, HTTPURLResponse)
    public typealias Snapshot = @Sendable (URL) async -> CGImage?

    /// Largest page or stylesheet read; the rest is ignored.
    static let maxBytes = 1_500_000
    /// Share of the blend taken by declared colors when a snapshot is also available.
    static let declaredShare = 0.6

    private let fetch: Fetch
    private let snapshot: Snapshot

    public init(timeout: TimeInterval = 12) {
        self.init(fetch: Self.urlSessionFetch(timeout: timeout), snapshot: { url in
            #if os(iOS) || os(visionOS)
            await WebSnapshotter.snapshot(of: url, timeout: timeout)
            #else
            nil
            #endif
        })
    }

    /// Injectable seams for tests.
    public init(fetch: @escaping Fetch, snapshot: @escaping Snapshot) {
        self.fetch = fetch
        self.snapshot = snapshot
    }

    public func extract(from input: String) async throws -> WebsitePaletteResult {
        guard let typed = WebPaletteScanner.normalizedURL(from: input) else { throw WebsitePaletteError.invalidURL }

        let (data, response) = try await fetchMapped(typed)
        guard (200..<300).contains(response.statusCode) else { throw WebsitePaletteError.badStatus(response.statusCode) }
        let finalURL = response.url ?? typed
        let type = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard type.isEmpty || type.contains("html") || type.contains("xml") else { throw WebsitePaletteError.notAWebPage }
        let html = String(decoding: data, as: UTF8.self)

        // Stylesheets are best effort: a missing one never fails the page.
        var sheets: [String] = []
        for sheetURL in WebPaletteScanner.stylesheetURLs(inHTML: html, base: finalURL) {
            if let (css, sheetResponse) = try? await fetch(sheetURL), (200..<300).contains(sheetResponse.statusCode) {
                sheets.append(String(decoding: css.prefix(Self.maxBytes), as: UTF8.self))
            }
        }
        let declared = WebPaletteScanner.samples(html: html, stylesheets: sheets)

        var snapshotSamples = PaletteSamples()
        if let image = await snapshot(finalURL) {
            snapshotSamples = ImagePaletteSampler.samples(from: image).discountingNeutrals(to: 0.35)
        }

        let usedSnapshot = !snapshotSamples.isEmpty
        let blended: PaletteSamples
        switch (declared.isEmpty, usedSnapshot) {
        case (false, true): blended = .blend([(declared, Self.declaredShare), (snapshotSamples, 1 - Self.declaredShare)])
        case (false, false): blended = declared
        case (true, true): blended = snapshotSamples
        case (true, false): throw WebsitePaletteError.noColors
        }
        return WebsitePaletteResult(url: finalURL, samples: blended, usedSnapshot: usedSnapshot)
    }

    private func fetchMapped(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await fetch(url)
        } catch let error as WebsitePaletteError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw WebsitePaletteError.timedOut
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff: throw WebsitePaletteError.offline
            default: throw WebsitePaletteError.unreachable
            }
        } catch {
            throw WebsitePaletteError.unreachable
        }
    }

    private static func urlSessionFetch(timeout: TimeInterval) -> Fetch {
        { url in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout * 2
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            let session = URLSession(configuration: configuration)
            defer { session.finishTasksAndInvalidate() }
            var request = URLRequest(url: url)
            request.setValue("text/html,text/css,*/*;q=0.8", forHTTPHeaderField: "Accept")
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw WebsitePaletteError.notAWebPage }
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count >= maxBytes { break }
            }
            return (data, http)
        }
    }
}
