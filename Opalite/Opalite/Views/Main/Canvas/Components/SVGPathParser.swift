//
//  SVGPathParser.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import Foundation
import CoreGraphics

/// Parses SVG files and extracts path data as CGPath objects.
///
/// Supports common SVG path commands: M, L, H, V, C, S, Q, T, A, Z
/// and their lowercase (relative) variants.
struct SVGPathParser {

    /// Result of parsing an SVG file
    struct ParseResult {
        /// The extracted paths from the SVG
        let paths: [CGPath]
        /// The viewBox or computed bounds of the SVG
        let bounds: CGRect
        /// Any parsing errors encountered (non-fatal)
        let warnings: [String]
    }

    /// Parses an SVG file at the given URL
    /// - Parameter url: URL to the SVG file
    /// - Returns: ParseResult containing paths and metadata
    func parse(from url: URL) throws -> ParseResult {
        let data = try Data(contentsOf: url)
        return try parse(from: data)
    }

    /// Parses SVG data
    /// - Parameter data: Raw SVG data
    /// - Returns: ParseResult containing paths and metadata
    func parse(from data: Data) throws -> ParseResult {
        guard let svgString = String(data: data, encoding: .utf8) else {
            throw SVGParseError.invalidData
        }
        return try parse(from: svgString)
    }

