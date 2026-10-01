import Testing
import CoreGraphics
import Foundation
@testable import OpaliteFeatureCanvas

@Suite("SVGPathParser")
struct SVGPathParserTests {
    private let parser = SVGPathParser()

    @Test("viewBox wins over computed bounds")
    func viewBox() throws {
        let svg = #"<svg viewBox="0 0 200 100"><path d="M 10 10 L 50 10 L 50 50 Z"/></svg>"#
        let result = try parser.parse(from: svg)
        #expect(result.bounds == CGRect(x: 0, y: 0, width: 200, height: 100))
        #expect(result.paths.count == 1)
        #expect(result.warnings.isEmpty)
    }

    @Test("Bounds are computed from paths when there is no viewBox")
    func computedBounds() throws {
        let svg = #"<svg><path d="M10,20 L110,20 L110,70 Z"/></svg>"#
        let result = try parser.parse(from: svg)
        #expect(result.bounds == CGRect(x: 10, y: 20, width: 100, height: 50))
    }

    @Test("Absolute and relative commands produce the same geometry")
    func relativeCommands() throws {
        let absolute = try #require(parser.parsePathData("M 10 10 L 20 10 L 20 20 H 10 V 10 Z"))
        let relative = try #require(parser.parsePathData("m 10 10 l 10 0 l 0 10 h -10 v -10 z"))
        #expect(absolute.boundingBoxOfPath == relative.boundingBoxOfPath)
        #expect(absolute.boundingBoxOfPath == CGRect(x: 10, y: 10, width: 10, height: 10))
    }

    @Test("Implicit line-to after move and packed negative numbers")
    func implicitLineTo() throws {
        let path = try #require(parser.parsePathData("M0,0 10,0 10,-10-5-10Z"))
        #expect(path.boundingBoxOfPath == CGRect(x: -5, y: -10, width: 15, height: 10))
    }

    @Test("Curves and arcs stay inside their hull")
    func curvesAndArcs() throws {
        let cubic = try #require(parser.parsePathData("M0,0 C 0,100 100,100 100,0"))
        let cubicBox = cubic.boundingBoxOfPath
        #expect(cubicBox.minX == 0 && cubicBox.maxX == 100)
        #expect(cubicBox.maxY > 50 && cubicBox.maxY <= 100)

        let quad = try #require(parser.parsePathData("M0,0 Q 50,50 100,0 T 200,0"))
        #expect(quad.boundingBoxOfPath.width == 200)

        let arc = try #require(parser.parsePathData("M 0,50 A 50,50 0 0 1 100,50"))
        let arcBox = arc.boundingBoxOfPath
        #expect(abs(arcBox.width - 100) < 0.5)
        #expect(abs(arcBox.height - 50) < 1.5)
    }

    @Test("Basic shape elements become paths")
    func basicShapes() throws {
        let svg = """
        <svg viewBox="0 0 100 100">
          <rect x="5" y="5" width="20" height="10"/>
          <circle cx="50" cy="50" r="10"/>
          <ellipse cx="50" cy="50" rx="10" ry="5"/>
          <line x1="0" y1="0" x2="10" y2="10"/>
          <polyline points="0,0 10,0 10,10"/>
          <polygon points="0 0, 10 0, 10 10"/>
        </svg>
        """
        let result = try parser.parse(from: svg)
        #expect(result.paths.count == 6)
        #expect(result.paths[0].boundingBoxOfPath == CGRect(x: 5, y: 5, width: 20, height: 10))
        #expect(result.paths[1].boundingBoxOfPath == CGRect(x: 40, y: 40, width: 20, height: 20))
    }

    @Test("An SVG without drawable content throws")
    func noPaths() {
        #expect(throws: SVGParseError.noPathsFound) {
            _ = try parser.parse(from: #"<svg viewBox="0 0 10 10"><text>hi</text></svg>"#)
        }
    }

    @Test("Unparseable path data is reported as a warning, not an error")
    func warnings() throws {
        let svg = #"<svg><path d="??"/><path d="M0 0 L 10 10"/></svg>"#
        let result = try parser.parse(from: svg)
        #expect(result.paths.count == 1)
        #expect(result.warnings.count == 1)
    }

    @Test("The shirt path parses to the expected native box")
    func shirt() throws {
        let path = try #require(parser.parsePathData(CanvasShapeGeometry.shirtPathData))
        let box = path.boundingBoxOfPath
        #expect(abs(box.minX - 5) < 0.01 && abs(box.maxX - 1255) < 0.01)
        #expect(abs(box.minY - 4) < 0.01 && abs(box.maxY - 996) < 0.01)
    }
}
