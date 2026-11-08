//
//  WebPaletteScanner.swift
//  OpaliteCore
//
//  Pure text scanning for website palette extraction: normalizing what the user typed into
//  a URL, finding the theme-color meta and same-host stylesheets in HTML, and counting the
//  color values (hex, rgb(), hsl()) declared in HTML and CSS. No networking lives here.
//

import Foundation

nonisolated public enum WebPaletteScanner {
    /// Declared colors with no hue (white, black, greys) count for this much of a colorful one:
    /// nearly every site declares them, and they would otherwise crowd out the brand colors.
    public static let neutralWeight = 0.2
    /// How many times a `theme-color` meta counts: the site's own statement of its brand color.
    public static let themeColorWeight = 25.0
    /// Declared custom properties (`--brand: #…`) count a little more than a one-off value.
    public static let customPropertyWeight = 2.0
    public static let maxStylesheets = 6

    // MARK: - URL

    /// A web URL from free text: adds `https://` when no scheme is typed, accepts only http(s)
    /// with a host, and strips whitespace. Nil when the text cannot be a website.
    public static func normalizedURL(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".") || host == "localhost"
        else { return nil }
        return url
    }

    /// The host without a leading `www.`, used to name the palette.
    public static func displayHost(of url: URL) -> String {
        let host = url.host ?? url.absoluteString
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // MARK: - HTML

    /// The `theme-color` meta values (a page may declare light and dark variants).
    public static func themeColors(inHTML html: String) -> [RGBA] {
        var results: [RGBA] = []
        for tag in matches(#"<meta\b[^>]*>"#, in: html) where tag.range(of: #"name\s*=\s*["']?theme-color"#, options: [.regularExpression, .caseInsensitive]) != nil {
            if let content = firstCapture(#"content\s*=\s*["']([^"']+)["']"#, in: tag), let color = parseColor(content) {
                results.append(color)
            }
        }
        return results
    }

    /// Absolute URLs of linked stylesheets on the same host as `base`, in document order.
    public static func stylesheetURLs(inHTML html: String, base: URL) -> [URL] {
        var urls: [URL] = []
        for tag in matches(#"<link\b[^>]*>"#, in: html) where tag.range(of: #"rel\s*=\s*["']?[^"'>]*stylesheet"#, options: [.regularExpression, .caseInsensitive]) != nil {
            guard let href = firstCapture(#"href\s*=\s*["']([^"']+)["']"#, in: tag),
                  let url = URL(string: href.replacingOccurrences(of: "&amp;", with: "&"), relativeTo: base)?.absoluteURL,
                  let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  url.host?.lowercased() == base.host?.lowercased(),
                  !urls.contains(url)
            else { continue }
            urls.append(url)
            if urls.count == maxStylesheets { break }
        }
        return urls
    }

    // MARK: - Counting

    /// Every color value in `text` (CSS, a `style` attribute, an HTML document) by frequency,
    /// as weighted samples. Custom-property declarations count extra; neutrals count less.
    public static func declaredColors(in text: String) -> [WeightedColor] {
        var counts: [RGBA: Double] = [:]
        func add(_ color: RGBA, _ times: Double) { counts[color, default: 0] += times }

        for token in matches(colorPattern, in: text) {
            if let color = parseColor(token) { add(color, 1) }
        }
        // Custom properties: `--name: <color>` gets a bonus on top of its plain occurrence.
        for declaration in matches(#"--[\w-]+\s*:\s*[^;}\n]+"#, in: text) {
            if let value = declaration.split(separator: ":", maxSplits: 1).last,
               let token = matches(colorPattern, in: String(value)).first, let color = parseColor(token) {
                add(color, customPropertyWeight - 1)
            }
        }
        return counts
            .sorted { ($0.key.hexString, $0.value) < ($1.key.hexString, $1.value) }
            .map { WeightedColor($0.key, weight: $0.value * (isNeutral($0.key) ? neutralWeight : 1)) }
    }

    /// Samples for a page: theme colors (weighted heavily) plus everything declared in the
    /// HTML and each stylesheet.
    public static func samples(html: String, stylesheets: [String]) -> PaletteSamples {
        var all: [WeightedColor] = themeColors(inHTML: html).map { WeightedColor($0, weight: themeColorWeight) }
        all += declaredColors(in: html)
        for css in stylesheets { all += declaredColors(in: css) }
        return PaletteSamples(all)
    }

    static func isNeutral(_ color: RGBA) -> Bool {
        ColorSpaces.oklch(from: ColorSpaces.oklab(from: color)).chroma < 0.03
    }

    // MARK: - Parsing

    private static let colorPattern = #"#[0-9a-fA-F]{8}\b|#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3,4}\b|rgba?\(\s*[^)]*\)|hsla?\(\s*[^)]*\)"#

    /// A CSS color value: #rgb, #rgba, #rrggbb, #rrggbbaa, rgb()/rgba(), hsl()/hsla() in the
    /// comma or space syntax. Nil for anything else (named colors, var(), etc.).
    public static func parseColor(_ text: String) -> RGBA? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("#") { return RGBA(hex: value) }
        guard let open = value.firstIndex(of: "("), let close = value.lastIndex(of: ")"), open < close else { return nil }
        let name = String(value[..<open])
        let body = value[value.index(after: open)..<close]
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ",", with: " ")
        let parts = body.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 3 || parts.count == 4 else { return nil }
        let alpha = parts.count == 4 ? component(parts[3], scale: 1) : 1
        guard let alpha else { return nil }

        switch name {
        case "rgb", "rgba":
            guard let r = component(parts[0], scale: 255), let g = component(parts[1], scale: 255), let b = component(parts[2], scale: 255) else { return nil }
            return RGBA(red: r, green: g, blue: b, alpha: alpha)
        case "hsl", "hsla":
            guard let hue = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
                  let s = component(parts[1], scale: 1), let l = component(parts[2], scale: 1) else { return nil }
            let hsl = HSL(hue: hue.truncatingRemainder(dividingBy: 360) + (hue < 0 ? 360 : 0), saturation: s, lightness: l)
            var color = hsl.rgba
            color.alpha = alpha
            return color
        default:
            return nil
        }
    }

    /// A number or percentage as 0...1 (numbers divided by `scale`).
    private static func component(_ text: String, scale: Double) -> Double? {
        if text.hasSuffix("%") {
            guard let percent = Double(text.dropLast()) else { return nil }
            return min(max(percent / 100, 0), 1)
        }
        guard let number = Double(text) else { return nil }
        return min(max(number / scale, 0), 1)
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
