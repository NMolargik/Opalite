//
//  DefaultCanvasRepository.swift
//  OpaliteData
//
//  Canvas persistence. Folds duplicate records that an iCloud sync race can produce (the
//  same id arriving as two objects), keeping the most recently updated one.
//

import Foundation
import SwiftData
import OpaliteCore
import os

public final class DefaultCanvasRepository: CanvasRepository {
    private let context: ModelContext
    private let changeCenter: PortfolioChangeCenter

    public init(container: ModelContainer, changeCenter: PortfolioChangeCenter) {
        self.context = container.mainContext
        self.changeCenter = changeCenter
    }

    public func canvases() throws(PersistenceError) -> [CanvasFile] {
        let fetched = try context.fetchTyped(FetchDescriptor<CanvasFile>(sortBy: [SortDescriptor(\CanvasFile.title)]))
        var seen: [UUID: CanvasFile] = [:]
        var deletedDuplicate = false
        for canvas in fetched {
            if let existing = seen[canvas.id] {
                let keep = canvas.updatedAt > existing.updatedAt ? canvas : existing
                let drop = keep === canvas ? existing : canvas
                context.delete(drop)
                seen[canvas.id] = keep
                deletedDuplicate = true
            } else {
                seen[canvas.id] = canvas
            }
        }
        if deletedDuplicate {
            Log.canvas.notice("Folded duplicate canvas records from a sync race")
            try context.saveTyped()
        }
        return seen.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func canvas(withID id: UUID) throws(PersistenceError) -> CanvasFile? {
        var descriptor = FetchDescriptor<CanvasFile>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetchTyped(descriptor).first
    }

    public func count() throws(PersistenceError) -> Int {
        try canvases().count
    }

    public func insert(_ canvas: CanvasFile, deviceName: String?) throws(PersistenceError) {
        canvas.lastEditedDeviceName = deviceName ?? canvas.lastEditedDeviceName
        canvas.updatedAt = .now
        context.insert(canvas)
        try context.saveTyped()
        changeCenter.notify(.canvasCreated(canvas.id))
    }

    public func update(_ canvas: CanvasFile, deviceName: String?, configure: (CanvasFile) -> Void) throws(PersistenceError) {
        configure(canvas)
        canvas.lastEditedDeviceName = deviceName ?? canvas.lastEditedDeviceName
        canvas.updatedAt = .now
        try context.saveTyped()
        changeCenter.notify(.canvasUpdated(canvas.id))
    }

    public func delete(_ canvas: CanvasFile) throws(PersistenceError) {
        let id = canvas.id
        if let palette = canvas.palette {
            palette.canvasFile = nil
        }
        context.delete(canvas)
        try context.saveTyped()
        changeCenter.notify(.canvasDeleted(id))
    }
}
