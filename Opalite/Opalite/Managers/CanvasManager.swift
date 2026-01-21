//
//  CanvasManager.swift
//  Opalite
//
//  Created by Nick Molargik on 12/18/25.
//

import SwiftData
import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif
#if canImport(DeviceKit)
import DeviceKit
#endif

// MARK: - CanvasManager

/// Manages PencilKit canvas files with SwiftData persistence.
///
/// `CanvasManager` provides the business logic layer for canvas CRUD operations,
/// maintaining an in-memory cache of canvases for efficient view consumption.
/// It handles drawing serialization/deserialization and integrates with CloudKit
/// for cross-device sync.
///
/// ## Usage
/// ```swift
/// @Environment(CanvasManager.self) private var canvasManager
///
/// // Create a new canvas
/// let canvas = try canvasManager.createCanvas(title: "My Sketch")
///
/// // Save drawing changes
/// try canvasManager.saveDrawing(drawing, to: canvas)
///
/// // Load a drawing
/// let drawing = canvasManager.loadDrawing(from: canvas)
/// ```
///
/// ## Threading
/// This class is `@MainActor`-isolated and should only be accessed from the main thread.
/// All SwiftData operations are performed on the main context.
@MainActor
@Observable
final class CanvasManager {

    // MARK: - Properties

    /// The SwiftData model context for persistence operations.
    @ObservationIgnored
    let context: ModelContext

    /// Creates a new canvas manager with the specified model context.
    ///
    /// - Parameter context: The SwiftData model context to use for persistence
    init(context: ModelContext) {
        self.context = context
        reloadCache()
    }

    // MARK: - Cached Data

    /// All canvas files, sorted by most recently updated.
    ///
    /// This array is automatically refreshed after any mutation operation.
    /// Views should observe this property for reactive updates.
    var canvases: [CanvasFile] = []

    /// Canvas file waiting to be opened in the UI.
    ///
    /// Set this property to trigger navigation to a specific canvas.
    /// The UI layer should observe this and clear it after handling.
    var pendingCanvasToOpen: CanvasFile?

    #if canImport(PencilKit)
    /// Shape waiting to be placed on the active canvas.
    ///
    /// Set from menu bar commands. The active CanvasView should observe
    /// this property and enter shape placement mode when set.
    var pendingShape: CanvasShape?
    #endif

    // MARK: - Sorting

    /// Sort descriptors for canvas queries (most recent first).
    private var canvasSort: [SortDescriptor<CanvasFile>] {
        [
            SortDescriptor(\CanvasFile.updatedAt, order: .reverse),
            SortDescriptor(\CanvasFile.createdAt, order: .reverse)
        ]
    }

    // MARK: - Cache Management

    /// Reloads the in-memory cache from the persistent store.
    ///
    /// Called automatically after mutations. In case of fetch errors,
    /// the cache is cleared to prevent stale data.
    ///
    /// This method also deduplicates canvases that may have been created
    /// during iCloud sync race conditions (same UUID appearing twice).
    private func reloadCache() {
        do {
            let descriptor = FetchDescriptor<CanvasFile>(sortBy: canvasSort)
            let fetched = try context.fetch(descriptor)

            // Deduplicate by ID (keep most recently updated)
            // This handles race conditions during iCloud sync where the same
            // canvas may arrive as two separate SwiftData objects
            var seenIDs: [UUID: CanvasFile] = [:]
            for canvas in fetched {
                if let existing = seenIDs[canvas.id] {
                    // Keep the more recently updated one, delete the older
                    let older = canvas.updatedAt > existing.updatedAt ? existing : canvas
                    context.delete(older)
                    seenIDs[canvas.id] = canvas.updatedAt > existing.updatedAt ? canvas : existing
                } else {
                    seenIDs[canvas.id] = canvas
                }
            }

            // Save if we deleted any duplicates
            if context.hasChanges {
                try context.save()
            }

            // Sort by most recently updated
            self.canvases = Array(seenIDs.values).sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            #if DEBUG
            print("[CanvasManager] reloadCache error: \(error)")
            #endif
            self.canvases = []
        }
    }

    // MARK: - Refresh

    /// Refreshes the in-memory cache by fetching the latest data from SwiftData.
    ///
    /// Call this method when returning from background or after CloudKit sync
    /// to ensure the UI reflects the most current data.
    func refreshAll() async {
        reloadCache()
    }

    // MARK: - Fetching