    /// Parses an SVG string
    /// - Parameter svgString: The SVG content as a string
    /// - Returns: ParseResult containing paths and metadata
    func parse(from svgString: String) throws -> ParseResult {
        var paths: [CGPath] = []
        var warnings: [String] = []
        var viewBox: CGRect?

        // Extract viewBox if present
        if let viewBoxMatch = svgString.range(of: #"viewBox\s*=\s*"([^"]*)""#, options: .regularExpression) {
            let viewBoxString = String(svgString[viewBoxMatch])
            if let valuesMatch = viewBoxString.range(of: #""([^"]*)""#, options: .regularExpression) {
                let values = String(viewBoxString[valuesMatch])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    .split(separator: " ")
                    .compactMap { Double($0) }
                if values.count == 4 {
                    viewBox = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
                }
            }
        }

        // Extract all path elements
        let pathPattern = #"<path[^>]*d\s*=\s*"([^"]*)""#
        let pathRegex = try? NSRegularExpression(pattern: pathPattern, options: [.dotMatchesLineSeparators])
        let nsString = svgString as NSString
        let matches = pathRegex?.matches(in: svgString, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []

        for match in matches {
            if match.numberOfRanges >= 2 {
                let pathDataRange = match.range(at: 1)
                let pathData = nsString.substring(with: pathDataRange)
                if let cgPath = parsePath(pathData) {
                    paths.append(cgPath)
                } else {
                    warnings.append("Failed to parse path: \(pathData.prefix(50))...")
                }
            }
        }

        // Also look for basic shapes and convert them to paths
        paths.append(contentsOf: parseRectElements(from: svgString))
        paths.append(contentsOf: parseCircleElements(from: svgString))
        paths.append(contentsOf: parseEllipseElements(from: svgString))
        paths.append(contentsOf: parseLineElements(from: svgString))
        paths.append(contentsOf: parsePolylineElements(from: svgString))
        paths.append(contentsOf: parsePolygonElements(from: svgString))

        // Calculate bounds from paths if no viewBox
        let bounds = viewBox ?? calculateBounds(from: paths)

        if paths.isEmpty {
            throw SVGParseError.noPathsFound
        }

        return ParseResult(paths: paths, bounds: bounds, warnings: warnings)
    }

    // MARK: - Path Parsing

    /// Parses an SVG path data string into a CGPath
    private func parsePath(_ data: String) -> CGPath? {
        let path = CGMutablePath()
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        var lastControlPoint: CGPoint?

        let tokens = tokenize(data)
        var i = 0
        var currentCommand: Character = "M"

        while i < tokens.count {
            let token = tokens[i]

            // Check if this is a command
            if token.count == 1, let char = token.first, char.isLetter {
                currentCommand = char
                i += 1

                // Execute Z/z immediately since it takes no parameters
                // This handles the case where Z is the last token in the path
                if char == "Z" || char == "z" {
                    path.closeSubpath()
                    currentPoint = startPoint
                    lastControlPoint = nil
                }
                continue
            }

            // Parse based on current command
            switch currentCommand {
            case "M": // Move to (absolute)
                if let point = parsePoint(tokens, at: &i) {
                    path.move(to: point)
                    currentPoint = point
                    startPoint = point
                    currentCommand = "L" // Subsequent coordinates are line-to
                }

            case "m": // Move to (relative)
                if let offset = parsePoint(tokens, at: &i) {
                    let point = CGPoint(x: currentPoint.x + offset.x, y: currentPoint.y + offset.y)
                    path.move(to: point)
                    currentPoint = point
                    startPoint = point
                    currentCommand = "l"
                }

            case "L": // Line to (absolute)
                if let point = parsePoint(tokens, at: &i) {
                    path.addLine(to: point)
                    currentPoint = point
                }

            case "l": // Line to (relative)
                if let offset = parsePoint(tokens, at: &i) {
                    let point = CGPoint(x: currentPoint.x + offset.x, y: currentPoint.y + offset.y)
                    path.addLine(to: point)
                    currentPoint = point
                }

            case "H": // Horizontal line (absolute)
                if let x = parseNumber(tokens, at: &i) {
                    let point = CGPoint(x: x, y: currentPoint.y)
                    path.addLine(to: point)
                    currentPoint = point
                }

            case "h": // Horizontal line (relative)
                if let dx = parseNumber(tokens, at: &i) {
                    let point = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    path.addLine(to: point)
                    currentPoint = point
                }

            case "V": // Vertical line (absolute)
                if let y = parseNumber(tokens, at: &i) {
                    let point = CGPoint(x: currentPoint.x, y: y)
                    path.addLine(to: point)
                    currentPoint = point
                }

            case "v": // Vertical line (relative)
                if let dy = parseNumber(tokens, at: &i) {
                    let point = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    path.addLine(to: point)
                    currentPoint = point
                }

            case "C": // Cubic bezier (absolute)
                if let cp1 = parsePoint(tokens, at: &i),
                   let cp2 = parsePoint(tokens, at: &i),
                   let end = parsePoint(tokens, at: &i) {
                    path.addCurve(to: end, control1: cp1, control2: cp2)
                    lastControlPoint = cp2
                    currentPoint = end
                }

            case "c": // Cubic bezier (relative)
                if let cp1Offset = parsePoint(tokens, at: &i),
                   let cp2Offset = parsePoint(tokens, at: &i),
                   let endOffset = parsePoint(tokens, at: &i) {
                    let cp1 = CGPoint(x: currentPoint.x + cp1Offset.x, y: currentPoint.y + cp1Offset.y)
                    let cp2 = CGPoint(x: currentPoint.x + cp2Offset.x, y: currentPoint.y + cp2Offset.y)
                    let end = CGPoint(x: currentPoint.x + endOffset.x, y: currentPoint.y + endOffset.y)
                    path.addCurve(to: end, control1: cp1, control2: cp2)
                    lastControlPoint = cp2
                    currentPoint = end
                }

            case "S": // Smooth cubic bezier (absolute)
                if let cp2 = parsePoint(tokens, at: &i),
                   let end = parsePoint(tokens, at: &i) {
                    let cp1 = reflectControlPoint(lastControlPoint, around: currentPoint)
                    path.addCurve(to: end, control1: cp1, control2: cp2)
                    lastControlPoint = cp2
                    currentPoint = end
                }

            case "s": // Smooth cubic bezier (relative)
                if let cp2Offset = parsePoint(tokens, at: &i),
                   let endOffset = parsePoint(tokens, at: &i) {
                    let cp1 = reflectControlPoint(lastControlPoint, around: currentPoint)
                    let cp2 = CGPoint(x: currentPoint.x + cp2Offset.x, y: currentPoint.y + cp2Offset.y)
                    let end = CGPoint(x: currentPoint.x + endOffset.x, y: currentPoint.y + endOffset.y)
                    path.addCurve(to: end, control1: cp1, control2: cp2)
                    lastControlPoint = cp2
                    currentPoint = end
                }

            case "Q": // Quadratic bezier (absolute)
                if let cp = parsePoint(tokens, at: &i),
                   let end = parsePoint(tokens, at: &i) {
                    path.addQuadCurve(to: end, control: cp)
                    lastControlPoint = cp
                    currentPoint = end
                }

            case "q": // Quadratic bezier (relative)
                if let cpOffset = parsePoint(tokens, at: &i),
                   let endOffset = parsePoint(tokens, at: &i) {
                    let cp = CGPoint(x: currentPoint.x + cpOffset.x, y: currentPoint.y + cpOffset.y)
                    let end = CGPoint(x: currentPoint.x + endOffset.x, y: currentPoint.y + endOffset.y)
                    path.addQuadCurve(to: end, control: cp)
                    lastControlPoint = cp
                    currentPoint = end
                }

            case "T": // Smooth quadratic bezier (absolute)
                if let end = parsePoint(tokens, at: &i) {
                    let cp = reflectControlPoint(lastControlPoint, around: currentPoint)
                    path.addQuadCurve(to: end, control: cp)
                    lastControlPoint = cp
                    currentPoint = end
                }

            case "t": // Smooth quadratic bezier (relative)
                if let endOffset = parsePoint(tokens, at: &i) {
                    let cp = reflectControlPoint(lastControlPoint, around: currentPoint)
                    let end = CGPoint(x: currentPoint.x + endOffset.x, y: currentPoint.y + endOffset.y)
                    path.addQuadCurve(to: end, control: cp)
                    lastControlPoint = cp
                    currentPoint = end
                }

            case "A", "a": // Arc
                // Arc parameters: rx ry x-axis-rotation large-arc-flag sweep-flag x y
                if let rx = parseNumber(tokens, at: &i),
                   let ry = parseNumber(tokens, at: &i),
                   let xAxisRotation = parseNumber(tokens, at: &i),
                   let largeArc = parseNumber(tokens, at: &i),
                   let sweep = parseNumber(tokens, at: &i),
                   let endX = parseNumber(tokens, at: &i),
                   let endY = parseNumber(tokens, at: &i) {
                    let endPoint: CGPoint
                    if currentCommand == "A" {
                        endPoint = CGPoint(x: endX, y: endY)
                    } else {
                        endPoint = CGPoint(x: currentPoint.x + endX, y: currentPoint.y + endY)
                    }
                    addArc(to: path, from: currentPoint, to: endPoint,
                           rx: rx, ry: ry,
                           xAxisRotation: xAxisRotation,
                           largeArcFlag: largeArc > 0.5,
                           sweepFlag: sweep > 0.5)
                    currentPoint = endPoint
                }

            case "Z", "z": // Close path
                path.closeSubpath()
                currentPoint = startPoint
                i += 1 // Move past Z if needed
                continue

            default:
                i += 1
            }

            // Reset control point for non-curve commands
            if !"CcSsQqTt".contains(currentCommand) {
                lastControlPoint = nil
            }
        }

        return path.isEmpty ? nil : path
    }

    // MARK: - Token Parsing

    /// Tokenizes an SVG path data string into commands and numbers
    private func tokenize(_ data: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inNumber = false

        for char in data {
            if char.isLetter {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
                inNumber = false
            } else if char.isNumber || char == "." || char == "-" || char == "e" || char == "E" {
                // Handle negative numbers that immediately follow another number (e.g., "-7.87-0.021")
                // Split the token unless it's part of scientific notation (e.g., "1e-10")
                if char == "-" && !current.isEmpty && !current.hasSuffix("e") && !current.hasSuffix("E") {
                    tokens.append(current)
                    current = ""
                }
                current.append(char)
                inNumber = true
            } else if char == "," || char.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                inNumber = false
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func parseNumber(_ tokens: [String], at index: inout Int) -> CGFloat? {
        guard index < tokens.count, let value = Double(tokens[index]) else {
            return nil
        }
        index += 1
        return CGFloat(value)
    }

    private func parsePoint(_ tokens: [String], at index: inout Int) -> CGPoint? {
        guard let x = parseNumber(tokens, at: &index),
              let y = parseNumber(tokens, at: &index) else {
            return nil
        }
        return CGPoint(x: x, y: y)
    }

    private func reflectControlPoint(_ controlPoint: CGPoint?, around point: CGPoint) -> CGPoint {
        guard let cp = controlPoint else { return point }
        return CGPoint(
            x: 2 * point.x - cp.x,
            y: 2 * point.y - cp.y
        )
    }

    // MARK: - Arc Conversion

    /// Converts SVG arc parameters to CGPath arc
    private func addArc(to path: CGMutablePath,
                        from start: CGPoint,
                        to end: CGPoint,
                        rx: CGFloat,
                        ry: CGFloat,
                        xAxisRotation: CGFloat,
                        largeArcFlag: Bool,
                        sweepFlag: Bool) {
        // If radii are 0, treat as straight line
        if rx == 0 || ry == 0 {
            path.addLine(to: end)
            return
        }

        // Convert to center parameterization
        let phi = xAxisRotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // Step 1: Compute (x1', y1')
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1Prime = cosPhi * dx + sinPhi * dy
        let y1Prime = -sinPhi * dx + cosPhi * dy

        // Ensure radii are large enough
        var rxAbs = abs(rx)
        var ryAbs = abs(ry)
        let lambda = (x1Prime * x1Prime) / (rxAbs * rxAbs) + (y1Prime * y1Prime) / (ryAbs * ryAbs)
        if lambda > 1 {
            let sqrtLambda = sqrt(lambda)
            rxAbs *= sqrtLambda
            ryAbs *= sqrtLambda
        }

        // Step 2: Compute (cx', cy')
        let rxSq = rxAbs * rxAbs
        let rySq = ryAbs * ryAbs
        let x1PrimeSq = x1Prime * x1Prime
        let y1PrimeSq = y1Prime * y1Prime

        var sq = (rxSq * rySq - rxSq * y1PrimeSq - rySq * x1PrimeSq) / (rxSq * y1PrimeSq + rySq * x1PrimeSq)
        sq = max(0, sq)
        let coef = (largeArcFlag != sweepFlag ? 1 : -1) * sqrt(sq)
        let cxPrime = coef * rxAbs * y1Prime / ryAbs
        let cyPrime = -coef * ryAbs * x1Prime / rxAbs

        // Step 3: Compute (cx, cy) from (cx', cy')
        let cx = cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2
        let cy = sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2

        // Step 4: Compute angles
        func angle(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var angle = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 {
                angle = -angle
            }
            return angle
        }

        let theta1 = angle(ux: 1, uy: 0,
                          vx: (x1Prime - cxPrime) / rxAbs,
                          vy: (y1Prime - cyPrime) / ryAbs)
        var dTheta = angle(ux: (x1Prime - cxPrime) / rxAbs,
                          uy: (y1Prime - cyPrime) / ryAbs,
                          vx: (-x1Prime - cxPrime) / rxAbs,
                          vy: (-y1Prime - cyPrime) / ryAbs)

        if !sweepFlag && dTheta > 0 {
            dTheta -= 2 * .pi
        } else if sweepFlag && dTheta < 0 {
            dTheta += 2 * .pi
        }

        // Approximate arc with bezier curves
        let numSegments = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let segmentAngle = dTheta / CGFloat(numSegments)

        for i in 0..<numSegments {
            let startAngle = theta1 + CGFloat(i) * segmentAngle
            let endAngle = startAngle + segmentAngle

            let alpha = sin(segmentAngle) * (sqrt(4 + 3 * pow(tan(segmentAngle / 2), 2)) - 1) / 3

            let cosStart = cos(startAngle)
            let sinStart = sin(startAngle)
            let cosEnd = cos(endAngle)
            let sinEnd = sin(endAngle)

            let p1x = rxAbs * cosStart
            let p1y = ryAbs * sinStart
            let p2x = rxAbs * cosEnd
            let p2y = ryAbs * sinEnd

            let cp1x = p1x - alpha * rxAbs * sinStart
            let cp1y = p1y + alpha * ryAbs * cosStart
            let cp2x = p2x + alpha * rxAbs * sinEnd
            let cp2y = p2y - alpha * ryAbs * cosEnd

            // Transform points back
            func transform(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
                CGPoint(
                    x: cosPhi * px - sinPhi * py + cx,
                    y: sinPhi * px + cosPhi * py + cy
                )
            }

            let control1 = transform(cp1x, cp1y)
            let control2 = transform(cp2x, cp2y)
            let endPt = transform(p2x, p2y)

            path.addCurve(to: endPt, control1: control1, control2: control2)
        }
    }

    // MARK: - Basic Shape Parsing

    private func parseRectElements(from svg: String) -> [CGPath] {
        var paths: [CGPath] = []
        let pattern = #"<rect[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return paths }
        let nsString = svg as NSString
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            let element = nsString.substring(with: match.range)
            let x = extractAttribute("x", from: element) ?? 0
            let y = extractAttribute("y", from: element) ?? 0
            let width = extractAttribute("width", from: element) ?? 0
            let height = extractAttribute("height", from: element) ?? 0
            let rx = extractAttribute("rx", from: element) ?? 0
            let ry = extractAttribute("ry", from: element) ?? rx

            let path = CGMutablePath()
            if rx > 0 || ry > 0 {
                path.addRoundedRect(in: CGRect(x: x, y: y, width: width, height: height),
                                   cornerWidth: rx, cornerHeight: ry)
            } else {
                path.addRect(CGRect(x: x, y: y, width: width, height: height))
            }
            paths.append(path)
        }
        return paths
    }

    private func parseCircleElements(from svg: String) -> [CGPath] {
        var paths: [CGPath] = []
        let pattern = #"<circle[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return paths }
        let nsString = svg as NSString
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            let element = nsString.substring(with: match.range)
            let cx = extractAttribute("cx", from: element) ?? 0
            let cy = extractAttribute("cy", from: element) ?? 0
            let r = extractAttribute("r", from: element) ?? 0

            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            paths.append(path)
        }
        return paths
    }

    private func parseEllipseElements(from svg: String) -> [CGPath] {
        var paths: [CGPath] = []
        let pattern = #"<ellipse[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return paths }
        let nsString = svg as NSString
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            let element = nsString.substring(with: match.range)
            let cx = extractAttribute("cx", from: element) ?? 0
            let cy = extractAttribute("cy", from: element) ?? 0
            let rx = extractAttribute("rx", from: element) ?? 0
            let ry = extractAttribute("ry", from: element) ?? 0

            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
            paths.append(path)
        }
        return paths
    }

