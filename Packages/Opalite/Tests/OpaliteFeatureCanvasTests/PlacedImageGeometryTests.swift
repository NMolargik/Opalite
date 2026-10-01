import Testing
import CoreGraphics
import Foundation
import OpaliteCore
@testable import OpaliteFeatureCanvas

@Suite("PlacedImageGeometry")
struct PlacedImageGeometryTests {
    private func image(size: CGSize = CGSize(width: 200, height: 100), at position: CGPoint = CGPoint(x: 500, y: 500), rotation: Double = 0) -> CanvasPlacedImage {
        CanvasPlacedImage(imageData: Data(), position: position, size: size, rotation: rotation)
    }

    @Test("Moves are divided by the zoom scale")
    func move() {
        let moved = PlacedImageGeometry.moved(image(), by: CGSize(width: 40, height: -20), zoomScale: 2)
        #expect(moved.position == CGPoint(x: 520, y: 490))
    }

    @Test("Corner resize keeps the aspect ratio and pins the opposite corner")
    func resize() {
        let start = image()
        let grown = PlacedImageGeometry.resized(start, handle: .bottomTrailing, translation: CGSize(width: 100, height: 0), zoomScale: 1, startSize: start.size, startPosition: start.position)
        #expect(grown.size == CGSize(width: 300, height: 150))
        // Top-leading corner stays at (400, 450).
        #expect(grown.boundingRect.minX == 400 && grown.boundingRect.minY == 450)

        let shrunk = PlacedImageGeometry.resized(start, handle: .topLeading, translation: CGSize(width: 50, height: 50), zoomScale: 1, startSize: start.size, startPosition: start.position)
        #expect(shrunk.size.width == 150 && shrunk.size.height == 75)
        // Bottom-trailing corner stays at (600, 550).
        #expect(shrunk.boundingRect.maxX == 600 && shrunk.boundingRect.maxY == 550)
    }

    @Test("Resizing never goes below the minimum side")
    func minimum() {
        let start = image()
        let tiny = PlacedImageGeometry.resized(start, handle: .bottomTrailing, translation: CGSize(width: -1000, height: -1000), zoomScale: 1, startSize: start.size, startPosition: start.position)
        #expect(tiny.size.height == PlacedImageGeometry.minimumSide)
        #expect(tiny.size.width == PlacedImageGeometry.minimumSide * 2)
    }

    @Test("Rotation wraps into 0..<360")
    func rotation() {
        #expect(PlacedImageGeometry.rotated(image(rotation: 350), by: 20).rotation == 10)
        #expect(PlacedImageGeometry.rotated(image(rotation: 10), by: -20).rotation == 350)
    }

    @Test("Initial placement fits the image into the visible region")
    func initialPlacement() {
        let visible = CGRect(x: 0, y: 0, width: 400, height: 300)
        let placement = PlacedImageGeometry.initialPlacement(for: CGSize(width: 4000, height: 2000), in: visible)
        #expect(placement.position == CGPoint(x: 200, y: 150))
        #expect(placement.size.width == 280 && placement.size.height == 140)
    }

    @Test("fittedSize preserves aspect and only shrinks")
    func fittedSize() {
        #expect(CanvasPlacedImage.fittedSize(for: CGSize(width: 800, height: 400)) == CGSize(width: 400, height: 200))
        #expect(CanvasPlacedImage.fittedSize(for: CGSize(width: 100, height: 50)) == CGSize(width: 100, height: 50))
        #expect(CanvasPlacedImage.fittedSize(for: .zero) == .zero)
    }

    @Test("Rotated bounds grow and the union covers every image")
    func bounds() {
        let plain = image()
        #expect(PlacedImageGeometry.rotatedBounds(of: plain) == plain.boundingRect)
        let turned = image(rotation: 90)
        let box = PlacedImageGeometry.rotatedBounds(of: turned)
        #expect(abs(box.width - 100) < 1e-6 && abs(box.height - 200) < 1e-6)
        let union = PlacedImageGeometry.unionBounds(of: [plain, image(at: CGPoint(x: 1000, y: 1000))])
        #expect(union.minX == 400 && union.maxX == 1100)
        #expect(PlacedImageGeometry.unionBounds(of: []).isNull)
    }

    @Test("Z-index advances past the topmost image")
    func zIndex() {
        #expect(PlacedImageGeometry.nextZIndex(after: []) == 0)
        var top = image()
        top.zIndex = 7
        #expect(PlacedImageGeometry.nextZIndex(after: [image(), top]) == 8)
    }

    @Test("Placed images round-trip through the flat JSON the canvas stores")
    func codable() throws {
        let original = image(rotation: 45)
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([CanvasPlacedImage].self, from: data)
        #expect(decoded == [original])
    }
}