    /// Fetches all canvases from the persistent store.
    ///
    /// This method updates the `canvases` cache and returns the fetched results.
    /// Use `refreshAll()` for async refresh without return value.
    ///
    /// - Returns: Array of all canvas files, sorted by most recently updated
    /// - Throws: SwiftData fetch errors
    @discardableResult
    func fetchCanvases() throws -> [CanvasFile] {
        let descriptor = FetchDescriptor<CanvasFile>(sortBy: canvasSort)
        let result = try context.fetch(descriptor)
        self.canvases = result
        return result
    }

    // MARK: - Saving

    /// Persists any pending changes to the SwiftData store.
    ///
    /// This method is called automatically by mutation methods. Only call
    /// directly if you've made manual changes to canvas objects.
    ///
    /// - Throws: SwiftData save errors
    func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Creating

    #if canImport(PencilKit)
    /// Creates a new canvas file with the specified properties.
    ///
    /// The canvas is inserted into the persistent store immediately.
    /// Device name is automatically recorded for sync attribution.
    ///
    /// - Parameters:
    ///   - title: Display title for the canvas (default: "Untitled Canvas")
    ///   - drawing: Initial PencilKit drawing content (default: empty)
    ///   - thumbnailData: Optional PNG thumbnail for list display
    /// - Returns: The newly created and persisted canvas file
    /// - Throws: SwiftData save errors
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

