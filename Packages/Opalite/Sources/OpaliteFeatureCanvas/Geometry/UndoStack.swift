//
//  UndoStack.swift
//  OpaliteFeatureCanvas
//
//  A bounded linear undo history over whole-state snapshots. The editor records the
//  previous snapshot before every user change (strokes, image moves, shape placement),
//  so one stack covers both the drawing and the placed images.
//

import Foundation

nonisolated struct UndoStack<Snapshot> {
    private(set) var past: [Snapshot] = []
    private(set) var future: [Snapshot] = []
    let limit: Int

    init(limit: Int = 40) {
        self.limit = max(1, limit)
    }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }

    /// Records the state *before* a new change; redo history is discarded.
    mutating func record(_ previous: Snapshot) {
        past.append(previous)
        if past.count > limit { past.removeFirst(past.count - limit) }
        future.removeAll()
    }

    /// Steps back: returns the snapshot to restore and parks `current` for redo.
    mutating func undo(current: Snapshot) -> Snapshot? {
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        return previous
    }

    /// Steps forward: returns the snapshot to restore and parks `current` for undo.
    mutating func redo(current: Snapshot) -> Snapshot? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        return next
    }

    mutating func clear() {
        past.removeAll()
        future.removeAll()
    }
}
