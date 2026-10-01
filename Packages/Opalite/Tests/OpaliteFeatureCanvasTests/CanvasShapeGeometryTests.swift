import Testing
import CoreGraphics
import OpaliteCore
@testable import OpaliteFeatureCanvas

@Suite("CanvasShapeGeometry")
struct CanvasShapeGeometryTests {
    private let center = CGPoint(x: 100, y: 100)

    @Test("Rectangles and squares fill the requested box with tripled corners")
    func rectangle() {
        let polylines = CanvasShapeGeometry.polylines(for: .rectangle, center: center, width: 40, height: 20)
        #expect(polylines.count == 1)
        let points = polylines[0]
        #expect(points.count == 15)
        #expect(PathSampling.bounds(of: polylines) == CGRect(x: 80, y: 90, width: 40, height: 20))
        #expect(points[0] == points[1] && points[1] == points[2])
        #expect(points.first == points.last)
    }

    @Test("Circles are closed ellipses inside the box")
    func circle() {
        let polylines = CanvasShapeGeometry.polylines(for: .circle, center: center, width: 60, height: 40)
        let points = polylines[0]
        #expect(points.first == points.last)
        let box = PathSampling.bounds(of: polylines)
        #expect(abs(box.width - 60) < 0.01 && abs(box.height - 40) < 0.01)
        #expect(points.allSatisfy { abs(pow(($0.x - 100) / 30, 2) + pow(($0.y - 100) / 20, 2) - 1) < 1e-6 })
    }

    @Test("Triangle apex is top-center with the base along the bottom")
    func triangle() {
        let points = CanvasShapeGeometry.polylines(for: .triangle, center: center, width: 40, height: 30)[0]
        #expect(points[0] == CGPoint(x: 100, y: 85))
        #expect(points.contains(CGPoint(x: 120, y: 115)))
        #expect(points.contains(CGPoint(x: 80, y: 115)))
    }

    @Test("Line spans the width at the vertical center")
    func line() {
        let points = CanvasShapeGeometry.polylines(for: .line, center: center, width: 50, height: 10)[0]
        #expect(points == [CGPoint(x: 75, y: 100), CGPoint(x: 125, y: 100)])
    }

    @Test("Arrow is a shaft plus two head strokes meeting at the tip")
    func arrow() {
        let polylines = CanvasShapeGeometry.polylines(for: .arrow, center: center, width: 100, height: 60)
        #expect(polylines.count == 3)
        let tip = CGPoint(x: 150, y: 100)
        #expect(polylines[0].last == tip)
        #expect(polylines[1].first == tip && polylines[2].first == tip)
        #expect(polylines[1].last == CGPoint(x: 125, y: 75))
        #expect(polylines[2].last == CGPoint(x: 125, y: 125))
    }

    @Test("Shirt fills the requested box at its native 1.26 aspect")
    func shirt() {
        let polylines = CanvasShapeGeometry.polylines(for: .shirt, center: center, width: 126, height: 100)
        #expect(polylines.count == 1)
        let box = PathSampling.bounds(of: polylines)
        #expect(abs(box.width - 125) < 1)
        #expect(abs(box.height - 99.2) < 1)
        #expect(abs(box.midX - 100) < 1 && abs(box.midY - 100) < 1)
    }

    @Test("Rotation keeps the shape centered and turns the box")
    func rotation() {
        let polylines = CanvasShapeGeometry.polylines(for: .line, center: center, width: 50, height: 10, rotation: .pi / 2)
        let points = polylines[0]
        #expect(abs(points[0].x - 100) < 1e-9 && abs(points[0].y - 75) < 1e-9)
        #expect(abs(points[1].x - 100) < 1e-9 && abs(points[1].y - 125) < 1e-9)
    }

    @Test("SVG paths are fitted into the box, non-uniformly")
    func svgFit() {
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        let polylines = CanvasShapeGeometry.polylines(forSVGPaths: [path], svgBounds: CGRect(x: 0, y: 0, width: 10, height: 10), center: center, width: 80, height: 40)
        let box = PathSampling.bounds(of: polylines)
        #expect(abs(box.width - 80) < 0.01 && abs(box.height - 40) < 0.01)
        #expect(abs(box.midX - 100) < 0.01 && abs(box.midY - 100) < 0.01)
    }

    @Test("Every shape honors its constrained aspect ratio when boxed by it")
    func constrainedAspects() {
        for shape in CanvasShape.allCases {
            guard let ratio = shape.constrainedAspectRatio else { continue }
            let polylines = CanvasShapeGeometry.polylines(for: shape, center: center, width: 100 * ratio, height: 100)
            let box = PathSampling.bounds(of: polylines)
            #expect(abs(box.width / box.height - ratio) < 0.03, "\(shape)")
        }
    }
}
