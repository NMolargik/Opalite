import Testing
import CoreGraphics
@testable import OpaliteFeatureCanvas

@Suite("ShapePlacementGeometry")
struct ShapePlacementGeometryTests {
    private let origin = CGPoint(x: 100, y: 100)

    @Test("Free drags grow away from the origin in every quadrant")
    func quadrants() {
        #expect(ShapePlacementGeometry.dragRect(from: origin, to: CGPoint(x: 140, y: 130), aspectRatio: nil) == CGRect(x: 100, y: 100, width: 40, height: 30))
        #expect(ShapePlacementGeometry.dragRect(from: origin, to: CGPoint(x: 60, y: 130), aspectRatio: nil) == CGRect(x: 60, y: 100, width: 40, height: 30))
        #expect(ShapePlacementGeometry.dragRect(from: origin, to: CGPoint(x: 60, y: 70), aspectRatio: nil) == CGRect(x: 60, y: 70, width: 40, height: 30))
        #expect(ShapePlacementGeometry.dragRect(from: origin, to: CGPoint(x: 140, y: 70), aspectRatio: nil) == CGRect(x: 100, y: 70, width: 40, height: 30))
    }

    @Test("An aspect lock shrinks the dominant axis to fit")
    func aspectLock() {
        let wide = ShapePlacementGeometry.dragRect(from: origin, to: CGPoint(x: 200, y: 120), aspectRatio: 2)
        #expect(wide.size == CGSize(width: 40, height: 20))
        let tall = ShapePlacementGeometry.dragRect(from: origin, to: CGPoint(x: 110, y: 200), aspectRatio: 1)
        #expect(tall.size == CGSize(width: 10, height: 10))
        let upLeft = ShapePlacementGeometry.dragRect(from: origin, to: CGPoint(x: 0, y: 50), aspectRatio: 1)
        #expect(upLeft == CGRect(x: 50, y: 50, width: 50, height: 50))
    }

    @Test("A tap becomes a default-size rect centered on the origin")
    func tap() {
        let rect = ShapePlacementGeometry.finalizedRect(CGRect(origin: origin, size: CGSize(width: 3, height: 2)), origin: origin, aspectRatio: nil)
        #expect(rect.width == ShapePlacementGeometry.defaultTapSize)
        #expect(rect.midX == 100 && rect.midY == 100)

        let locked = ShapePlacementGeometry.finalizedRect(.init(origin: origin, size: .zero), origin: origin, aspectRatio: 2)
        #expect(locked.width == ShapePlacementGeometry.defaultTapSize && locked.height == ShapePlacementGeometry.defaultTapSize / 2)
    }

    @Test("Tiny drags snap up around their center; normal drags are untouched")
    func snapUp() {
        let small = CGRect(x: 100, y: 100, width: 30, height: 100)
        let snapped = ShapePlacementGeometry.finalizedRect(small, origin: origin, aspectRatio: nil)
        #expect(snapped.width == ShapePlacementGeometry.minimumDimension * 2)
        #expect(snapped.height == 100)
        #expect(snapped.midX == small.midX && snapped.midY == small.midY)

        let normal = CGRect(x: 0, y: 0, width: 80, height: 60)
        #expect(ShapePlacementGeometry.finalizedRect(normal, origin: .zero, aspectRatio: nil) == normal)
    }

    @Test("Rotation snaps to 5° and buckets every 10°")
    func rotation() {
        let snapped = ShapePlacementGeometry.snappedRotation(7 * .pi / 180)
        #expect(abs(snapped - 5 * .pi / 180) < 1e-9)
        #expect(ShapePlacementGeometry.hapticBucket(forRotation: 9 * .pi / 180) == 0)
        #expect(ShapePlacementGeometry.hapticBucket(forRotation: 10 * .pi / 180) == 1)
        #expect(ShapePlacementGeometry.hapticBucket(forRotation: -25 * .pi / 180) == -2)
    }

    @Test("View rects map through the scroll offset and zoom")
    func viewToCanvas() {
        let rect = ShapePlacementGeometry.canvasRect(fromViewRect: CGRect(x: 10, y: 20, width: 100, height: 50), contentOffset: CGPoint(x: 200, y: 400), zoomScale: 2)
        #expect(rect == CGRect(x: 105, y: 210, width: 50, height: 25))
        let visible = ShapePlacementGeometry.visibleCanvasRect(viewportSize: CGSize(width: 400, height: 300), contentOffset: CGPoint(x: 100, y: 100), zoomScale: 0.5)
        #expect(visible == CGRect(x: 200, y: 200, width: 800, height: 600))
    }
}
