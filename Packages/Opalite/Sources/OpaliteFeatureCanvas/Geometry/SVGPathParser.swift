//
//  SVGPathParser.swift
//  OpaliteFeatureCanvas
//
//  Turns an SVG document into CGPaths: `<path d="…">` (M/L/H/V/C/S/Q/T/A/Z and relative
//  forms) plus the basic shapes (rect, circle, ellipse, line, polyline, polygon). Pure
//  CoreGraphics, so it runs — and is tested — on the host.
//

import Foundation
import CoreGraphics

nonisolated struct SVGPathParser {

    struct ParseResult {
        /// The extracted paths in SVG user units.
        let paths: [CGPath]
        /// The viewBox, or the union of the path bounds when the SVG has none.
        let bounds: CGRect
        /// Non-fatal problems (unparseable path data).
        let warnings: [String]
    }

    init() {}

    func parse(from url: URL) throws -> ParseResult {
        try parse(from: Data(contentsOf: url))
    }

    func parse(from data: Data) throws -> ParseResult {
        guard let string = String(data: data, encoding: .utf8) else { throw SVGParseError.invalidData }
        return try parse(from: string)
    }

    func parse(from svg: String) throws -> ParseResult {
        var paths: [CGPath] = []
        var warnings: [String] = []

        for pathData in attributeValues(named: "d", onElement: "path", in: svg) {
            if let path = parsePathData(pathData) {
                paths.append(path)
            } else {
                warnings.append("Unparseable path data: \(pathData.prefix(40))")
            }
        }

        paths.append(contentsOf: rectPaths(in: svg))
        paths.append(contentsOf: circlePaths(in: svg))
        paths.append(contentsOf: ellipsePaths(in: svg))
        paths.append(contentsOf: linePaths(in: svg))
        paths.append(contentsOf: pointsPaths(element: "polyline", close: false, in: svg))
        paths.append(contentsOf: pointsPaths(element: "polygon", close: true, in: svg))

        guard !paths.isEmpty else { throw SVGParseError.noPathsFound }
        return ParseResult(paths: paths, bounds: viewBox(in: svg) ?? unionBounds(of: paths), warnings: warnings)
    }

    // MARK: - Path data

    /// Parses one `d` attribute into a path, or nil when nothing drawable results.
    func parsePathData(_ data: String) -> CGPath? {
        let path = CGMutablePath()
        let tokens = tokenize(data)
        var index = 0
        var command: Character = "M"
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?

        while index < tokens.count {
            let token = tokens[index]
            if token.count == 1, let character = token.first, character.isLetter {
                command = character
                index += 1
                if command == "Z" || command == "z" {
                    path.closeSubpath()
                    current = subpathStart
                    lastControl = nil
                }
                continue
            }

            let isRelative = command.isLowercase
            func absolute(_ point: CGPoint) -> CGPoint {
                isRelative ? CGPoint(x: current.x + point.x, y: current.y + point.y) : point
            }

            switch command.uppercased().first! {
            case "M":
                guard let point = parsePoint(tokens, at: &index) else { index += 1; continue }
                current = absolute(point)
                subpathStart = current
                path.move(to: current)
                command = isRelative ? "l" : "L"
            case "L":
                guard let point = parsePoint(tokens, at: &index) else { index += 1; continue }
                current = absolute(point)
                path.addLine(to: current)
            case "H":
                guard let x = parseNumber(tokens, at: &index) else { index += 1; continue }
                current = CGPoint(x: isRelative ? current.x + x : x, y: current.y)
                path.addLine(to: current)
            case "V":
                guard let y = parseNumber(tokens, at: &index) else { index += 1; continue }
                current = CGPoint(x: current.x, y: isRelative ? current.y + y : y)
                path.addLine(to: current)
            case "C":
                guard let c1 = parsePoint(tokens, at: &index), let c2 = parsePoint(tokens, at: &index), let end = parsePoint(tokens, at: &index) else { index += 1; continue }
                let control1 = absolute(c1), control2 = absolute(c2), target = absolute(end)
                path.addCurve(to: target, control1: control1, control2: control2)
                lastControl = control2
                current = target
            case "S":
                guard let c2 = parsePoint(tokens, at: &index), let end = parsePoint(tokens, at: &index) else { index += 1; continue }
                let control1 = reflect(lastControl, around: current)
                let control2 = absolute(c2), target = absolute(end)
                path.addCurve(to: target, control1: control1, control2: control2)
                lastControl = control2
                current = target
            case "Q":
                guard let c = parsePoint(tokens, at: &index), let end = parsePoint(tokens, at: &index) else { index += 1; continue }
                let control = absolute(c), target = absolute(end)
                path.addQuadCurve(to: target, control: control)
                lastControl = control
                current = target
            case "T":
                guard let end = parsePoint(tokens, at: &index) else { index += 1; continue }
                let control = reflect(lastControl, around: current)
                let target = absolute(end)
                path.addQuadCurve(to: target, control: control)
                lastControl = control
                current = target
            case "A":
                guard let rx = parseNumber(tokens, at: &index), let ry = parseNumber(tokens, at: &index),
                      let rotation = parseNumber(tokens, at: &index), let largeArc = parseNumber(tokens, at: &index),
                      let sweep = parseNumber(tokens, at: &index), let end = parsePoint(tokens, at: &index) else { index += 1; continue }
                let target = absolute(end)
                SVGArc.add(to: path, from: current, to: target, rx: rx, ry: ry, xAxisRotation: rotation, largeArc: largeArc > 0.5, sweep: sweep > 0.5)
                current = target
            default:
                index += 1
            }

            if !"CcSsQqTt".contains(command) { lastControl = nil }
        }

        return path.isEmpty ? nil : path
    }

    // MARK: - Tokens

    private func tokenize(_ data: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        func flush() {
            if !current.isEmpty { tokens.append(current); current = "" }
        }
        for character in data {
            if character.isLetter && character != "e" && character != "E" {
                flush()
                tokens.append(String(character))
            } else if character.isNumber || character == "." || character == "-" || character == "+" || character == "e" || character == "E" {
                if (character == "-" || character == "+"), !current.isEmpty, !current.hasSuffix("e"), !current.hasSuffix("E") {
                    flush()
                }
                if character == ".", current.contains("."), !current.contains("e"), !current.contains("E") {
                    flush()
                }
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return tokens
    }

    private func parseNumber(_ tokens: [String], at index: inout Int) -> CGFloat? {
        guard index < tokens.count, let value = Double(tokens[index]) else { return nil }
        index += 1
        return CGFloat(value)
    }

    private func parsePoint(_ tokens: [String], at index: inout Int) -> CGPoint? {
        let start = index
        guard let x = parseNumber(tokens, at: &index), let y = parseNumber(tokens, at: &index) else {
            index = start
            return nil
        }
        return CGPoint(x: x, y: y)
    }

    private func reflect(_ control: CGPoint?, around point: CGPoint) -> CGPoint {
        guard let control else { return point }
        return CGPoint(x: 2 * point.x - control.x, y: 2 * point.y - control.y)
    }

    // MARK: - Elements

    private func viewBox(in svg: String) -> CGRect? {
        guard let value = firstAttribute("viewBox", in: svg) else { return nil }
        let numbers = value.replacingOccurrences(of: ",", with: " ").split(separator: " ").compactMap { Double($0) }
        guard numbers.count == 4, numbers[2] > 0, numbers[3] > 0 else { return nil }
        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    private func elements(named name: String, in svg: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "<\(name)\\b[^>]*>", options: [.dotMatchesLineSeparators]) else { return [] }
        let text = svg as NSString
        return regex.matches(in: svg, range: NSRange(location: 0, length: text.length)).map { text.substring(with: $0.range) }
    }

    private func attributeValues(named attribute: String, onElement element: String, in svg: String) -> [String] {
        elements(named: element, in: svg).compactMap { firstAttribute(attribute, in: $0) }
    }

    private func firstAttribute(_ name: String, in element: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\b\(name)\\s*=\\s*([\"'])(.*?)\\1", options: [.dotMatchesLineSeparators]) else { return nil }
        let text = element as NSString
        guard let match = regex.firstMatch(in: element, range: NSRange(location: 0, length: text.length)), match.numberOfRanges >= 3 else { return nil }
        return text.substring(with: match.range(at: 2))
    }

    private func number(_ name: String, in element: String) -> CGFloat? {
        firstAttribute(name, in: element).flatMap { Double($0.trimmingCharacters(in: .letters)) }.map { CGFloat($0) }
    }

    private func rectPaths(in svg: String) -> [CGPath] {
        elements(named: "rect", in: svg).map { element in
            let rect = CGRect(x: number("x", in: element) ?? 0, y: number("y", in: element) ?? 0, width: number("width", in: element) ?? 0, height: number("height", in: element) ?? 0)
            let rx = number("rx", in: element) ?? 0
            let ry = number("ry", in: element) ?? rx
            let path = CGMutablePath()
            if rx > 0 || ry > 0 {
                path.addRoundedRect(in: rect, cornerWidth: min(rx, rect.width / 2), cornerHeight: min(ry, rect.height / 2))
            } else {
                path.addRect(rect)
            }
            return path
        }
    }

    private func circlePaths(in svg: String) -> [CGPath] {
        elements(named: "circle", in: svg).map { element in
            let cx = number("cx", in: element) ?? 0, cy = number("cy", in: element) ?? 0, r = number("r", in: element) ?? 0
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            return path
        }
    }

    private func ellipsePaths(in svg: String) -> [CGPath] {
        elements(named: "ellipse", in: svg).map { element in
            let cx = number("cx", in: element) ?? 0, cy = number("cy", in: element) ?? 0
            let rx = number("rx", in: element) ?? 0, ry = number("ry", in: element) ?? 0
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
            return path
        }
    }

    private func linePaths(in svg: String) -> [CGPath] {
        elements(named: "line", in: svg).map { element in
            let path = CGMutablePath()
            path.move(to: CGPoint(x: number("x1", in: element) ?? 0, y: number("y1", in: element) ?? 0))
            path.addLine(to: CGPoint(x: number("x2", in: element) ?? 0, y: number("y2", in: element) ?? 0))
            return path
        }
    }

    private func pointsPaths(element: String, close: Bool, in svg: String) -> [CGPath] {
        attributeValues(named: "points", onElement: element, in: svg).compactMap { points in
            let numbers = points.replacingOccurrences(of: ",", with: " ").split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
            guard numbers.count >= 4 else { return nil }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            for i in stride(from: 2, to: numbers.count - 1, by: 2) {
                path.addLine(to: CGPoint(x: numbers[i], y: numbers[i + 1]))
            }
            if close { path.closeSubpath() }
            return path
        }
    }

    private func unionBounds(of paths: [CGPath]) -> CGRect {
        let union = paths.reduce(CGRect.null) { $0.union($1.boundingBoxOfPath) }
        return union.isNull || union.isEmpty ? CGRect(x: 0, y: 0, width: 100, height: 100) : union
    }
}

// MARK: - Arcs

/// SVG elliptical arc → cubic Béziers (SVG implementation notes, section F.6.5).
nonisolated enum SVGArc {
    static func add(to path: CGMutablePath, from start: CGPoint, to end: CGPoint, rx: CGFloat, ry: CGFloat, xAxisRotation: CGFloat, largeArc: Bool, sweep: Bool) {
        guard rx != 0, ry != 0, start != end else {
            path.addLine(to: end)
            return
        }
        let phi = xAxisRotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (start.x - end.x) / 2, dy = (start.y - end.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        var rxAbs = abs(rx), ryAbs = abs(ry)
        let lambda = (x1p * x1p) / (rxAbs * rxAbs) + (y1p * y1p) / (ryAbs * ryAbs)
        if lambda > 1 {
            rxAbs *= sqrt(lambda)
            ryAbs *= sqrt(lambda)
        }

        let rxSq = rxAbs * rxAbs, rySq = ryAbs * ryAbs
        let numerator = max(0, rxSq * rySq - rxSq * y1p * y1p - rySq * x1p * x1p)
        let denominator = rxSq * y1p * y1p + rySq * x1p * x1p
        let coefficient = (largeArc != sweep ? 1 : -1) * sqrt(denominator == 0 ? 0 : numerator / denominator)
        let cxp = coefficient * rxAbs * y1p / ryAbs
        let cyp = -coefficient * ryAbs * x1p / rxAbs
        let cx = cosPhi * cxp - sinPhi * cyp + (start.x + end.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (start.y + end.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let length = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            guard length > 0 else { return 0 }
            var value = acos(max(-1, min(1, dot / length)))
            if ux * vy - uy * vx < 0 { value = -value }
            return value
        }

        let theta1 = angle(1, 0, (x1p - cxp) / rxAbs, (y1p - cyp) / ryAbs)
        var delta = angle((x1p - cxp) / rxAbs, (y1p - cyp) / ryAbs, (-x1p - cxp) / rxAbs, (-y1p - cyp) / ryAbs)
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let segmentAngle = delta / CGFloat(segments)
        let alpha = sin(segmentAngle) * (sqrt(4 + 3 * pow(tan(segmentAngle / 2), 2)) - 1) / 3

        func transform(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
            CGPoint(x: cosPhi * px - sinPhi * py + cx, y: sinPhi * px + cosPhi * py + cy)
        }

        for segment in 0..<segments {
            let a1 = theta1 + CGFloat(segment) * segmentAngle
            let a2 = a1 + segmentAngle
            let p1 = (rxAbs * cos(a1), ryAbs * sin(a1))
            let p2 = (rxAbs * cos(a2), ryAbs * sin(a2))
            let control1 = transform(p1.0 - alpha * rxAbs * sin(a1), p1.1 + alpha * ryAbs * cos(a1))
            let control2 = transform(p2.0 + alpha * rxAbs * sin(a2), p2.1 - alpha * ryAbs * cos(a2))
            path.addCurve(to: transform(p2.0, p2.1), control1: control1, control2: control2)
        }
    }
}

// MARK: - Errors

nonisolated enum SVGParseError: LocalizedError, Equatable {
    case invalidData
    case noPathsFound

    var errorDescription: String? {
        switch self {
        case .invalidData: String(localized: "The SVG file contains invalid data.")
        case .noPathsFound: String(localized: "No drawable paths were found in the SVG file.")
        }
    }
}
