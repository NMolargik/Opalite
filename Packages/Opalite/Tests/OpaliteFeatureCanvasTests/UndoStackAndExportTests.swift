import Testing
import CoreGraphics
import Foundation
import OpaliteCore
@testable import OpaliteFeatureCanvas

@Suite("UndoStack")
struct UndoStackTests {
    @Test("Undo and redo walk the history in order")
    func undoRedo() {
        var stack = UndoStack<Int>()
        stack.record(1)
        stack.record(2)
        #expect(stack.canUndo && !stack.canRedo)
        #expect(stack.undo(current: 3) == 2)
        #expect(stack.undo(current: 2) == 1)
        #expect(stack.undo(current: 1) == nil)
        #expect(stack.redo(current: 1) == 2)
        #expect(stack.redo(current: 2) == 3)
        #expect(stack.redo(current: 3) == nil)
    }

    @Test("A new change after undo discards the redo branch")
    func branch() {
        var stack = UndoStack<Int>()
        stack.record(1)
        _ = stack.undo(current: 2)
        #expect(stack.canRedo)
        stack.record(5)
        #expect(!stack.canRedo)
        #expect(stack.undo(current: 6) == 5)
    }

    @Test("History is bounded by the limit")
    func limit() {
        var stack = UndoStack<Int>(limit: 2)
        for value in 1...5 { stack.record(value) }
        #expect(stack.past == [4, 5])
        stack.clear()
        #expect(!stack.canUndo)
    }
}

@Suite("CanvasExportGeometry")
struct CanvasExportGeometryTests {
    @Test("Empty canvases have no export rect")
    func empty() {
        #expect(CanvasExportGeometry.exportRect(drawingBounds: .null, images: [], canvasSize: CGSize(width: 100, height: 100)) == nil)
        #expect(CanvasExportGeometry.exportRect(drawingBounds: .zero, images: [], canvasSize: CGSize(width: 100, height: 100)) == nil)
    }

    @Test("Content is padded and clamped to the canvas")
    func padded() {
        let rect = CanvasExportGeometry.exportRect(drawingBounds: CGRect(x: 10, y: 10, width: 100, height: 50), images: [], canvasSize: CGSize(width: 4096, height: 4096))
        #expect(rect == CGRect(x: 0, y: 0, width: 150, height: 100))
        let image = CanvasPlacedImage(imageData: Data(), position: CGPoint(x: 1000, y: 1000), size: CGSize(width: 200, height: 100))
        let union = CanvasExportGeometry.exportRect(drawingBounds: CGRect(x: 100, y: 100, width: 10, height: 10), images: [image], canvasSize: CGSize(width: 4096, height: 4096))
        #expect(union == CGRect(x: 60, y: 60, width: 1080, height: 1030))
    }
}
