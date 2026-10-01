import Testing
import CoreGraphics
@testable import OpaliteFeatureCanvas

@Suite("PathSampling")
struct PathSamplingTests {
    @Test("Line sampling excludes the start and ends exactly on the end point")
    func lineSampling() {
        let points = PathSampling.line(from: .zero, to: CGPoint(x: 10, y: 0), spacing: 2)
        #expect(points.count == 5)
        #expect(points.first == CGPoint(x: 2, y: 0))
        #expect(points.last == CGPoint(x: 10, y: 0))
    }

    @Test("A zero-length line still yields its end point")
    func degenerateLine() {
        #expect(PathSampling.line(from: .zero, to: .zero) == [.zero])
    }

    @Test("Bézier sampling ends on the end point and respects the hull")
    func bezierSampling() {
        let cubic = PathSampling.cubicBezier(from: .zero, control1: CGPoint(x: 0, y: 10), control2: CGPoint(x: 10, y: 10), to: CGPoint(x: 10, y: 0), spacing: 1)
        #expect(cubic.last == CGPoint(x: 10, y: 0))
        #expect(cubic.allSatisfy { $0.y >= 0 && $0.y <= 10 && $0.x >= 0 && $0.x <= 10 })

        let quad = PathSampling.quadraticBezier(from: .zero, control: CGPoint(x: 5, y: 10), to: CGPoint(x: 10, y: 0), spacing: 1)
        #expect(quad.last == CGPoint(x: 10, y: 0))
        #expect(quad.count >= 2)
    }

    @Test("Subpaths split into separate polylines and close back to their start")
    func subpaths() {
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: 10, height: 10))
        path.move(to: CGPoint(x: 20, y: 0))
        path.addLine(to: CGPoint(x: 30, y: 0))
        let polylines = PathSampling.polylines(from: path, spacing: 1)
        #expect(polylines.count == 2)
        #expect(polylines[0].first == .zero)
        #expect(polylines[0].last == .zero)
        #expect(polylines[1].first == CGPoint(x: 20, y: 0))
        #expect(polylines[1].last == CGPoint(x: 30, y: 0))
    }

    @Test("Rotation by 90° maps right to down")
    func rotation() {
        let rotated = PathSampling.rotate(CGPoint(x: 10, y: 0), around: .zero, by: .pi / 2)
        #expect(abs(rotated.x) < 1e-9)
        #expect(abs(rotated.y - 10) < 1e-9)
    }

    @Test("Bounds cover every point, and are null when empty")
    func bounds() {
        let box = PathSampling.bounds(of: [[CGPoint(x: -1, y: 2)], [CGPoint(x: 3, y: -4), CGPoint(x: 0, y: 0)]])
        #expect(box == CGRect(x: -1, y: -4, width: 4, height: 6))
        #expect(PathSampling.bounds(of: []).isNull)
    }
}
