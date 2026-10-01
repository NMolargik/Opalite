//
//  CanvasEditorModel.swift
//  OpaliteFeatureCanvas
//
//  The editor's view model: the live drawing and placed images, ink and tool state,
//  the viewport (scroll offset / zoom) the overlays need, shape/SVG placement, a single
//  undo history across ink and images, and debounced autosave through `CanvasModel`.
//

#if canImport(PencilKit) && (os(iOS) || os(visionOS))
import SwiftUI
import UIKit
import PencilKit
import Observation
import os
import OpaliteCore
import OpaliteDesignSystem
import OpaliteFeatureShared

/// Whole-editor state the undo stack snapshots.
struct CanvasSnapshot {
    var drawing: PKDrawing
    var images: [CanvasPlacedImage]
}

/// What the placement overlay is currently sizing.
enum PlacementSubject: Identifiable {
    case shape(CanvasShape)
    case svg(paths: [CGPath], bounds: CGRect, name: String)

    var id: String {
        switch self {
        case .shape(let shape): "shape-\(shape.rawValue)"
        case .svg(_, _, let name): "svg-\(name)"
        }
    }

    var title: String {
        switch self {
        case .shape(let shape): shape.displayName
        case .svg(_, _, let name): name
        }
    }

    var systemImage: String {
        switch self {
        case .shape(let shape): shape.systemImage
        case .svg: "square.on.circle"
        }
    }

    /// Width / height lock while dragging (nil = free).
    var aspectRatio: CGFloat? {
        switch self {
        case .shape(let shape): shape.constrainedAspectRatio
        case .svg(_, let bounds, _): bounds.height > 0 ? bounds.width / bounds.height : nil
        }
    }
}

@MainActor
@Observable
final class CanvasEditorModel {
    let canvas: CanvasFile
    @ObservationIgnored private var canvases: CanvasModel?
    @ObservationIgnored private var toasts: ToastManager?

    // MARK: Content
    var drawing = PKDrawing()
    var placedImages: [CanvasPlacedImage] = []
    var canvasSize: CGSize = CanvasFile.defaultCanvasSize

    // MARK: Tools
    var inkColor: RGBA = .black
    /// Bumped to push `inkColor` into the active tool (user tool-picker edits don't bump it).
    var inkStamp = UUID()
    var externalTool: PKTool?
    var externalToolStamp = UUID()
    var isToolPickerVisible: Bool
    var isSwatchStripVisible = true

    // MARK: Modes
    var placement: PlacementSubject?
    var isEditingImages = false
    var selectedImageID: UUID?

    // MARK: Viewport (reported by the scroll view)
    var contentOffset: CGPoint = .zero
    var zoomScale: CGFloat = 1
    var viewportSize: CGSize = .zero
    /// Height of the viewport the tool picker covers at the bottom (iPhone).
    var obscuredBottomInset: CGFloat = 0

    // MARK: Presentation
    var isPresentingRename = false
    var renameText = ""
    var isConfirmingClear = false
    var isConfirmingDelete = false
    var isImportingSVG = false
    var isImportingImageFile = false
    var isPickingPhoto = false

