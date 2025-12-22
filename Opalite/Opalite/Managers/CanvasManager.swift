//
//  CanvasManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import SwiftData
import SwiftUI
import PencilKit
#if canImport(DeviceKit)
import DeviceKit
#endif

@MainActor
@Observable
final class CanvasManager {
    @ObservationIgnored
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Cached data for views to consume
    var canvases: [CanvasFile] = []

    /// Set this to request opening a specific canvas (used for cross-tab navigation)
    var pendingCanvasToOpen: CanvasFile? = nil

    // MARK: - Sort
    private var canvasSort: [SortDescriptor<CanvasFile>] {
        [
            SortDescriptor(\CanvasFile.updatedAt, order: .reverse),
            SortDescriptor(\CanvasFile.createdAt, order: .reverse)
        ]
    }

    // MARK: - Cache Reload
    private func reloadCache() {
        do {
            let descriptor = FetchDescriptor<CanvasFile>(sortBy: canvasSort)
            self.canvases = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("[CanvasManager] reloadCache error: \(error)")
            #endif
            self.canvases = []
        }
    }

    // MARK: - Public API: Refresh
    /// Refreshes in-memory cache by fetching the latest data from the ModelContext.
    func refreshAll() async {
        reloadCache()
    }

    // MARK: - Public API: Fetching
    @discardableResult
    func fetchCanvases() throws -> [CanvasFile] {
        let descriptor = FetchDescriptor<CanvasFile>(sortBy: canvasSort)
        let result = try context.fetch(descriptor)
        self.canvases = result
        return result
    }

    // MARK: - Saving
    func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Creating / Inserting
    /// Creates, inserts, and saves a new canvas file.
    @discardableResult
    func createCanvas(
        title: String = "Untitled Canvas",
        drawing: PKDrawing = PKDrawing(),
        thumbnailData: Data? = nil
    ) throws -> CanvasFile {
        let canvas = CanvasFile(title: title, drawing: drawing)
        canvas.thumbnailData = thumbnailData

        #if canImport(DeviceKit)
        canvas.lastEditedDeviceName = Device.current.safeDescription
        #endif

        canvas.createdAt = .now
        canvas.updatedAt = .now

        context.insert(canvas)
        try saveContext()
        reloadCache()
        return canvas
    }

    /// Inserts and saves an existing canvas instance (e.g., imported).
    @discardableResult
    func createCanvas(existing canvas: CanvasFile) throws -> CanvasFile {
        #if canImport(DeviceKit)
        canvas.lastEditedDeviceName = Device.current.safeDescription
        #endif
        canvas.updatedAt = .now

        context.insert(canvas)
        try saveContext()
        reloadCache()
        return canvas
    }

    // MARK: - Updating
    /// Applies changes to a canvas and saves.
    func updateCanvas(_ canvas: CanvasFile, applying changes: ((CanvasFile) -> Void)? = nil) throws {
        changes?(canvas)
        #if canImport(DeviceKit)
        canvas.lastEditedDeviceName = Device.current.safeDescription
        #endif
        canvas.updatedAt = .now
        try saveContext()
        reloadCache()
    }

    /// Persists a new drawing to the canvas and saves.
    func saveDrawing(_ drawing: PKDrawing, to canvas: CanvasFile, thumbnailData: Data? = nil) throws {
        canvas.saveDrawing(drawing)
        if let thumbnailData {
            canvas.thumbnailData = thumbnailData
        }
        #if canImport(DeviceKit)
        canvas.lastEditedDeviceName = Device.current.safeDescription
        #endif
        try saveContext()
        reloadCache()
    }

    // MARK: - Loading
    /// Loads the PKDrawing from a canvas (returns empty drawing if missing/corrupt).
    func loadDrawing(from canvas: CanvasFile) -> PKDrawing {
        canvas.loadDrawing()
    }

    /// Loads the background image from a canvas (returns nil if none).
    func loadBackgroundImage(from canvas: CanvasFile) -> UIImage? {
        canvas.loadBackgroundImage()
    }

    // MARK: - Background Image
    /// Saves a background image to the canvas.
    func saveBackgroundImage(_ image: UIImage?, to canvas: CanvasFile) throws {
        canvas.saveBackgroundImage(image)
        #if canImport(DeviceKit)
        canvas.lastEditedDeviceName = Device.current.safeDescription
        #endif
        try saveContext()
    }

    // MARK: - Deleting
    func deleteCanvas(_ canvas: CanvasFile) throws {
        context.delete(canvas)
        try saveContext()
        reloadCache()
    }

    // MARK: - Samples
    func loadSamples() throws {
        self.canvases = []

        let a = CanvasFile(title: "Sketch", drawing: PKDrawing())
        let b = CanvasFile(title: "Ideas", drawing: PKDrawing())
        let c = CanvasFile(title: "Storyboard", drawing: PKDrawing())

        #if canImport(DeviceKit)
        let device = Device.current.safeDescription
        a.lastEditedDeviceName = device
        b.lastEditedDeviceName = device
        c.lastEditedDeviceName = device
        #endif

        a.createdAt = .now
        a.updatedAt = .now
        b.createdAt = .now
        b.updatedAt = .now
        c.createdAt = .now
        c.updatedAt = .now

        context.insert(a)
        context.insert(b)
        context.insert(c)

        try saveContext()
        reloadCache()
    }
}