        let canvasID = canvas.id
        context.insert(canvas)
        try saveContext()
        reloadCache()
        // Return the canvas from the cache to avoid returning a detached object
        return canvases.first { $0.id == canvasID } ?? canvas
    }
    #else
    /// Creates a new canvas file with the specified title (tvOS version).
    ///
    /// - Parameters:
    ///   - title: Display title for the canvas
    /// - Returns: The newly created and persisted canvas file
    /// - Throws: SwiftData save errors
    @discardableResult
    func createCanvas(title: String = "Untitled Canvas") throws -> CanvasFile {
        let canvas = CanvasFile(title: title)

        canvas.createdAt = .now
        canvas.updatedAt = .now

        let canvasID = canvas.id
        context.insert(canvas)
        try saveContext()
        reloadCache()
        return canvases.first { $0.id == canvasID } ?? canvas
    }
    #endif

    /// Inserts an existing canvas file (e.g., from import) into the store.
    ///
    /// Use this method when importing canvases from external sources.
    /// The canvas's `updatedAt` timestamp is refreshed.
    ///
    /// - Parameter canvas: The canvas file to insert
    /// - Returns: The same canvas file after insertion
    /// - Throws: SwiftData save errors
    @discardableResult
    func createCanvas(existing canvas: CanvasFile) throws -> CanvasFile {
        #if canImport(DeviceKit)
        canvas.lastEditedDeviceName = Device.current.safeDescription
        #endif
        canvas.updatedAt = .now

        let canvasID = canvas.id
        context.insert(canvas)
        try saveContext()
        reloadCache()
        // Return the canvas from the cache to avoid returning a detached object
        return canvases.first { $0.id == canvasID } ?? canvas
    }

    // MARK: - Updating

    /// Applies changes to a canvas and persists them.
    ///
    /// Use the closure to modify canvas properties. The `updatedAt` timestamp
    /// and device name are automatically updated.
    ///
    /// - Parameters:
    ///   - canvas: The canvas to update
    ///   - changes: Optional closure to apply modifications
    /// - Throws: SwiftData save errors
    func updateCanvas(_ canvas: CanvasFile, applying changes: ((CanvasFile) -> Void)? = nil) throws {
        changes?(canvas)
        #if canImport(DeviceKit)
        canvas.lastEditedDeviceName = Device.current.safeDescription
        #endif
        canvas.updatedAt = .now
        try saveContext()
        reloadCache()
    }

    #if canImport(PencilKit)
    /// Saves a PencilKit drawing to a canvas file.
    ///
    /// The drawing is serialized and stored externally (not in SwiftData).
    /// Automatically generates a thumbnail for list display and tvOS preview.
    ///
    /// - Parameters:
    ///   - drawing: The PencilKit drawing to save
    ///   - canvas: The canvas file to save to
    ///   - thumbnailData: Optional custom thumbnail PNG data (if nil, one is generated)
    /// - Throws: SwiftData save errors
    func saveDrawing(_ drawing: PKDrawing, to canvas: CanvasFile, thumbnailData: Data? = nil) throws {
        // Use fresh canvas from cache to avoid detached object crashes with external storage
        guard let freshCanvas = freshCanvas(for: canvas) else { return }
        freshCanvas.saveDrawing(drawing)

        // Generate thumbnail if not provided
        if let thumbnailData {
            freshCanvas.thumbnailData = thumbnailData
        } else {
            freshCanvas.thumbnailData = generateThumbnail(from: drawing, canvasSize: freshCanvas.canvasSize)
        }

        #if canImport(DeviceKit)
        freshCanvas.lastEditedDeviceName = Device.current.safeDescription
        #endif
        try saveContext()
        reloadCache()
    }

    // MARK: - Thumbnail Generation

    /// Generates a PNG thumbnail from a PencilKit drawing.
    ///
    /// The thumbnail is rendered at a maximum size of 400x400 points while maintaining
    /// the drawing's aspect ratio. This is used for list display and tvOS previews.
    ///
    /// - Parameters:
    ///   - drawing: The PencilKit drawing to render
    ///   - canvasSize: The canvas dimensions (optional, defaults to drawing bounds)
    /// - Returns: PNG data for the thumbnail, or nil if generation fails
    func generateThumbnail(from drawing: PKDrawing, canvasSize: CGSize? = nil) -> Data? {
        #if canImport(UIKit)
        let maxThumbnailSize: CGFloat = 400

        // Use canvas size if available, otherwise use drawing bounds
        let sourceSize = canvasSize ?? drawing.bounds.size
        guard sourceSize.width > 0 && sourceSize.height > 0 else { return nil }

        // Calculate scale to fit within maxThumbnailSize while preserving aspect ratio
        let scale = min(maxThumbnailSize / sourceSize.width, maxThumbnailSize / sourceSize.height, 1.0)
        let thumbnailSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )

        // Render the drawing to an image with white background
        let bounds = CGRect(origin: .zero, size: sourceSize)
        let drawingImage = drawing.image(from: bounds, scale: 1.0)

        // Create a new image with white background
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        let thumbnailImage = renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: thumbnailSize))

            // Draw the PencilKit image scaled to fit
            drawingImage.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }

        return thumbnailImage.pngData()
        #else
        return nil
        #endif
    }

    // MARK: - Loading

    /// Loads the PencilKit drawing from a canvas file.
    ///
    /// If the drawing data is missing or corrupted, returns an empty drawing.
    /// The drawing is deserialized from external storage.
    ///
    /// - Parameter canvas: The canvas to load from
    /// - Returns: The canvas's PencilKit drawing, or empty if unavailable
    func loadDrawing(from canvas: CanvasFile) -> PKDrawing {
        // Use fresh canvas from cache to avoid detached object crashes with external storage
        guard let freshCanvas = freshCanvas(for: canvas) else { return PKDrawing() }
        return freshCanvas.loadDrawing()
    }
    #endif

    // MARK: - Helpers

    /// Returns the fresh canvas from the cache matching the given canvas's ID.
    /// This prevents crashes when accessing external storage attributes on detached objects.
    /// Falls back to fetching from the database if not found in cache.
    private func freshCanvas(for canvas: CanvasFile) -> CanvasFile? {
        let canvasID = canvas.id
        // First try the cache
        if let cached = canvases.first(where: { $0.id == canvasID }) {
            return cached
        }
        // Fallback: fetch from database
        let predicate = #Predicate<CanvasFile> { $0.id == canvasID }
        let descriptor = FetchDescriptor<CanvasFile>(predicate: predicate)
        return try? context.fetch(descriptor).first
    }

    // MARK: - Deleting

    /// Permanently deletes a canvas file from the store.
    ///
    /// This operation cannot be undone. Associated drawing data is also removed.
    ///
    /// - Parameter canvas: The canvas to delete
    /// - Throws: SwiftData save errors
    func deleteCanvas(_ canvas: CanvasFile) throws {
        context.delete(canvas)
        try saveContext()
        reloadCache()
    }

    // MARK: - Sample Data

    /// Creates sample canvas files for SwiftUI previews.
    ///
    /// Clears existing cached data and creates three sample canvases:
    /// "Sketch", "Ideas", and "Storyboard".
    ///
    /// - Throws: SwiftData save errors
    func loadSamples() throws {
        self.canvases = []

        #if canImport(PencilKit)
        let a = CanvasFile(title: "Sketch", drawing: PKDrawing())
        let b = CanvasFile(title: "Ideas", drawing: PKDrawing())
        let c = CanvasFile(title: "Storyboard", drawing: PKDrawing())
        #else
        let a = CanvasFile(title: "Sketch")
        let b = CanvasFile(title: "Ideas")
        let c = CanvasFile(title: "Storyboard")
        #endif

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