    @ObservationIgnored private var history = UndoStack<CanvasSnapshot>()
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    @ObservationIgnored private var drawingDirty = false
    @ObservationIgnored private var imagesDirty = false

    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }
    var isPlacing: Bool { placement != nil }
    /// Drawing input is paused while an overlay owns the touches.
    var isDrawingEnabled: Bool { placement == nil && !isEditingImages }
    var isEmpty: Bool { drawing.strokes.isEmpty && placedImages.isEmpty }
    var selectedImage: CanvasPlacedImage? { placedImages.first { $0.id == selectedImageID } }

    init(canvas: CanvasFile) {
        self.canvas = canvas
        #if targetEnvironment(macCatalyst)
        isToolPickerVisible = false
        #else
        isToolPickerVisible = true
        #endif
    }

    // MARK: - Lifecycle

    func attach(canvases: CanvasModel, toasts: ToastManager) {
        self.canvases = canvases
        self.toasts = toasts
    }

    func load() {
        drawing = canvases?.loadDrawing(from: canvas) ?? canvas.loadDrawing()
        placedImages = canvas.placedImages
        if let stored = canvas.canvasSize {
            canvasSize = stored
        } else {
            canvasSize = CanvasFile.defaultCanvasSize
            canvases?.update(canvas) { $0.setCanvasSize(CanvasFile.defaultCanvasSize) }
        }
        history.clear()
        drawingDirty = false
        imagesDirty = false
    }

    /// Writes pending changes immediately (on disappear / backgrounding).
    func flush() {
        autosaveTask?.cancel()
        autosaveTask = nil
        persist()
    }

    // MARK: - Drawing

    /// A user edit arriving from the PencilKit canvas.
    func drawingDidChange(_ newDrawing: PKDrawing) {
        guard newDrawing != drawing else { return }
        history.record(snapshot)
        drawing = newDrawing
        drawingDirty = true
        scheduleAutosave()
    }

    func undo() {
        guard let previous = history.undo(current: snapshot) else { return }
        restore(previous)
        Haptics.lightImpact()
    }

    func redo() {
        guard let next = history.redo(current: snapshot) else { return }
        restore(next)
        Haptics.lightImpact()
    }

    func clearCanvas() {
        history.record(snapshot)
        drawing = PKDrawing()
        placedImages = []
        selectedImageID = nil
        drawingDirty = true
        imagesDirty = true
        scheduleAutosave()
        Haptics.mediumImpact()
    }

    // MARK: - Ink & tools

    func setInk(_ rgba: RGBA) {
        inkColor = rgba
        inkStamp = UUID()
    }

    /// The tool picker (or Catalyst strip) chose a tool; keep the ink swatch in sync.
    func userSelectedTool(_ tool: PKTool) {
        if let inking = tool as? PKInkingTool, let rgba = Color(uiColor: inking.color).rgba {
            inkColor = rgba
        }
    }

    func apply(externalTool tool: PKTool) {
        externalTool = tool
        externalToolStamp = UUID()
        userSelectedTool(tool)
    }

    var currentInk: PKInk { PKInk(.pen, color: inkColor.uiColor) }

    // MARK: - Shape placement

    func beginPlacing(_ shape: CanvasShape) {
        finishEditingImages()
        placement = .shape(shape)
        Haptics.selection()
    }

    func importSVG(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let parsed = try SVGPathParser().parse(from: url)
                for warning in parsed.warnings { Log.canvas.warning("SVG import: \(warning, privacy: .public)") }
                finishEditingImages()
                placement = .svg(paths: parsed.paths, bounds: parsed.bounds, name: url.deletingPathExtension().lastPathComponent)
            } catch {
                Log.canvas.error("SVG import failed: \(error.localizedDescription, privacy: .public)")
                toasts?.show(error: OpaliteError.importFailed(reason: error.localizedDescription))
            }
        case .failure(let error):
            toasts?.show(error: OpaliteError.importFailed(reason: error.localizedDescription))
        }
    }

    /// Commits the placement: `viewRect`/`rotation` come from the overlay in viewport points.
    func place(viewRect: CGRect, rotation: CGFloat) {
        guard let placement else { return }
        let canvasRect = ShapePlacementGeometry.canvasRect(fromViewRect: viewRect, contentOffset: contentOffset, zoomScale: zoomScale)
        let center = CGPoint(x: canvasRect.midX, y: canvasRect.midY)
        let polylines: [[CGPoint]]
        switch placement {
        case .shape(let shape):
            polylines = CanvasShapeGeometry.polylines(for: shape, center: center, width: canvasRect.width, height: canvasRect.height, rotation: rotation)
        case .svg(let paths, let bounds, _):
            polylines = CanvasShapeGeometry.polylines(forSVGPaths: paths, svgBounds: bounds, center: center, width: canvasRect.width, height: canvasRect.height, rotation: rotation)
        }
        let strokes = CanvasStrokeFactory.strokes(from: polylines, ink: currentInk)
        self.placement = nil
        guard !strokes.isEmpty else { return }

        history.record(snapshot)
        var updated = drawing
        updated.strokes.append(contentsOf: strokes)
        drawing = updated
        drawingDirty = true
        expandCanvasIfNeeded(toContain: PathSampling.bounds(of: polylines))
        scheduleAutosave()
        Haptics.mediumImpact()
    }

    func cancelPlacement() {
        placement = nil
        Haptics.selection()
    }

    // MARK: - Placed images

    /// Inserts image bytes, fitted into the visible region and selected for editing.
    func insertImage(data: Data) {
        guard let uiImage = UIImage(data: data) else {
            toasts?.show(error: OpaliteError.importFailed(reason: String(localized: "That file isn't an image")))
            return
        }
        let prepared = Self.downscaledPNG(uiImage)
        let visible = ShapePlacementGeometry.visibleCanvasRect(viewportSize: viewportSize, contentOffset: contentOffset, zoomScale: zoomScale)
        let placementInfo = PlacedImageGeometry.initialPlacement(for: prepared.pixelSize, in: visible)
        let image = CanvasPlacedImage(
            imageData: prepared.data,
            position: placementInfo.position,
            size: placementInfo.size,
            zIndex: PlacedImageGeometry.nextZIndex(after: placedImages)
        )
        history.record(snapshot)
        placedImages.append(image)
        imagesDirty = true
        placement = nil
        isEditingImages = true
        selectedImageID = image.id
        expandCanvasIfNeeded(toContain: image.boundingRect)
        scheduleAutosave()
        Haptics.success()
    }

    func importImageFile(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                insertImage(data: try Data(contentsOf: url))
            } catch {
                toasts?.show(error: OpaliteError.importFailed(reason: error.localizedDescription))
            }
        case .failure(let error):
            toasts?.show(error: OpaliteError.importFailed(reason: error.localizedDescription))
        }
    }

    /// Live update during a gesture (no undo record; call `commitImageEdit` first).
    func updateImage(_ image: CanvasPlacedImage) {
        guard let index = placedImages.firstIndex(where: { $0.id == image.id }) else { return }
        placedImages[index] = image
        imagesDirty = true
        scheduleAutosave()
    }

    /// Records the pre-gesture state once, at the start of a move/resize/rotate.
    func beginImageEdit() {
        history.record(snapshot)
    }

    func endImageEdit(_ image: CanvasPlacedImage) {
        updateImage(image)
        expandCanvasIfNeeded(toContain: PlacedImageGeometry.rotatedBounds(of: image))
    }

    func rotateSelectedImage(by degrees: Double) {
        guard let image = selectedImage else { return }
        beginImageEdit()
        endImageEdit(PlacedImageGeometry.rotated(image, by: degrees))
        Haptics.selection()
    }

    func bringSelectedImageToFront() {
        guard var image = selectedImage else { return }
        beginImageEdit()
        image.zIndex = PlacedImageGeometry.nextZIndex(after: placedImages)
        updateImage(image)
        Haptics.selection()
    }

    func deleteImage(id: UUID) {
        guard placedImages.contains(where: { $0.id == id }) else { return }
        history.record(snapshot)
        placedImages.removeAll { $0.id == id }
        if selectedImageID == id { selectedImageID = nil }
        imagesDirty = true
        scheduleAutosave()
        Haptics.mediumImpact()
    }

    func startEditingImages() {
        placement = nil
        isEditingImages = true
        if selectedImageID == nil { selectedImageID = placedImages.max(by: { $0.zIndex < $1.zIndex })?.id }
    }

    func finishEditingImages() {
        isEditingImages = false
        selectedImageID = nil
    }

    // MARK: - Export

    func makeExport() -> CanvasImageExport {
        #if os(visionOS)
        let scale: CGFloat = 2
        #else
        let scale = UITraitCollection.current.displayScale
        #endif
        return CanvasImageExport(title: canvas.title, drawingData: drawing.dataRepresentation(), images: placedImages, canvasSize: canvasSize, scale: scale)
    }

    // MARK: - Rename / delete

    func beginRename() {
        renameText = canvas.title
        isPresentingRename = true
    }

    func commitRename() {
        canvases?.rename(canvas, to: renameText)
        isPresentingRename = false
    }

    func deleteCanvas() {
        autosaveTask?.cancel()
        canvases?.delete(canvas)
    }

    // MARK: - Private

    private var snapshot: CanvasSnapshot { CanvasSnapshot(drawing: drawing, images: placedImages) }

    private func restore(_ snapshot: CanvasSnapshot) {
        drawing = snapshot.drawing
        placedImages = snapshot.images
        if let selectedImageID, !placedImages.contains(where: { $0.id == selectedImageID }) { self.selectedImageID = nil }
        drawingDirty = true
        imagesDirty = true
        scheduleAutosave()
    }

    private func expandCanvasIfNeeded(toContain rect: CGRect) {
        guard !rect.isNull else { return }
        let needed = CGSize(width: max(canvasSize.width, rect.maxX + CanvasExportGeometry.padding), height: max(canvasSize.height, rect.maxY + CanvasExportGeometry.padding))
        guard needed != canvasSize else { return }
        canvasSize = needed
        canvases?.update(canvas) { $0.expandCanvasIfNeeded(to: needed) }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        guard let canvases else { return }
        if imagesDirty {
            let images = placedImages
            canvases.update(canvas) { $0.placedImages = images }
            imagesDirty = false
        }
        if drawingDirty {
            canvases.saveDrawing(drawing, to: canvas)
            drawingDirty = false
        }
    }

    /// Caps inserted images at 2048px on the long side and normalizes to PNG.
    private static func downscaledPNG(_ image: UIImage, maxPixels: CGFloat = 2048) -> (data: Data, pixelSize: CGSize) {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest > maxPixels else {
            return (image.pngData() ?? Data(), pixelSize)
        }
        let factor = maxPixels / longest
        let target = CGSize(width: (pixelSize.width * factor).rounded(), height: (pixelSize.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return (rendered.pngData() ?? Data(), target)
    }
}
#endif