    private func parseLineElements(from svg: String) -> [CGPath] {
        var paths: [CGPath] = []
        let pattern = #"<line[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return paths }
        let nsString = svg as NSString
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            let element = nsString.substring(with: match.range)
            let x1 = extractAttribute("x1", from: element) ?? 0
            let y1 = extractAttribute("y1", from: element) ?? 0
            let x2 = extractAttribute("x2", from: element) ?? 0
            let y2 = extractAttribute("y2", from: element) ?? 0

            let path = CGMutablePath()
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
            paths.append(path)
        }
        return paths
    }

    private func parsePolylineElements(from svg: String) -> [CGPath] {
        var paths: [CGPath] = []
        let pattern = #"<polyline[^>]*points\s*=\s*"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return paths }
        let nsString = svg as NSString
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if match.numberOfRanges >= 2 {
                let pointsRange = match.range(at: 1)
                let pointsString = nsString.substring(with: pointsRange)
                if let path = parsePointsString(pointsString, close: false) {
                    paths.append(path)
                }
            }
        }
        return paths
    }

    private func parsePolygonElements(from svg: String) -> [CGPath] {
        var paths: [CGPath] = []
        let pattern = #"<polygon[^>]*points\s*=\s*"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return paths }
        let nsString = svg as NSString
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if match.numberOfRanges >= 2 {
                let pointsRange = match.range(at: 1)
                let pointsString = nsString.substring(with: pointsRange)
                if let path = parsePointsString(pointsString, close: true) {
                    paths.append(path)
                }
            }
        }
        return paths
    }

    private func parsePointsString(_ string: String, close: Bool) -> CGPath? {
        let numbers = string
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0) }

        guard numbers.count >= 4 else { return nil }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: numbers[0], y: numbers[1]))

        for i in stride(from: 2, to: numbers.count - 1, by: 2) {
            path.addLine(to: CGPoint(x: numbers[i], y: numbers[i + 1]))
        }

        if close {
            path.closeSubpath()
        }

        return path
    }

    private func extractAttribute(_ name: String, from element: String) -> CGFloat? {
        let pattern = "\(name)\\s*=\\s*\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: element, options: [], range: NSRange(location: 0, length: (element as NSString).length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        let valueRange = match.range(at: 1)
        let valueString = (element as NSString).substring(with: valueRange)
        return Double(valueString).map { CGFloat($0) }
    }

    // MARK: - Bounds Calculation

    private func calculateBounds(from paths: [CGPath]) -> CGRect {
        var bounds = CGRect.null
        for path in paths {
            bounds = bounds.union(path.boundingBox)
        }
        return bounds.isNull ? CGRect(x: 0, y: 0, width: 100, height: 100) : bounds
    }
}

// MARK: - Errors

enum SVGParseError: LocalizedError {
    case invalidData
    case noPathsFound
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The SVG file contains invalid data."
        case .noPathsFound:
            return "No drawable paths found in the SVG file."
        case .fileNotFound:
            return "The SVG file could not be found."
        }
    }
}
